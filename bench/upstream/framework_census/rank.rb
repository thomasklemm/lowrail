# frozen_string_literal: true

# Framework census ranking: census ranking (../census/rank.rb, breadth first:
# apps reached, then mean objects per operation over every workload) restricted
# to the request/job frameworks other than Active Record, overall and per
# framework.
#   ruby rank.rb RUN_DIR MODE [LIMIT] [PER_FRAMEWORK_LIMIT]
# RUN_DIR is a script/census label directory (e.g. .lowrail/private/census/base2).
require_relative "../census/rank"

module FrameworkRank
  FRAMEWORKS = %w[actionview actionpack activesupport activejob actionmailer railties activemodel].freeze

  module_function

  def framework(site) = site[%r{\A[^/]+}]

  def rows(dir, mode)
    runs = CensusRank.load_runs(dir, mode)
    raise "no #{mode} runs in #{dir}" if runs.empty?
    all = CensusRank.rows(runs)
    # Rank within the full ordering, so a site's overall rank is kept.
    all.each_with_index { |r, i| r[:overall] = i + 1 }
    [runs, all.select { FRAMEWORKS.include?(framework(_1[:site])) }]
  end

  def line(r, i)
    format("%3d %4d %-74s apps %d share %4.0f%% mean %6.2f %-26s %s", i + 1, r[:overall], r[:site][0, 74], r[:apps],
      r[:share] * 100, r[:mean], r[:kinds].join(","), r[:classes].join(","))
  end

  def report(dir, mode, limit, per)
    runs, rows = rows(dir, mode)
    total = runs.sum { _1["workloads"].size }
    out = ["#{runs.size} runs, #{total} workloads (#{mode}); columns: rank among framework lines, overall rank, site"]
    out << "== all seven frameworks"
    rows.first(limit).each_with_index { |r, i| out << line(r, i) }
    FRAMEWORKS.each do |fw|
      sub = rows.select { framework(_1[:site]) == fw }
      out << "== #{fw} (#{sub.size} lines, #{sub.count { _1[:apps] >= 7 }} reach >= 7 apps)"
      sub.first(per).each_with_index { |r, i| out << line(r, i) }
    end
    out.join("\n") + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  dir, mode, limit, per = ARGV
  print FrameworkRank.report(dir, mode || "interpreter", Integer(limit || 80), Integer(per || 25))
end
