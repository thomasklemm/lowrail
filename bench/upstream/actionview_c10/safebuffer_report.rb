# frozen_string_literal: true

# Summarizes safebuffer_count.rb outputs:
#   ruby safebuffer_report.rb DIR NS_INTERP NS_YJIT [APPS...]
# NS_*: the extra ns per SafeBuffer.new from the micro (miss minus fast path).
require "json"

dir, ns_i, ns_y, *apps = ARGV
ns = { "interpreter" => Float(ns_i), "yjit" => Float(ns_y) }
apps = Dir[File.join(dir, "*-interpreter.json")].map { File.basename(_1, "-interpreter.json") }.sort if apps.empty?

puts "| App | Workloads (with any) | SafeBuffer.new per op, mean (max) | of them on an already-safe argument | wall per op interp / YJIT, mean | share interp / YJIT, mean (max) |"
puts "| --- | ---: | ---: | ---: | ---: | ---: |"
sites = Hash.new { |h, k| h[k] = { apps: [], per_op: 0.0, safe: 0.0, workloads: 0 } }
total_workloads = 0
apps.each do |app|
  runs = ns.keys.to_h { |m| [m, JSON.parse(File.read(File.join(dir, "#{app}-#{m}.json")))["workloads"]] }
  wi = runs["interpreter"]
  wy = runs["yjit"].to_h { [_1["workload"], _1] }
  shares = wi.map do |w|
    y = wy.fetch(w["workload"])
    n = w["safebuffer_new_per_op"]
    [n * ns["interpreter"] / w["wall_ns_per_op_median"], n * ns["yjit"] / y["wall_ns_per_op_median"]]
  end
  with = wi.count { _1["safebuffer_new_per_op"] > 0 }
  mean = ->(a) { a.sum / a.size }
  puts format("| %s | %d (%d) | %.1f (%.0f) | %.1f | %.2f / %.2f ms | %.2f%% / %.2f%% (%.2f%% / %.2f%%) |", app, wi.size, with,
    mean.(wi.map { _1["safebuffer_new_per_op"] }), wi.map { _1["safebuffer_new_per_op"] }.max,
    mean.(wi.map { _1["already_safe_arg_per_op"] }),
    mean.(wi.map { _1["wall_ns_per_op_median"] }) / 1e6, mean.(wi.map { wy.fetch(_1["workload"])["wall_ns_per_op_median"] }) / 1e6,
    100 * mean.(shares.map(&:first)), 100 * mean.(shares.map(&:last)), 100 * shares.map(&:first).max, 100 * shares.map(&:last).max)
  total_workloads += wi.size
  wi.each do |w|
    w["sites"].each do |s|
      row = sites[[s["via"], s["creator"].sub(/_app_views_\S+/, "TEMPLATE")]]
      row[:apps] |= [app]
      row[:per_op] += s["per_op"]
      row[:safe] += s["already_safe_per_op"]
    end
  end
end
puts
puts "Top creators (per op summed over all #{total_workloads} workloads, then divided by them):"
sites.sort_by { -_2[:per_op] }.first(Integer(ENV.fetch("TOP", "30"))).each do |(via, creator), r|
  puts format("%7.2f %6.2f safe-arg  %-9s %-110s %s", r[:per_op] / total_workloads, r[:safe] / total_workloads, via, creator, r[:apps].join(","))
end
