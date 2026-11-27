# frozen_string_literal: true
# Page objects for TO1: per page and mode, the median GC-enabled objects per request of main, main again (A/A)
# and the head, and traced objects per request.   ruby objects_table.rb objects/
require "json"
dir = ARGV[0]
def med(a) = a.sort[a.size / 2]
%w[blog writebook casa].each do |app|
  %w[4.0.10:interpreter 4.0.10:yjit master:zjit].each do |rm|
    ruby, mode = rm.split(":")
    v = ->(label) { f = "#{dir}/#{label}/#{app}-#{mode}.json"; next nil unless File.exist?(f); w = JSON.parse(File.read(f))["workloads"][0]; [w["workload"], med(w["gc_enabled_objects_per_op"]), w["traced_gc_objects"] / w["ops"].to_f, w["gc_windows"].map { _1["wall_ms_per_op"] }.min] }
    a, a2, h = v.("main-#{ruby}"), v.("main-#{ruby}2"), v.("to1-#{ruby}")
    next unless a && a2 && h
    puts [app, a[0], rm, "main #{a[1]} / #{a2[1]}", "to1 #{h[1]}", "Δ #{(h[1] - (a[1] + a2[1]) / 2).round(1)}", "traced #{a[2]} / #{a2[2]} → #{h[2]}", "ms #{a[3]}"].join(" | ")
  end
end
