# frozen_string_literal: true

# Background census rankings (docs/upstream/background-census.md), from
# script/cpu-census and stackprof_run.rb outputs:
#   ruby rank.rb cpu DIR MODE [rails|gems|all] [LIMIT] [TIERS] [KIND]  Callgrind self Ir by line, breadth first
#   ruby rank.rb stackprof DIR MODE [rails|gems|all] [LIMIT]       stackprof CPU µs by line, same tiers
#   ruby rank.rb kinds DIR MODE                                    Ir per operation by workload kind and app
# Lines are Rails lines (RAILS/...) by default; `gems` ranks lines of gems
# outside Rails keyed by gem name without version, so apps on different
# releases share a key; `all` ranks both.
require "json"
require_relative "../census8/cpu_rank"

module BackgroundRank
  module_function

  def site(file, scope)
    if file.start_with?("RAILS/")
      file.delete_prefix("RAILS/") if scope != "gems"
    elsif scope != "rails" && (m = file.match(%r{\AGEM/[^/]+/(?:gems|bundler/gems)/([A-Za-z0-9_.-]+?)-(?:\d[\w.]*|[0-9a-f]{12})/(.+)\z}))
      "#{m[1]}: #{m[2]}"
    end
  end

  def install(scope)
    CpuRank.singleton_class.send(:define_method, :rails) { |file| BackgroundRank.site(file, scope) }
  end

  # stackprof outputs in CpuRank's shape: µs per operation in place of Ir.
  def stackprof_runs(dir, mode)
    Dir["#{dir}/*-#{mode}.json"].sort.map do |path|
      run = JSON.parse(File.read(path))
      run["workloads"] = run["workloads"].map do |w|
        w.merge("ir_per_op" => w["cpu_us_per_op"], "jit_flat" => true,
          "sites" => w["sites"].map { _1.merge("ir_per_op" => _1["us_per_op"], "native" => 0) })
      end
      run.merge("excluded" => [])
    end
  end

  def kinds(runs)
    rows = Hash.new { |h, k| h[k] = [] }
    runs.each { |r| r["workloads"].each { |w| rows[[w["kind"], r["app"]]] << w["ir_per_op"] } }
    rows.sort.map { |(kind, app), irs| format("%-8s %-12s workloads %3d median Ir/op %10.0f", kind, app, irs.size, irs.sort[irs.size / 2]) }
  end
end

if $PROGRAM_NAME == __FILE__
  command, dir, mode, scope, limit, tiers, kind = ARGV
  mode = { "interp" => "interpreter" }.fetch(mode, mode)
  scope ||= "rails"
  tiers = tiers ? tiers.split(",").map { Integer(_1) } : [7, 5, 3, 2]
  case command
  when "cpu", "stackprof"
    BackgroundRank.install(scope)
    runs = command == "cpu" ? CpuRank.load_runs(dir, mode) : BackgroundRank.stackprof_runs(dir, mode)
    # KIND (enqueue, job, mailer, storage, cable) ranks that kind's workloads only.
    runs = runs.map { |r| r.merge("workloads" => r["workloads"].select { _1["kind"] == kind }) }.reject { _1["workloads"].empty? } if kind
    reach = command == "cpu" ? Integer(ENV.fetch("REACH", CpuRank::REACH)) : Float(ENV.fetch("REACH", "1.0")) # Ir or µs per operation
    rows = CpuRank.rows(runs, tiers: tiers, reach: reach)
    File.write(File.join(dir, "rank-#{command}-#{mode}-#{scope}#{"-#{kind}" if kind}.tsv"), CpuRank.tsv(rows, "line"))
    print CpuRank.text(runs, rows, "line", mode, Integer(limit || 40))
  when "kinds"
    puts BackgroundRank.kinds(CpuRank.load_runs(dir, mode))
  else
    abort File.read(__FILE__).lines.grep(/^#   ruby/).join
  end
end
