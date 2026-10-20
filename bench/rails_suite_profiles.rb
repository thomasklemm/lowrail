# frozen_string_literal: true

# Trusted local StackProf dumps only (Marshal is not safe for untrusted input).
# Usage: ruby bench/rails_suite_profiles.rb DIR/*.stackprof > profiles.json
require "json"
abort "pass Lowrail-off .stackprof files" if ARGV.empty?
totals = {}
profiles = {}
ARGV.each do |path|
  profile = Marshal.load(File.binread(path))
  frames = profile.fetch(:frames)
  keys = frames.to_h do |id, frame|
    file = frame.fetch(:file)
    relative = file[%r{/(activesupport|activemodel|activerecord|actionpack|actionview|activejob|actionmailer|railties)/lib/(.+)}, 0]
    [id, relative && [relative.delete_prefix("/"), frame.fetch(:name)]]
  end
  inclusive = Hash.new(0)
  raw = profile.fetch(:raw)
  total = 0
  index = 0
  while index < raw.size
    depth = raw[index]
    stack = raw.slice(index + 1, depth)
    weight = raw[index + depth + 1]
    total += weight
    stack.filter_map { keys[_1] }.uniq.each { inclusive[_1] += weight }
    index += depth + 2
  end
  label = File.basename(path).delete_suffix("-off-profile.json.stackprof")
  abort "duplicate profile label #{label}: give adapter captures distinct filenames" if profiles.key?(label)
  profiles[label] = { "raw_weight" => total, "samples" => profile[:samples], "missed_samples" => profile[:missed_samples] }
  frames.each do |id, frame|
    key = keys[id] or next
    entry = (totals[key] ||= { "file" => key[0], "method" => key[1], "self_samples" => 0, "suites" => {} })
    entry["self_samples"] += frame.fetch(:samples)
  end
  inclusive.each do |key, samples|
    totals.fetch(key).fetch("suites")[label] = { "inclusive_samples" => samples, "percent" => (100.0 * samples / total).round(4) }
  end
end
rows = totals.values.each do |row|
  # Equal weighting across captures avoids letting AR's larger test count
  # alone choose the shortlist. AV's three task groups remain distinguishable.
  row["mean_percent"] = (row.fetch("suites").values.sum { _1.fetch("percent") } / profiles.size).round(4)
end.sort_by { [-_1.fetch("mean_percent"), -_1.fetch("self_samples"), _1.fetch("method")] }
puts JSON.pretty_generate({ "profiles" => profiles, "methods" => rows })
