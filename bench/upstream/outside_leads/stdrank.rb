# frozen_string_literal: true

# ruby stdrank.rb DIR MODE [owners|methods|incl|cfuncs|objmethods|perapp] [FILTER_REGEX] [LIMIT]
# Mean share of each workload's attributed samples (samples - gc - wait), averaged over all workloads.
require "json"
dir, mode, what, filter, limit = ARGV
what ||= "owners"
limit = Integer(limit || 40)
filter = Regexp.new(filter || ".")
runs = Dir["#{dir}/*-#{mode}.json"].sort.map { JSON.parse(File.read(_1)) }
wls = runs.flat_map { |r| r["workloads"].map { [r["app"], _1] } }
n = wls.size
acc = Hash.new { |h, k| h[k] = { share: 0.0, apps: Hash.new(0.0), us: 0.0, wl: 0, obj: 0.0 } }
wls.each do |app, w|
  denom = (w["samples"] - w["gc"] - w["wait"]).to_f
  next if denom <= 0
  table = case what
  when "owners" then w["owners"]
  when "methods" then w["methods"]
  when "incl" then w["incl"]
  when "inclown" then w["incl_own"]
  when "cfuncs" then w["cfuncs"]
  when "callers" then w["std_callers"]
  when "owncallers" then w["own_callers"]
  when "objmethods" then w["objects"]["methods"]
  when "objowners" then w["objects"]["owners"]
  end
  table.each do |k, v|
    next unless k.match?(filter)
    a = acc[k]
    if what.start_with?("obj")
      per = v.fdiv(w["objects_ops"])
      a[:obj] += per
      a[:share] += v.fdiv(w["objects"]["samples"].nonzero? || 1)
      a[:apps][app] += per
    else
      s = v / denom
      a[:share] += s
      a[:us] += s * w["cpu_us_per_op"]
      a[:apps][app] += s
    end
    a[:wl] += 1
  end
end
per_app_n = wls.group_by(&:first).transform_values(&:size)
puts "#{runs.size} runs, #{per_app_n.size} apps, #{n} workloads (#{mode}, #{what})"
acc.sort_by { -_2[:share] }.first(limit).each do |k, a|
  apps = a[:apps].map { |app, s| "#{app} #{format(what.start_with?("obj") ? "%.1f" : "%.2f%%", what.start_with?("obj") ? s / per_app_n[app] : 100 * s / per_app_n[app])}" }.join(", ")
  if what.start_with?("obj")
    printf("%6.2f obj/op %5.2f%% wl %3d  %-90s  %s\n", a[:obj] / n, 100 * a[:share] / n, a[:wl], k[0, 90], apps)
  else
    printf("%6.3f%% %7.1f us/op wl %3d  %-90s  %s\n", 100 * a[:share] / n, a[:us] / n, a[:wl], k[0, 90], apps)
  end
end
