# frozen_string_literal: true

# Rank ZJIT polymorphic/megamorphic fallback sites and estimate what an
# N-entry polymorphic cache would catch (docs/upstream/zjit-polymorphism.md).
#
#   ruby zjit_poly_rank.rb INTERP_DIR JIT_DIR [--top 15] [--apps a,b] > report.md
#
# INTERP_DIR/APP.tsv: full per-site receiver distribution (ZJIT_POLYPROBE=interp)
# JIT_DIR/APP.tsv:    receiver of every ZJIT dynamic fallback (ZJIT_POLYPROBE=jit)
# APP.json (either dir): census `stats` output with `ops`.
# TSV columns: kind, iseq:insn_idx, label@path:line, method/ivar, type, shape, count.
require "json"

interp_dir, jit_dir = ARGV.first(2)
top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 15
apps = Dir[File.join(jit_dir, "*.tsv")].map { File.basename(_1, ".tsv") }.sort
apps &= ARGV[ARGV.index("--apps") + 1].split(",") if ARGV.include?("--apps")

def short_path(site)
  site.sub(%r{/\S*/bundler/gems/rails-\h+/}, "rails/").sub(%r{/\S*/gems/([^/]+)/}, '\1/')
      .sub(%r{/home/user/workspace/repo/\.corpus/census4-[^/]+/}, "app/")
end

def norm_type(t) = t.gsub(/0x\h+/, "0x?")

def load(path)
  rows = []
  File.foreach(path) do |line|
    kind, iseq_idx, label, what, type, shape, count = line.chomp.split("\t")
    next unless count
    idx = iseq_idx.split(":").last
    site = "#{short_path(label)} @#{idx}"
    rows << [kind, site, norm_type(type), shape, Integer(count), what]
  end
  rows
end

GROUP = {
  "Send: polymorphic fallback" => "send_polymorphic_fallback",
  "Send: polymorphic call site" => "send_polymorphic",
  "Send: megamorphic call site" => "send_megamorphic",
  "InvokeBlock: polymorphic dispatch miss" => "invokeblock_polymorphic_miss",
  "InvokeBlock: not yet specialized" => "invokeblock_not_specialized",
  "getivar_fallback_no_profile_missing_ic" => "getivar_no_profile_missing_ic",
  "getivar_fallback_no_side_exits" => "getivar_no_side_exits",
  "getivar_fallback_polymorphic" => "getivar_polymorphic",
  "getivar_fallback_megamorphic" => "getivar_megamorphic",
}.freeze
INTERP_KIND = { "send" => "send", "invokeblock" => "invokeblock", "getivar" => "getivar" }.freeze

# For sends a cache entry is a receiver class; for getivar a (class, shape);
# for invokeblock a block handler.
def entry_key(group, type, shape)
  group.start_with?("getivar") ? "#{type}|#{shape}" : type
end

def interp_kind(group)
  group.start_with?("send") ? "send" : group.start_with?("invokeblock") ? "invokeblock" : "getivar"
end

sites = Hash.new { |h, k| h[k] = { apps: {} } }
names = {}
totals = Hash.new { |h, k| h[k] = Hash.new(0.0) }
match = Hash.new(0.0)

