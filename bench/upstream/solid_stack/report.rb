# frozen_string_literal: true

# Summarizes one round of bench/upstream/solid_stack/run.sh labels.
#   ruby report.rb DIR PREFIX            ops table: objects and Ir per op for PREFIX-{rel,main}-{a,b}, with A/A
#   ruby report.rb DIR LABEL sites [N]   top N lines per op for one cpu label
#   ruby report.rb DIR LABEL components  share of each op's Ir by gem or Rails component (top 60 lines only)
require "json"

dir, prefix, what, n = ARGV
load_label = ->(label, kind) { JSON.parse(File.read(File.join(dir, "#{label}-#{kind}.json")))["workloads"].to_h { [_1["workload"], _1] } }
pct = ->(a, b) { format("%+.2f%%", (b - a) * 100.0 / a) }

component = lambda do |file|
  case file
  when %r{\AGEM/(solid_queue|solid_cache|solid_cable|turbo-rails)/} then $1
  when %r{\ARAILS/(\w+)/} then "rails/#{$1}"
  when %r{\AGEM/4\.0\.0/gems/([a-z_\-]+?)-\d} then "gem/#{$1}"
  when %r{\ARUBY/|<internal} then "ruby"
  else "other"
  end
end

if what == "components"
  load_label.(prefix, "cpu").each_value do |w|
    shares = Hash.new(0.0)
    w["sites"].each { |s| shares[component.(s["file"])] += s["ir_per_op"] }
    top = shares.sort_by { -_2 }.first(Integer(n || 6)).map { |c, ir| format("%s %.0f%%", c, ir * 100 / w["ir_per_op"]) }
    puts format("%-55s %9.0f  %s", w["workload"], w["ir_per_op"], top.join(", "))
  end
  exit
end

if what == "sites"
  load_label.(prefix, "cpu").each_value do |w|
    puts "== #{w["workload"]}  #{w["ir_per_op"].round} Ir/op, #{w["objects_per_op"]} objects/op"
    w["sites"].first(Integer(n || 15)).each { |s| puts format("  %9.0f %5.1f%% %s:%d %s", s["ir_per_op"], s["ir_per_op"] * 100 / w["ir_per_op"], s["file"], s["line"], s["method"]) }
  end
  exit
end

ra, rb, ma, mb = %w[rel-a rel-b main-a main-b].map { |s| ["#{prefix}-#{s}", s] }
cpu = [ra, rb, ma, mb].to_h { |label, s| [s, load_label.(label, "cpu")] }
obj = [ra, rb, ma, mb].to_h { |label, s| [s, load_label.(label, "objects")] }
puts "| Op | Objects (release) | Ir/op (release) | A/A | Objects (main) | Ir/op (main) | A/A | main vs release |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
cpu["rel-a"].each_key do |name|
  r1, r2, m1, m2 = %w[rel-a rel-b main-a main-b].map { cpu[_1][name]["ir_per_op"] }
  o1, o2 = obj["rel-a"][name]["objects_per_op"], obj["main-a"][name]["objects_per_op"]
  puts "| #{name} | #{o1.round(1)} | #{r1.round} | #{pct.(r1, r2)} | #{o2.round(1)} | #{m1.round} | #{pct.(m1, m2)} | #{pct.((r1 + r2) / 2, (m1 + m2) / 2)} |"
end
