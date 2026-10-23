# frozen_string_literal: true

# Four fresh native YJIT A/B/A blocks; optional existing fixed-heap counter.
# ruby bench/experiments/advise_patch_study.rb BASE FORK WORKLOAD NEW_OUT [--counter]
require_relative "../request_pairs"

module AdvisePatchStudy
  # Preserve original bytes except explicitly declared, counted substitutions.
  # Retain raw hashes too; this never normalizes SQL, HTML structure or cookies
  # other than the exact fields named in policy expressions.
  def self.response_fingerprint(response, policy = {})
    body = response.body
    headers = response.headers.to_h
    raw = { status: response.status, bytes: body.bytesize, body_sha256: Digest::SHA256.hexdigest(body),
      headers_sha256: Digest::SHA256.hexdigest(JSON.generate(headers.sort.to_h)) }
    replace = ->(value, rule) {
      pattern = Regexp.new(rule.fetch("pattern"))
      values = value.is_a?(Array) ? value : [value]
      raise "entropy field multiplicity changed: #{rule.fetch('name')}" unless values.sum { _1.scan(pattern).size } == rule.fetch("count")
      replaced = values.map { _1.gsub(pattern, rule.fetch("replacement")) }
      value.is_a?(Array) ? replaced : replaced.first
    }
    policy.fetch("body", []).each { body = replace.call(body, _1) }
    headers = headers.dup
    policy.fetch("headers", {}).each do |name, rules|
      (rules.is_a?(Array) ? rules : [rules]).each do |rule|
        headers[name] = replace.call(headers.fetch(name), rule)
      end
    end
    raw.merge(controlled_body_sha256: Digest::SHA256.hexdigest(body),
      controlled_headers_sha256: Digest::SHA256.hexdigest(JSON.generate(headers.sort.to_h)))
  end

  def self.t95(values)
    raise "four independent blocks required" unless values.size == 4
    mean = values.sum / 4.0
    se = Math.sqrt(values.sum { (_1 - mean)**2 } / 3.0 / 4.0)
    { mean: mean, t95: [mean - 3.182446305 * se, mean + 3.182446305 * se], blocks: values }
  end

  # The explicit allowlist certifies that a candidate statement is a pure read;
  # a SELECT prefix alone cannot establish that (functions can write). Refuse
  # unknown changes, locks and any intervening non-SELECT conservatively.
  # Events: [statement, exact binds, cached, connection index, name, row count].
  def self.sql_comparison(base, patch, permitted_reads: [])
    retained, seen, dropped = 0, {}, []
    base.each_with_index do |event, index|
      statement, binds, _, connection = event
      read = statement.match?(/\ASELECT\b/i) && !statement.match?(/\b(?:FOR\s+(?:UPDATE|SHARE|NO\s+KEY|KEY\s+SHARE)|LOCK)\b/i)
      identity = [connection, statement, binds]
      if retained < patch.size && event == patch[retained]
        retained += 1
      elsif read && seen.key?(identity) && permitted_reads.include?([statement, binds])
        dropped << { position: index + 1, earlier_position: seen.fetch(identity),
          statement: statement, binds: binds, cached: event[2], connection: connection }
      else
        return { pass: false, position: index + 1, dropped: dropped }
      end
      read ? seen[identity] = index + 1 : seen.clear
    end
    { pass: retained == patch.size, dropped: dropped }
  end

  def self.exact_comparison(workers, permitted_reads: [])
    base = workers.fetch("off_a").fetch("exact").first
    responses = workers.values.flat_map { _1.fetch("exact") }
    comparisons = workers.transform_values do |worker|
      worker.fetch("exact").map do |row|
        sql_comparison(base.fetch("sql"), row.fetch("sql"), permitted_reads: permitted_reads)
      end
    end
    # Baselines must match without dropping anything, including A/A entropy.
    aa = workers.reject { |name, _| name == "on" }.values.all? do |worker|
      worker.fetch("exact").all? { _1.fetch("sql") == base.fetch("sql") }
    end
    { responses_equal: responses.map { _1.values_at("status", "controlled_body_sha256", "controlled_headers_sha256") }.uniq.one?,
      sql_pass: aa && comparisons.values.flatten.all? { _1.fetch(:pass) }, sql: comparisons,
      same_dependencies: workers.values.map { _1.fetch("lock_sha256") }.uniq.one? }
  end

  def self.run(base, fork, workload, out, counter: false)
    [base, fork].each do |app|
      raise "dedicated corpus checkout required" unless File.realpath(app).start_with?(File.expand_path("../../.corpus/", __dir__) + "/")
    end
    raise "new output required; no retries" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    worker = File.join(__dir__, "advise_patch_worker.rb")
    entropy = ENV["ADVISE_ENTROPY"] && File.realpath(ENV.fetch("ADVISE_ENTROPY"))
    permitted_reads = ENV["ADVISE_SQL_READS"] ? JSON.parse(File.read(ENV.fetch("ADVISE_SQL_READS"))) : []
    env = { "RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0", "RUBYOPT" => nil,
      "BUNDLE_GEMFILE" => nil, "BUNDLE_FROZEN" => "true", "BENCH_JIT" => "1",
      "BENCH_JIT_MAX_WARMUP" => ENV.fetch("BENCH_JIT_MAX_WARMUP", "100000"),
      "BENCH_REQUESTS" => "1000", "ADVISE_SCREEN" => nil, "ADVISE_COUNTER" => nil,
      "ADVISE_WORKLOAD" => workload, "ADVISE_ENTROPY" => entropy, "DATABASE_URL" => ENV["DATABASE_URL"], "BENCH_JOBS" => "1" }
    pins = [base, fork].to_h do |app|
      [app, Dir.glob(File.join(app, "{app,config,lib}/**/*")).select { File.file?(_1) }.sort.to_h {
        [_1.delete_prefix(app + "/"), Digest::SHA256.file(_1).hexdigest] }]
    end
    File.write(File.join(out, "protocol.json"), JSON.pretty_generate(base: base, fork: fork,
      workload: Digest::SHA256.file(workload).hexdigest, source_pins: pins,
      entropy: entropy && { sha256: Digest::SHA256.file(entropy).hexdigest, policy: JSON.parse(File.read(entropy)) },
      certified_duplicate_reads: permitted_reads,
      rails_env: "production", warmup_cap: env.fetch("BENCH_JIT_MAX_WARMUP"),
      blocks: 4, native_requests: 1000, counter_requests: 10, retry: false,
      acceptance: "production eager load/cache, full bodies/headers/status identical except declared counted entropy fields, only certified exact duplicate SELECTs may drop without intervening writes/locks/transactions; retained SQL exact, app full suite green, native t95 upper < 0, A/A intervals within ±2%, flat JIT; Callgrind/A/A supporting only"))
    screens = {}
    { "off_a" => base, "on" => fork, "off_b" => base }.each do |arm, app|
      log = File.join(out, "screen-#{arm}.log")
      ok = system(env.merge("ADVISE_SCREEN" => "1"), RbConfig.ruby, *JitStability.flags("1"), worker,
        chdir: app, out: log, err: [:child, :out])
      unless ok
        result = { accepted: false, rejected: "production boot/workload screen", failed_arm: arm, log: log,
          completed_native_blocks: 0, counter: "not run; failed prerequisite" }
        File.write(File.join(out, "result.json"), JSON.pretty_generate(result))
        puts JSON.pretty_generate(result)
        return
      end
      line = File.foreach(log).find { _1.start_with?("LOWRAIL_BENCH ") }
      screens[arm] = JSON.parse(line.delete_prefix("LOWRAIL_BENCH "))
    end
    screen = exact_comparison(screens, permitted_reads: permitted_reads)
    unless screen[:responses_equal] && screen[:sql_pass] && screen[:same_dependencies]
      result = { accepted: false, rejected: "response/SQL screen (only declared entropy exempted)", screen: screens,
        completed_native_blocks: 0, counter: "not run; failed prerequisite" }
      File.write(File.join(out, "result.json"), JSON.pretty_generate(result))
      puts JSON.pretty_generate(result)
      return
    end
    if counter
      # Interpreter Ir is supporting evidence, never the acceptance gate.
      ENV["BENCH_JIT"] = "0"
      ENV["BENCH_JOBS"] = "1"
      environments = { "off_a" => env.merge("BENCH_WORKDIR" => base),
        "on" => env.merge("BENCH_WORKDIR" => fork), "off_b" => env.merge("BENCH_WORKDIR" => base) }.
        transform_values { _1.merge("ADVISE_COUNTER" => "1", "BENCH_JIT" => "0") }
      metadata = { seed: 41231, rounds: 4, workers: {} }
      passed = RequestPairs.heap_instructions(environments, base, out, "", metadata,
        worker: worker, requests: 10)
      File.write(File.join(out, "result.json"), JSON.pretty_generate(counter_controls_pass: passed,
        summary: JSON.parse(File.read(File.join(out, "summary.json")))))
      return
    end
    rows, workers = [], {}
    4.times do |block|
      row = {}
      { "off_a" => base, "on" => fork, "off_b" => base }.each do |arm, app|
        label = "#{block}-#{arm}"
        log = File.join(out, "#{label}.log")
        ok = system(env, RbConfig.ruby, *JitStability.flags("1"), worker,
          chdir: app, out: log, err: [:child, :out])
        unless ok
          result = { accepted: false, rejected: "native worker failed (including non-flat warmup refusal)",
            failed_worker: label, log: log, completed_native_blocks: rows.size, workers: workers,
            counter: "separate supporting run only; no valid native gain" }
          File.write(File.join(out, "result.json"), JSON.pretty_generate(result), perm: 0o600)
          puts JSON.pretty_generate(result)
          return
        end
        line = File.foreach(log).find { _1.start_with?("LOWRAIL_BENCH ") }
        row[arm] = workers[label] = JSON.parse(line.delete_prefix("LOWRAIL_BENCH "))
      end
      rows << row
      File.write(File.join(out, "samples.json"), JSON.pretty_generate(rows), perm: 0o600)
      warn "native A/B/A block #{block + 1}/4"
    end
    metrics = %w[cpu_us wall_us allocations].to_h do |metric|
      values = rows.map { |row| 100 * (row.fetch("on").fetch(metric) / ((row.fetch("off_a").fetch(metric) + row.fetch("off_b").fetch(metric)) / 2) - 1) }
      drift = rows.map { |row| 100 * (row.fetch("off_b").fetch(metric) / row.fetch("off_a").fetch(metric) - 1) }
      [metric, { delta_pct: t95(values), aa_pct: t95(drift) }]
    end
    exact = workers.values.flat_map { _1.fetch("exact") }
    comparisons = rows.map { exact_comparison(_1, permitted_reads: permitted_reads) }
    # The same baseline trace/response must also hold across independent blocks.
    baseline = rows.first.fetch("off_a").fetch("exact").first
    aa = rows.all? do |row|
      %w[off_a off_b].all? { |arm| row.fetch(arm).fetch("exact").all? { _1.fetch("sql") == baseline.fetch("sql") } }
    end
    result = { metrics: metrics, jit: JitStability.control(workers, requested: "1"),
      raw_body_equal: exact.map { _1.values_at("status", "body_sha256", "bytes") }.uniq.one?,
      raw_headers_equal: exact.map { _1.fetch("headers_sha256") }.uniq.one?,
      controlled_body_equal: exact.map { _1.values_at("status", "controlled_body_sha256") }.uniq.one?,
      controlled_headers_equal: exact.map { _1.fetch("controlled_headers_sha256") }.uniq.one?,
      sql_equal: exact.map { _1.values_at("sql_n", "sql_sha256") }.uniq.one?,
      sql_gate_pass: aa && comparisons.all? { _1[:sql_pass] }, sql_comparisons: comparisons,
      same_dependencies: workers.values.map { _1.fetch("lock_sha256") }.uniq.one?,
      sql_counts: workers.transform_values { _1.fetch("exact").map { |row| row.fetch("sql_n") } },
      acceptance: "not accepted by timing alone; require full suite, exact responses/SQL, flat JIT and A/A; Callgrind supports only", retry: false }
    result[:native_gate_pass] = result[:jit].fetch(:pass) && result[:controlled_body_equal] &&
      result[:controlled_headers_equal] && result[:sql_gate_pass] && result[:same_dependencies] && %w[cpu_us wall_us].all? do |metric|
        bounds = metrics.fetch(metric).fetch(:aa_pct).fetch(:t95)
        metrics.fetch(metric).fetch(:delta_pct).fetch(:t95).last < 0 && bounds.first >= -2 && bounds.last <= 2
      end
    File.write(File.join(out, "result.json"), JSON.pretty_generate(result), perm: 0o600)
    puts JSON.pretty_generate(result)
  end
end

if $PROGRAM_NAME == __FILE__
  base, fork, workload, out, mode = ARGV
  abort "usage: advise_patch_study.rb BASE FORK WORKLOAD NEW_OUT [--counter]" unless out && [nil, "--counter"].include?(mode)
  AdvisePatchStudy.run(File.realpath(base), File.realpath(fork), File.realpath(workload), File.expand_path(out), counter: mode == "--counter")
end
