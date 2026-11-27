# frozen_string_literal: true

# Attribution tables for README.md from the detail runs' dump.rb aggregates:
#   ruby attribute.rb OUT > attribution.md
# Bytes are memsize (slot plus out-of-slot) of live objects after full GCs.
# "(tracer)" (the allocation tracer's own table) is left out everywhere.
require "json"

out = ARGV.fetch(0)
APPS = %w[blog writebook pingcrm redprints-cfp react-starter-kit sure].freeze
def dump(config, tree, app)
  path = File.join(ARGV[0], config, tree, "#{app}-detail.dump.json")
  File.exist?(path) ? JSON.parse(File.read(path)) : nil
end

def rows(d, snap, section) = d.dig("snapshots", snap, section).to_h { [_1["key"], _1["bytes"]] }
def mb(x) = format("%.2f", x / 1e6)
def group(owner)
  return nil if owner == "(tracer)"
  case owner
  when %r{\Arails/} then "Rails (all components)"
  when %r{\Agem/} then "gems"
  when "app" then "app"
  when "ruby/stdlib", "ruby/(eval)" then "Ruby stdlib"
  when "ruby/vm" then "Ruby VM tables"
  when "ruby/method-cache" then "Ruby method caches (cc tables)"
  when "(untraced)" then "untraced (C, before tracing)"
  else "harness and other"
  end
end
GROUPS = ["Rails (all components)", "gems", "app", "Ruby stdlib", "Ruby VM tables", "Ruby method caches (cc tables)",
  "untraced (C, before tracing)", "harness and other"].freeze

def table(title, header, lines)
  puts "### #{title}", "", "| #{header.join(" | ")} |", "|---|#{"---:|" * (header.size - 1)}"
  lines.each { puts "| #{_1.join(" | ")} |" }
  puts
end

base = %w[master-interpreter main]
puts "## Attribution (detail runs: allocation tracing and heap dumps, one run per configuration)", ""

# 1. Boot heap by owner group, Ruby master interpreter, Rails main.
lines = GROUPS.map do |g|
  [g] + APPS.map { |a| (d = dump(*base, a)) ? mb(rows(d, "boot", "by_owner").select { |k, _| group(k) == g }.sum { _2 }) : "–" }
end
lines << ["ISEQs (inside the groups above)"] + APPS.map { |a| (d = dump(*base, a)) ? mb(rows(d, "boot", "by_imemo")["iseq"].to_i) : "–" }
table("Live bytes after boot by owner, MB (Ruby master interpreter, Rails main)", ["owner"] + APPS, lines)

# 2. Largest owners across apps (sum over apps that have the owner).
totals = Hash.new { |h, k| h[k] = {} }
APPS.each { |a| (d = dump(*base, a)) && rows(d, "boot", "by_owner").each { |k, v| totals[k][a] = v } }
top = totals.reject { |k, _| k == "(tracer)" }.sort_by { |_, h| -h.values.sum.fdiv(h.size) }.first(30)
table("Largest owners after boot, MB (master interpreter, Rails main)", ["owner"] + APPS,
  top.map { |k, h| [k] + APPS.map { |a| h[a] ? mb(h[a]) : "–" } })

# 3. Rails main − 8.1 by Rails component, split ISEQ / other, per Ruby.
%w[master-interpreter r4010-interpreter].each do |config|
  comps = Hash.new { |h, k| h[k] = {} }
  APPS.each do |a|
    d0 = dump(config, "r81", a) or next
    d1 = dump(config, "main", a) or next
    t0 = rows(d0, "boot", "by_owner_type")
    t1 = rows(d1, "boot", "by_owner_type")
    (t0.keys | t1.keys).each do |k|
      owner, type = k.split(" ", 2)
      next unless owner.start_with?("rails/") || owner.start_with?("gem/") || owner == "ruby/stdlib" || owner == "ruby/method-cache"
      key = owner.start_with?("rails/") ? "#{owner} #{type == "IMEMO/iseq" ? "ISEQ" : "other"}" : owner
      comps[key][a] = comps[key].fetch(a, 0) + t1.fetch(k, 0) - t0.fetch(k, 0)
    end
  end
  table("Rails main − 8.1.4.1 after boot by owner, MB (#{config}; owners moving ≥ 0.1 MB in some app)", ["owner"] + APPS,
    comps.select { |_, h| h.values.any? { _1.abs >= 100_000 } }.sort_by { |_, h| -h.values.sum }
      .map { |k, h| [k] + APPS.map { |a| h.key?(a) ? format("%+.2f", h[a] / 1e6) : "–" } })
end

# 4. Ruby master − 4.0.10 by object type and imemo type, Rails main.
%w[interpreter].each do |mode|
  keys = Hash.new { |h, k| h[k] = {} }
  APPS.each do |a|
    d0 = dump("r4010-#{mode}", "main", a) or next
    d1 = dump("master-#{mode}", "main", a) or next
    %w[by_type by_imemo].each do |section|
      t0 = rows(d0, "boot", section)
      t1 = rows(d1, "boot", section)
      (t0.keys | t1.keys).each do |k|
        next if section == "by_type" && k == "IMEMO"
        name = section == "by_imemo" ? "IMEMO/#{k}" : k
        keys[name][a] = t1.fetch(k, 0) - t0.fetch(k, 0)
      end
    end
  end
  table("Ruby master − 4.0.10 after boot by type, MB (#{mode}, Rails main; types moving ≥ 0.1 MB in some app)",
    ["type"] + APPS, keys.select { |k, h| !k.include?("ObjectTracing") && h.values.any? { _1.abs >= 100_000 } }
      .sort_by { |_, h| h.values.sum }.map { |k, h| [k] + APPS.map { |a| h.key?(a) ? format("%+.2f", h[a] / 1e6) : "–" } })
end

# 5. Duplicated Strings and growth after request 1,000.
lines = []
%w[r4010-interpreter master-interpreter master-zjit].product(%w[r81 main]).each do |config, tree|
  lines << ["#{config} #{tree}"] + APPS.map { |a| (d = dump(config, tree, a)) ? mb(d.dig("snapshots", "boot", "strings", "wasted_bytes")) : "–" }
end
table("Bytes in duplicate String copies after boot (beyond one copy per content), MB", ["configuration"] + APPS, lines)

lines = []
%w[r4010-interpreter master-interpreter master-zjit].product(%w[r81 main]).each do |config, tree|
  lines << ["#{config} #{tree}"] + APPS.map do |a|
    d = dump(config, tree, a)
    g = d && d["growth"]
    g ? mb(g["by_owner_type"].reject { _1["key"].start_with?("(tracer)") }.sum { _1["bytes"] }) : "–"
  end
end
table("Objects allocated after request 1,000 and still live at request 5,000, MB", ["configuration"] + APPS, lines)
