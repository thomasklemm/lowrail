# frozen_string_literal: true

# Where request CPU goes, by owner (prof.rb receipts): mean share of each
# workload's samples outside I/O wait, over every workload of every app.
#   ruby owners.rb DIR LABEL MODE
require "json"
dir, label, mode = ARGV
mode = { "interp" => "interpreter" }.fetch(mode, mode)
rows = Dir[File.join(dir, label, "*-#{mode}.json")].flat_map { JSON.parse(File.read(_1))["workloads"] }
share = Hash.new(0.0)
rows.each do |w|
  total = (w["samples"] - w["wait"]).to_f
  next if total <= 0
  w["owners"].each { |k, v| share[k.start_with?("gem:") ? "gems" : k] += v / total / rows.size }
  share["gc"] += w["gc"] / total / rows.size
end
puts "#{label} #{mode}: #{rows.size} workloads; " + share.sort_by { -_2 }.map { |k, v| "#{k} #{(v * 100).round(1)}%" }.join(", ")
