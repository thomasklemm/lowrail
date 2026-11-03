# frozen_string_literal: true

# Breadth-first site ranking (census 4's rails_main_census_4_rank.rb, with the
# tier boundaries as a parameter). A Rails source line "reaches" a workload
# when it allocates >= 0.5 objects per operation there. Apps are counted once
# (fizzy and fizzy-mysql are one app). Lines are tiered by apps reached (default
# >= 7, 5-6, 3-4, 2, 1); within a tier, by the mean objects per operation over
# every workload of every app (per-call cost times how often an ordinary
# operation reaches the line).
require "json"

module CensusRank
  TIERS = [7, 5, 3, 2].freeze
  REACH = 0.5

  module_function

  def app_of(name) = name.sub(/-(mysql|nops)\z/, "")

  def load_runs(dir, mode) = Dir["#{dir}/*-#{mode}.json"].sort.map { JSON.parse(File.read(_1)) }

  def rows(runs, tiers: TIERS)
    workloads = runs.flat_map { |run| run["workloads"].map { [run["app"], _1] } }
    total = workloads.size
    sites = Hash.new { |h, k| h[k] = { per_workload: Hash.new(0.0), classes: Hash.new(0.0) } }
    workloads.each do |app, w|
      w["sites"].each do |s|
        next unless s["file"].start_with?("RAILS/")
        key = "#{s["file"].delete_prefix("RAILS/")}:#{s["line"]}"
        sites[key][:per_workload][[app, w["workload"], w["kind"]]] += s["objects_per_op"]
        sites[key][:classes][s["class"]] += s["objects_per_op"]
      end
    end
    tier = ->(apps) { tiers.index { apps >= _1 } || tiers.size }
    rows = sites.map do |key, data|
      hit = data[:per_workload].select { |_, v| v >= REACH }
      apps = hit.keys.map { app_of(_1[0]) }.uniq
      { site: key, apps: apps.size, app_names: apps.sort, share: hit.size.fdiv(total),
        kinds: hit.keys.map { _1[2] }.uniq.sort, mean: data[:per_workload].values.sum / total,
        classes: data[:classes].sort_by { -_2 }.first(2).map(&:first) }
    end
    rows.select { _1[:apps] > 0 }.sort_by { [tier.(_1[:apps]), -_1[:mean]] }
  end

  def tsv(rows)
    lines = [%w[rank site apps share mean_objects_per_op kinds classes app_names].join("\t")]
    rows.each_with_index do |r, i|
      lines << [i + 1, r[:site], r[:apps], r[:share].round(3), r[:mean].round(2), r[:kinds].join(","),
        r[:classes].join(","), r[:app_names].join(",")].join("\t")
    end
    lines.join("\n") + "\n"
  end

  def text(runs, rows, mode, limit)
    total = runs.sum { _1["workloads"].size }
    lines = ["#{runs.size} runs, #{runs.map { app_of(_1["app"]) }.uniq.size} apps, #{total} workloads (#{mode})"]
    rows.first(limit).each_with_index do |r, i|
      lines << format("%3d %-78s apps %d share %4.0f%% mean %6.2f %-22s %s", i + 1, r[:site][0, 78], r[:apps],
        r[:share] * 100, r[:mean], r[:kinds].join(","), r[:classes].join(","))
    end
    lines.join("\n") + "\n"
  end
end
