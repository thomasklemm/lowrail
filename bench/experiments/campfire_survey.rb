# frozen_string_literal: true

# Orchestrates untimed, independently booted workers. Never launches Callgrind.
require_relative "campfire_scenario"

module CampfireSurvey
  module_function

  def run(app, seed, output, suite, mode, valgrind = nil)
    raise "dedicated disposable localhost Redis required" unless ENV["CAMPFIRE_DISPOSABLE_REDIS"] == "1"
    receipt = JSON.parse(File.read(suite))
    raise "green own-suite receipt required before census" unless receipt.fetch("identical") &&
      %w[off on].all? do |arm|
        run = receipt.fetch("report").fetch(arm)
        run.fetch("exit_ok") && !run.fetch("tests").empty? && run.fetch("tests").values.all? { %w[pass skip].include?(_1.first) }
      end
    raise "new private output required" if File.exist?(output)
    raise "unknown untimed mode" unless %w[cold census room_cold room_census profile heap].include?(mode)
    raise "heap preflight requires Valgrind tool=none" if mode == "heap" && !valgrind
    manifest = File.join(app, ".lowrail/manifest.json")
    artifact_sha = Digest::SHA256.file(manifest).hexdigest
    FileUtils.mkdir_p(output, mode: 0o700)
    records = %w[off_a off_b on].map do |arm|
      state = File.join(output, "#{arm}-state")
      FileUtils.cp_r(seed, state)
      env = CampfireScenario.environment(app, state).merge(
        "LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_SEALED" => "1",
        "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"),
        "LOWRAIL_STATS" => mode.end_with?("census") ? File.join(output, "#{arm}-stats") : nil,
        "RUBYOPT" => "-rbundler/setup -I#{CampfireScenario::ROOT}/gem/lib -rlowrail/setup")
      # This dedicated local service belongs to the survey, never a real cache.
      require "redis"
      Redis.new(url: env.fetch("REDIS_URL")).flushdb
      destination = File.join(output, "#{arm}.json")
      command = [RbConfig.ruby, File.join(__dir__, "campfire_scenario.rb"), mode, app, state, destination]
      if mode == "heap"
        command.unshift(valgrind, "--tool=none", "--log-file=#{output}/#{arm}-valgrind.log")
        env.merge!("RUBY_GC_HEAP_FREE_SLOTS_MIN_RATIO" => "0", "RUBY_GC_HEAP_FREE_SLOTS_MAX_RATIO" => "0.99",
          "RUBY_GC_HEAP_GROWTH_FACTOR" => "1.0")
        # Exactly the five 4.0 pools used by the shared request protocol.
        [1_000_000, 250_000, 100_000, 20_000, 10_000].each_with_index do |slots, pool|
          env["RUBY_GC_HEAP_#{pool}_INIT_SLOTS"] = slots.to_s
        end
      end
      File.open(File.join(output, "#{arm}.log"), "w") do |log|
        ok = system(env, *command, chdir: app, out: log, err: log)
        raise "#{arm} failed; retain #{log.path}" unless ok
      end
      raise "artifact changed" unless artifact_sha == Digest::SHA256.file(manifest).hexdigest
      record = JSON.parse(File.read(destination))
      record["artifact_sha256"] = artifact_sha
      record["own_suite_sha256"] = Digest::SHA256.file(suite).hexdigest
      # Parent reads after process exit, not an assumed async-completion claim.
      require "sqlite3"
      db = SQLite3::Database.new(File.join(state, "primary.sqlite3"), readonly: true)
      record["exit_database"] = db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").flatten.to_h do |table|
        # FTS includes WITHOUT ROWID shadow tables. Canonicalize full rows,
        # retaining duplicates, rather than assuming a hidden rowid exists.
        rows = db.execute("SELECT * FROM \"#{table.gsub('"', '""')}\"").sort_by { Marshal.dump(_1) }
        [table, {"rows" => rows.size, "sha256" => Digest::SHA256.hexdigest(Marshal.dump(rows))}]
      end
      db.close
      File.write(destination, JSON.pretty_generate(record), perm: 0o600)
      record
    end
    summary = {"mode" => mode, "artifact_sha256" => artifact_sha, "arms" => records.map { _1.except("steps", "routes") }}
    if mode.end_with?("cold")
      base = records.first.fetch("steps")
      summary["comparisons"] = records.drop(1).map do |record|
        steps = record.fetch("steps")
        raise "different request sequence" unless base.size == steps.size
        base.zip(steps).map do |a, b|
          {"method" => a.fetch("method"), "path" => a.fetch("path"), "status" => a.fetch("status"),
            "status_equal" => a.fetch("status") == b.fetch("status"),
            "body_equal" => a.fetch("body") == b.fetch("body"),
            "body_bytes" => [a.fetch("body").bytesize, b.fetch("body").bytesize],
            "different_headers" => (a.fetch("headers").keys | b.fetch("headers").keys).select { a["headers"][_1] != b["headers"][_1] }}
        end
      end
      summary["status"] = summary.fetch("comparisons").flatten.all? do |step|
        step.fetch("status_equal") && step.fetch("body_equal") && step.fetch("different_headers").empty?
      end ? "http_equal_for_executed_scenarios" : "rejected_raw_http_identity"
    elsif mode == "heap"
      summary["status"] = records.all? { _1.fetch("stable") } ? "stable_tool_none_preflight_only" : "rejected_heap_growth"
      summary["brk_overflow"] = Dir[File.join(output, "*-valgrind.log")].any? { File.read(_1).include?("brk segment overflow") }
      summary["status"] = "rejected_brk_overflow" if summary.fetch("brk_overflow")
    else
      summary["routes"] = records.map { _1.fetch("routes") }
    end
    File.write(File.join(output, "summary.json"), JSON.pretty_generate(summary), perm: 0o600)
    puts JSON.generate(mode: mode, status: summary["status"], output: output)
  end
end

if $PROGRAM_NAME == __FILE__
  mode, app, seed, output, suite, valgrind = ARGV
  abort "usage: campfire_survey.rb cold|census|room_cold|room_census|profile|heap APP SEED NEW_PRIVATE_OUTPUT GREEN_SUITE_JSON [VALGRIND]" unless suite
  CampfireSurvey.run(*[app, seed, output, suite].map { File.expand_path(_1) }, mode, valgrind)
end
