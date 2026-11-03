# frozen_string_literal: true

# Rank gem code by breadth, then CPU (docs/upstream/gem-request-census.md).
#   ruby rank.rb DIR LABEL MODE [AA_LABEL] [--gems] [--limit N] [--tsv FILE]
# DIR/LABEL/APP-MODE.json come from prof.rb. A site is a gem method (path and
# name, so releases of a gem with shifted lines share a key); a gem with --gems. A site reaches a workload at >= 0.1% of that
# workload's CPU samples (all samples minus I/O wait and harness frames, GC
# included). Samples are wall-clock: a C call that blocks without a Ruby-level
# wait (pg's get_result on the server) counts as its gem's time. Apps reached count fizzy/fizzy-mysql and APP/APP-nops once. Within
# each tier (>= 7, 5-6, 3-4, 2, 1 apps), sites are ordered by their mean share
# over every workload of every configuration. Columns: mean CPU share, mean
# CPU µs per operation (share x thread CPU time per operation), mean objects
# per operation (stackprof object mode, attributed the same way) and, with
# AA_LABEL, the A/A difference of the mean share (LABEL - AA_LABEL).
require "json"

dir, label, mode, aa = ARGV.reject { _1.start_with?("--") || _1 =~ /\A\d+\z/ || _1.end_with?(".tsv") }
gems = ARGV.include?("--gems")
limit = (i = ARGV.index("--limit")) ? Integer(ARGV[i + 1]) : 60
tsv = (i = ARGV.index("--tsv")) ? ARGV[i + 1] : nil
mode = { "interp" => "interpreter" }.fetch(mode, mode)
REACH = 0.001
TIERS = [7, 5, 3, 2, 1].freeze

def app_of(config) = config.delete_suffix("-nops").delete_suffix("-mysql")

def load_label(dir, label, mode, gems)
  rows = []
  Dir[File.join(dir, label, "*-#{mode}.json")].sort.each do |path|
    data = JSON.parse(File.read(path))
    data.fetch("workloads").each do |w|
      cpu = w["samples"] - w["wait"] - w["owners"].fetch("harness", 0)
      next if cpu <= 0
      sites = Hash.new(0)
      objects = Hash.new(0)
      if gems
        w["owners"].each { |k, v| sites[k.delete_prefix("gem:")] += v if k.start_with?("gem:") }
        w["objects"]["owners"].each { |k, v| objects[k.delete_prefix("gem:")] += v if k.start_with?("gem:") }
      else
        w["methods"].each { |k, v| sites[k.sub(/:\d+ /, " ")] += v }
        w["objects"]["methods"].each { |k, v| objects[k.sub(/:\d+ /, " ")] += v }
      end
      rows << { config: data["app"], app: app_of(data["app"]), name: w["name"], cpu: cpu,
        cpu_us: w["cpu_us_per_op"] * cpu.fdiv(w["samples"] - w["wait"]), sites: sites,
        objects: objects.transform_values { _1.fdiv(w["objects_ops"]) } }
    end
  end
  rows
end

def summarize(rows)
  n = rows.size.to_f
  out = Hash.new { |h, k| h[k] = { apps: {}, reached: 0, share: 0.0, us: 0.0, objects: 0.0 } }
  rows.each do |w|
    (w[:sites].keys | w[:objects].keys).each do |site|
      s = w[:sites][site].fdiv(w[:cpu])
      o = out[site]
      o[:share] += s / n
      o[:us] += s * w[:cpu_us] / n
      o[:objects] += w[:objects].fetch(site, 0) / n
      next unless s >= REACH
      o[:reached] += 1
      o[:apps][w[:app]] = true
    end
  end
  out
end

rows = load_label(dir, label, mode, gems)
abort "no data for #{label} #{mode}" if rows.empty?
sum = summarize(rows)
aa_sum = aa && summarize(load_label(dir, aa, mode, gems))
tier = ->(apps) { TIERS.find { apps >= _1 } || 0 }
ranked = sum.select { |_, o| o[:apps].any? }.sort_by { |site, o| [-tier.(o[:apps].size), -o[:share], site] }
apps = rows.map { _1[:app] }.uniq.size
puts "#{label} #{mode}: #{rows.size} workloads, #{rows.map { _1[:config] }.uniq.size} configurations, #{apps} apps; " \
  "#{gems ? "gems" : "gem methods"} reaching >= #{(REACH * 100).round(2)}% of a workload's CPU samples"
puts format("%-4s %-4s %-5s %-8s %-9s %-8s %s%s", "#", "apps", "wl", "share%", "us/op", "obj/op", aa ? "A/A pp  " : "", "site")
lines = ranked.each_with_index.map do |(site, o), i|
  d = aa_sum && (o[:share] - aa_sum[site][:share]) * 100
  [i + 1, o[:apps].size, o[:reached], (o[:share] * 100).round(3), o[:us].round(1), o[:objects].round(1), d&.round(3), site,
    o[:apps].keys.sort.join(",")]
end
lines.first(limit).each do |l|
  puts format("%-4d %-4d %-5d %-8.3f %-9.1f %-8.1f %s%s", *l[0, 6], l[6] ? format("%+-8.3f", l[6]) : "", l[7])
end
File.write(tsv, (["rank\tapps\tworkloads\tshare_pct\tus_per_op\tobjects_per_op\taa_pp\tsite\tapp_list"] +
  lines.map { _1.join("\t") }).join("\n") + "\n") if tsv