apps.each do |app|
  json = [jit_dir, interp_dir].map { File.join(_1, "#{app}.json") }.find { File.exist?(_1) }
  jit_ops = JSON.parse(File.read(File.join(jit_dir, "#{app}.json")))["ops"].to_f
  int_ops = JSON.parse(File.read(File.join(interp_dir, "#{app}.json")))["ops"].to_f
  raise "no ops for #{app} (#{json})" unless jit_ops > 0 && int_ops > 0

  dist = Hash.new { |h, k| h[k] = Hash.new(0) }     # [kind, site] -> entry -> count
  shapes = Hash.new { |h, k| h[k] = Hash.new(0) }   # [kind, site] -> class|shape -> count
  load(File.join(interp_dir, "#{app}.tsv")).each do |kind, site, type, shape, n, what|
    dist[[kind, site]][type] += n
    shapes[[kind, site]]["#{type}|#{shape}"] += n
    names[site] ||= what unless kind.end_with?("_cme", "_idx")
  end

  fb = Hash.new { |h, k| h[k] = Hash.new(0) }        # [group, site] -> entry -> count
  cme = Hash.new { |h, k| h[k] = Hash.new(0) }       # [group, site] -> cme label -> count
  load(File.join(jit_dir, "#{app}.tsv")).each do |kind, site, type, shape, n|
    if kind.end_with?("/cme")
      g = GROUP[kind.delete_suffix("/cme")] or next
      cme[[g, site]][type] += n
    else
      g = GROUP[kind] or next
      fb[[g, site]][entry_key(g, type, shape)] += n
    end
  end

  fb.each do |(g, site), entries|
    ik = interp_kind(g)
    # An inlined attr_reader's GetIvar carries the caller's send site.
    ik = "send" if ik == "getivar" && !shapes.key?(["getivar", site]) && shapes.key?(["send", site])
    full = g.start_with?("getivar") ? shapes[[ik, site]] : dist[[ik, site]]
    calls = full.values.sum
    ranked = full.sort_by { -_2 }.map(&:first)
    fallbacks = entries.values.sum
    matched = entries.sum { |e, n| full.key?(e) ? n : 0 }
    match[:all] += fallbacks
    match[:matched] += matched
    caught = [1, 2, 4, 8].to_h { |n| [n, entries.sum { |e, c| ranked.first(n).include?(e) ? c : 0 }] }
    cme_full = dist[["send_cme", site]]
    top_cme = cme_full.max_by { _2 }&.first
    one_method = g.start_with?("send") && top_cme ? cme[[g, site]][top_cme] : 0

    s = sites[[g, site]]
    s[:apps][app] = {
      fallbacks: fallbacks / jit_ops, calls: calls / int_ops,
      caught: caught.transform_values { _1 / jit_ops }, one_method: one_method / jit_ops,
      classes: dist[[ik, site]].size, entries: full.size, shapes_n: shapes[[ik, site]].size,
      shapes: nil,
      cmes: cme_full.size, ivar_idx: dist[["getivar_idx", site]].size,
      ivar_idx_top: dist[["getivar_idx", site]].max_by { _2 }&.first,
      cover: [1, 2, 4, 8].to_h { |n| [n, calls.zero? ? 0 : full.values.sort.reverse.first(n).sum.fdiv(calls)] },
      top_types: full.sort_by { -_2 }.first(4).map { |e, n| [e, n.fdiv([calls, 1].max)] },
      top_cme: top_cme,
    }
    t = totals[g]
    t[:fallbacks] += fallbacks / jit_ops
    caught.each { |n, c| t[:"caught#{n}"] += c / jit_ops }
    t[:one_method] += one_method / jit_ops
  end
end

n_apps = apps.size.to_f
puts "Apps: #{apps.join(', ')} (means are over #{apps.size} apps, per operation)"
puts "Fallback receivers found in the interpreter distribution: #{(100 * match[:matched] / [match[:all], 1].max).round(1)}%"
puts
puts "| Reason | Fallbacks/op | caught N=1 | N=2 | N=4 | N=8 | one resolved method |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
totals.sort_by { -_2[:fallbacks] }.each do |g, t|
  f = t[:fallbacks] / n_apps
  pct = ->(x) { "#{(x / n_apps).round} (#{(100 * x / [t[:fallbacks], 1e-9].max).round}%)" }
  puts "| `#{g}` | #{f.round} | #{pct[t[:caught1]]} | #{pct[t[:caught2]]} | #{pct[t[:caught4]]} | #{pct[t[:caught8]]} | #{g.start_with?('send') ? pct[t[:one_method]] : '–'} |"
end

totals.keys.sort_by { -totals[_1][:fallbacks] }.each do |g|
  puts
  puts "### #{g}"
  puts
  puts "| Site | Apps | Fallbacks/op | Calls/op | Classes | Shapes | Top-2 / 4 / 8 cover | N=4 catches | #{g.start_with?('getivar') ? 'ivar index' : 'methods'} | Top receivers |"
  puts "| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |"
  rows = sites.select { |(gg, _), _| gg == g }.map do |(_, site), s|
    a = s[:apps].values
    [site, s, a.sum { _1[:fallbacks] } / n_apps]
  end.sort_by { -_3 }.first(top)
  rows.each do |site, s, f|
    a = s[:apps].values
    calls = a.sum { _1[:calls] } / n_apps
    w = ->(k, n) { (a.sum { _1[:cover][n] * _1[:calls] } / [a.sum { _1[:calls] }, 1e-9].max * 100).round }
    caught4 = a.sum { _1[:caught][4] } / n_apps
    mx = ->(k) { a.map { _1[k] }.compact.max }
    extra = g.start_with?("getivar") ? "#{mx[:ivar_idx]} (#{a.first[:ivar_idx_top]})" : "#{mx[:cmes]} (#{a.first[:top_cme]})"
    tt = a.max_by { _1[:calls] }[:top_types].map { |e, share| "#{e.split('|').first} #{(share * 100).round}%" }.join(", ")
    puts "| `#{site.sub(/ @\d+\z/, '')} #{names[site]}` | #{a.size} | #{f.round(1)} | #{calls.round(1)} | #{mx[:classes]} | #{mx[:shapes_n]} | #{w[:cover, 2]}% / #{w[:cover, 4]}% / #{w[:cover, 8]}% | #{caught4.round(1)} | #{extra} | #{tt} |"
  end
end
