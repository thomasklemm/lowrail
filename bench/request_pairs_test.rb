# frozen_string_literal: true

require "minitest/autorun"
require_relative "request_pairs"
require_relative "gc_requests"

class RequestPairsTest < Minitest::Test
  def test_jit_gate_rejects_wrong_modes_missing_counters_and_nonflat_windows
    { "yjit" => %w[compiled_iseq_count compiled_block_count invalidation_count],
      "zjit" => %w[compiled_iseq_count failed_iseq_count compiled_side_exit_count compile_time_ns invalidation_time_ns invalidation_count] }.each do |jit, keys|
      counters = keys.to_h { [_1, 17] }
      worker = { "yjit" => jit == "yjit", "zjit" => jit == "zjit",
        "jit_warmup" => { "stable" => true, "consecutive_flat_windows" => 3 },
        "windows" => [{ "jit_before" => counters.dup, "jit_after" => counters.dup }] }
      assert JitStability.control({ "worker" => worker }, requested: jit).fetch(:pass)
      refute JitStability.control({ "worker" => worker }, requested: "0").fetch(:pass)
      counters.each_key do |key|
        worker["windows"][0]["jit_after"][key] = 18
        refute JitStability.control({ "worker" => worker }, requested: jit).fetch(:pass), key
        worker["windows"][0]["jit_after"][key] = 17
        worker["windows"][0]["jit_before"].delete(key)
        result = JitStability.control({ "worker" => worker }, requested: jit)
        refute result.fetch(:pass), key
        assert_includes result.fetch(:workers).fetch("worker").fetch(:missing_counters), key.to_sym
        worker["windows"][0]["jit_before"][key] = 17
      end
      worker["jit_warmup"]["consecutive_flat_windows"] = 2
      refute JitStability.control({ "worker" => worker }, requested: jit).fetch(:pass)
    end
  end

  def test_partial_zjit_flatness_never_substitutes_for_missing_invalidation_proof
    keys = %w[compiled_iseq_count failed_iseq_count compiled_side_exit_count compile_time_ns invalidation_time_ns]
    counters = keys.to_h { [_1, 17] }.merge("invalidation_count" => nil)
    worker = { "yjit" => false, "zjit" => true,
      "jit_warmup" => { "stable" => false, "observed_counters_flat" => true, "consecutive_flat_windows" => 3,
        "history" => [0, 200, 400, 600].map { { "requests" => _1, "counters" => counters.dup } } },
      "windows" => [{ "jit_before" => counters.dup, "jit_after" => counters.dup }] }
    result = JitStability.control({ "worker" => worker }, requested: "zjit")
    refute result.fetch(:pass)
    assert result.fetch(:partial_gate).fetch(:pass)
    keys.each do |key|
      worker["windows"][0]["jit_after"][key] = 18
      refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass), key
      worker["windows"][0]["jit_after"][key] = 17
      worker["jit_warmup"]["history"][1]["counters"][key] = 16
      refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass), key
      worker["jit_warmup"]["history"][1]["counters"][key] = nil
      refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass), key
      worker["jit_warmup"]["history"][1]["counters"][key] = 17
    end
    first = worker["jit_warmup"]["history"].shift
    refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass)
    worker["jit_warmup"]["history"].unshift(first)
    worker["yjit"] = true
    refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass)
    worker["yjit"] = false
    worker["windows"].clear
    refute JitStability.control({ "worker" => worker }, requested: "zjit").fetch(:partial_gate).fetch(:pass)
    refute JitStability.control({}, requested: "zjit").fetch(:partial_gate).fetch(:pass)
  end

  def test_brk_overflow_rejects_the_cohort_in_preflight_or_a_successful_worker
    saved = ENV.to_h.slice("PATH", "PROBE_WARNING", "BENCH_HEAP_SLOTS", "BENCH_JIT")
    Dir.mktmpdir("lowrail-brk-refusal-test") do |dir|
      executable = File.join(dir, "valgrind")
      File.write(executable, <<~RUBY)
        #!#{RbConfig.ruby}
        if ARGV.include?("--version")
          puts "valgrind-log-contract-probe"
          exit
        end
        preflight = ARGV.include?("--tool=none")
        log = ARGV.find { _1.start_with?("--log-file=") }.delete_prefix("--log-file=")
        warning = ENV["PROBE_WARNING"] == (preflight ? "preflight" : "worker")
        File.write(log, warning ? "==123== brk segment overflow in thread #1: can't grow\\n" : "==123== clean log\\n")
        # A warning does not make Valgrind exit unsuccessfully on its own.
        exit 0
      RUBY
      FileUtils.chmod(0o755, executable)
      ENV.update("PATH" => "#{dir}:#{ENV.fetch('PATH')}", "BENCH_HEAP_SLOTS" => Array.new(GC.stat_heap.size, 10_000).join(","), "BENCH_JIT" => "0")
      %w[preflight worker].each do |phase|
        ENV["PROBE_WARNING"] = phase
        out = File.join(dir, phase)
        FileUtils.mkdir_p(out)
        error = assert_raises(RuntimeError) do
          RequestPairs.heap_instructions({ "off_a" => {} }, dir, out, "GET:/", { rounds: 1, seed: 1, workers: {} })
        end
        assert_match "Valgrind brk reservation exhausted", error.message
        rejection = JSON.parse(File.read(File.join(out, "valgrind-rejected.json")))
        refute rejection.fetch("accepted")
        assert_equal phase == "preflight" ? "preflight" : "0-off_a", rejection.fetch("worker")
        refute File.exist?(File.join(out, "summary.json")), "no accepted summary may survive an overflow"
      end
    end
  ensure
    %w[PATH PROBE_WARNING BENCH_HEAP_SLOTS BENCH_JIT].each { ENV[_1] = saved[_1] }
  end

  def test_instruction_reader_uses_self_totals_not_wrapped_summary
    Dir.mktmpdir("lowrail-profile-test") do |dir|
      path = File.join(dir, "profile")
      File.write(path, "events: Ir\nsummary: 18446744073709122988\nfl=probe.c\nfn=work\n1 1610\ntotals: 1610\n")
      assert_equal 1610, RequestPairs.instruction_total(path)
    end
  end

  def test_jit_gate_requires_actual_mode_and_flat_warmup_and_measurement
    counters = { "compiled_iseq_count" => 73, "compiled_block_count" => 901, "invalidation_count" => 12 }
    worker = { "yjit" => true, "jit_warmup" => { "stable" => true, "consecutive_flat_windows" => 3 },
      "windows" => [{ "jit_before" => counters, "jit_after" => counters.dup }] }
    assert JitStability.control({ "on" => worker }, requested: true).fetch(:pass)
    counters.each_key do |key|
      changed = Marshal.load(Marshal.dump(worker))
      changed.fetch("windows").first.fetch("jit_after")[key] += 1
      refute JitStability.control({ "on" => changed }, requested: true).fetch(:pass), key
    end
    worker.fetch("jit_warmup")["stable"] = false
    refute JitStability.control({ "on" => worker }, requested: true).fetch(:pass)
    worker["jit_warmup"] = nil
    refute JitStability.control({ "on" => worker }, requested: true).fetch(:pass)
    worker["yjit"] = false
    result = JitStability.control({ "on" => worker }, requested: true)
    refute result.fetch(:pass)
    assert_equal [false], result.fetch(:actual_yjit)
    assert JitStability.control({ "off" => worker }, requested: false).fetch(:pass)
    worker["yjit"] = true
    result = JitStability.control({ "unexpected" => worker }, requested: false)
    refute result.fetch(:pass)
    assert_equal [true], result.fetch(:actual_yjit)
  end

  def test_comparisons_refuse_an_ar_build_that_would_silently_decline
    saved = ENV.to_h.slice("BENCH_COUNTER", "BENCH_INSTANTIATE_DIR", "BENCH_ROUNDS", "BENCH_LOWRAIL_LIB")
    Dir.mktmpdir("lowrail-stale-build-test") do |dir|
      FileUtils.mkdir_p(File.join(dir, ".lowrail"))
      normal = { rails_env: "production", files: {}, templates: {}, units: [] }
      File.write(File.join(dir, ".lowrail/manifest.json"), JSON.generate(normal))
      extra = File.join(dir, "extra")
      FileUtils.mkdir_p(extra)
      units = [{ pass: "active_record/instantiate", ar_instantiate: { sources: { File.join(dir, "missing.rb") => "obsolete" } } }]
      File.write(File.join(extra, "manifest.json"), JSON.generate(normal.merge(units: units)))
      ENV.update("BENCH_INSTANTIATE_DIR" => extra, "BENCH_ROUNDS" => "8")
      [nil, "callgrind", "gc"].each_with_index do |counter, index|
        ENV["BENCH_COUNTER"] = counter
        error = assert_raises(RuntimeError) { RequestPairs.run(dir, File.join(dir, "out-#{index}"), "GET:/") }
        assert_match "AR build sources changed", error.message
      end
      # The checkout matches, but the library actually loaded by workers
      # does not. It must not masquerade as an active certified AR build.
      certified = File.expand_path("../gem/lib/lowrail/ar_guard.rb", __dir__)
      units.first[:ar_instantiate][:sources] = { certified => Digest::SHA256.file(certified).hexdigest }
      File.write(File.join(extra, "manifest.json"), JSON.generate(normal.merge(units: units)))
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "lowrail"))
      File.write(File.join(lib, "lowrail/ar_guard.rb"), "obsolete")
      ENV["BENCH_LOWRAIL_LIB"] = lib
      error = assert_raises(RuntimeError) { RequestPairs.run(dir, File.join(dir, "out-override"), "GET:/") }
      assert_match "AR build sources changed", error.message
    end
  ensure
    %w[BENCH_COUNTER BENCH_INSTANTIATE_DIR BENCH_ROUNDS BENCH_LOWRAIL_LIB].each { ENV[_1] = saved[_1] }
  end

  def test_gc_exclusion_preserves_mutator_work_between_incremental_segments
    skip "Valgrind not installed" unless system("sh", "-c", "command -v valgrind >/dev/null")
    Dir.mktmpdir("lowrail-counter-test") do |dir|
      extension = RequestPairs.compile_counter_extension(dir)
      script = File.join(dir, "probe.rb")
      File.write(script, <<~'RUBY')
        require ARGV.fetch(0)
        mode = ARGV.fetch(1)
        roots = Array.new(200_000) { "a" * 48 }
        3.times { GC.start }
        GC.disable if mode == "disabled"
        pending = 0
        checksum = 0
        LowrailCallgrindBench.start(mode == "excluded")
        10.times do
          GC.start(immediate_mark: false, immediate_sweep: false) unless mode == "disabled"
          pending += 1 if GC.latest_gc_info(:state) != :none
          5000.times { checksum = (checksum * 1664525 + 1013904223) & 0xffffffff }
        end
        segments = LowrailCallgrindBench.finish
        puts [checksum, pending, segments, roots.size].join(",")
      RUBY
      results = %w[disabled total excluded].to_h do |mode|
        output = File.join(dir, mode)
        text, status = Open3.capture2e({ "RUBYOPT" => nil }, "valgrind", "--tool=callgrind",
          "--instr-atstart=no", "--callgrind-out-file=#{output}", "--log-file=#{output}.log",
          RbConfig.ruby, "--disable-yjit", script, extension, mode)
        assert status.success?, text
        instructions = RequestPairs.instruction_total("#{output}.1")
        [mode, { data: text.strip.split(",").map(&:to_i), instructions: instructions }]
      end
      # Independent affine-transform exponentiation modulo 2**32 gives this
      # 50,000-step LCG reference, not the counter's measured output.
      results.each_value { assert_equal 119_094_416, _1[:data][0] }
      assert_operator results["excluded"][:data][1], :>, 0, "probe must exercise incremental GC"
      assert_operator results["excluded"][:data][2], :>, 0
      assert_operator results["total"][:instructions], :>, results["excluded"][:instructions] * 1.1
      assert_in_delta results["disabled"][:instructions], results["excluded"][:instructions],
        results["disabled"][:instructions] * 0.02
    end
  end

  def test_memory_attribution_deduplicates_containers_without_following_weak_references
    text = "x" * 512
    array = [text, text]
    array << array
    key, value = Object.new, "y" * 8192
    weak = ObjectSpace::WeakMap.new
    weak[key] = value
    root = { "data" => array, :weak => weak }
    result = RequestMemory.containers([root, array])
    assert_equal({ "Hash" => 1, "Array" => 1, "String" => 2, "ObjectSpace::WeakMap" => 1 }, result[:objects])
    assert_equal [root, root.keys.first, array, text, weak].sum { ObjectSpace.memsize_of(_1) }, result[:bytes]
    assert_same value, weak[key]
  end

  def test_operation_windows_sum_allocations_and_keep_zero_allocation_reports_finite
    skip "Valgrind not installed" unless system("sh", "-c", "command -v valgrind >/dev/null")
    saved = ENV.to_h.slice("BENCH_HEAP_SLOTS", "BENCH_JIT")
    ENV.update("BENCH_HEAP_SLOTS" => Array.new(GC.stat_heap.size, 10_000).join(","), "BENCH_JIT" => "0")
    Dir.mktmpdir("lowrail-operation-window-test") do |dir|
      script = File.join(dir, "operation.rb")
      File.write(script, <<~RUBY)
        require "json"
        require #{File.expand_path("heap_windows", __dir__).dump}
        require #{File.expand_path("jit_stability", __dir__).dump}
        require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
        ids = ENV["EMPTY_ONLY"] ? [11] : [11, 12]
        windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ids)
        # A settling callback must not charge its allocations to either window.
        settle = -> { 1000.times { Object.new } } if ENV["EMPTY_ONLY"]
        operation = ->(count, id) do
          checksum = 0
          count.times do
            checksum += 1
            Object.new if id == 12
          end
        end
        if JitStability.enabled?
          warmup = JitStability.warm { |count| ids.each { operation.call(count, _1) } }
          observe = JitStability.method(:snapshot)
        end
        anchors = HeapWindows.run(windows, settle: settle, observe: observe, &operation)
        puts "LOWRAIL_BENCH " + JSON.generate(**JitStability.state, windows: windows,
          heap_anchors: anchors, jit_warmup: warmup, operations: ids.to_h { [_1, {}] })
      RUBY
      modes = %w[0 1]
      _, _, zjit = Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "--disable-yjit", "--zjit", "-e", "exit(RubyVM::ZJIT.enabled? ? 0 : 1)")
      modes << "zjit" if zjit.success?
      modes.each do |mode|
        empty = mode != "0"
        ENV["BENCH_JIT"] = mode
        out = File.join(dir, mode)
        FileUtils.mkdir_p(out)
        environments = %w[off_a off_b on].to_h { [_1, { "RUBYOPT" => nil, "EMPTY_ONLY" => empty ? "1" : nil }] }
        capture_io do
          RequestPairs.heap_instructions(environments, dir, out, "", { rounds: 1, seed: 1, workers: {} },
            worker: script, requests: 1000)
        end
        samples = JSON.parse(File.read(File.join(out, "samples.json"))).fetch("samples").first
        samples.each_value do |sample|
          # Only unit 12 allocates: charging just the first window loses it.
          assert_in_delta(empty ? 0 : 1, sample.fetch("allocations"), 0.05)
          assert_equal(empty ? ["11"] : %w[11 12], sample.fetch("operations").keys.sort)
          assert_equal GC.stat_heap.size, sample.fetch("windows").first.fetch("pools_before").size
        end
        summary = JSON.parse(File.read(File.join(out, "summary.json")))
        if mode == "zjit"
          refute summary.fetch("jit").fetch("pass"), "preview lacks a public invalidation counter"
          assert_equal ["zjit"], summary.fetch("jit").fetch("actual_jit")
          assert summary.fetch("jit").fetch("workers").values.all? { _1.fetch("missing_counters").include?("invalidation_count") }
        else
          assert summary.fetch("jit").fetch("pass"), summary.fetch("jit").inspect
        end
        if empty
          assert_nil summary.fetch("layers").fetch("off_a").fetch("allocations").fetch("delta_pct")
          assert_nil summary.fetch("gc").fetch("off_a").fetch("gc_per_1k_allocations")
        end
      end
    end
  ensure
    %w[BENCH_HEAP_SLOTS BENCH_JIT].each { ENV[_1] = saved[_1] } if saved
  end

  def test_paired_bootstrap_removes_round_drift_but_not_a_real_effect
    rounds = 24.times.map do |i|
      value = 1000.0 + 50 * i
      { "off_a" => { "cpu_us" => value, "wall_us" => value, "allocations" => 100.0 },
        "off_b" => { "cpu_us" => value, "wall_us" => value, "allocations" => 100.0 },
        "slow" => { "cpu_us" => value * 1.125, "wall_us" => value * 1.125, "allocations" => 107.0 } }
    end
    result = RequestPairs.summarize(rounds, seed: 1, tolerance: 2)
    assert result[:aa][:pass]
    assert_equal [0.0, 0.0], result[:layers]["off_b"]["cpu_us"][:delta_pct][:ci95]
    result[:layers]["slow"]["cpu_us"][:delta_pct][:ci95].each { assert_in_delta 12.5, _1, 1e-9 }
    assert_in_delta 7.0, result[:layers]["slow"]["allocations"][:delta_pct][:median], 1e-9
    rounds.each { _1["off_b"]["wall_us"] *= 1.05 }
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 2)[:aa][:pass]
  end

  def test_wide_control_is_not_equivalence
    rounds = 24.times.map do |i|
      { "off_a" => RequestPairs::METRICS.to_h { [_1, 100.0] },
        "off_b" => RequestPairs::METRICS.to_h { [_1, i.even? ? 90.0 : 110.0] } }
    end
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 2)[:aa][:pass]
    assert_equal 2.5, RequestPairs.median([1, 2, 3, 8])
  end

  def test_instruction_control_ignores_emulation_time
    rounds = [-0.1, 0.0, 0.1].map do |noise|
      { "off_a" => { "instructions" => 1000.0, "wall_us" => 100.0 },
        "off_b" => { "instructions" => 1000.0 + noise, "wall_us" => 900.0 },
        "fast" => { "instructions" => 875.0, "wall_us" => 1100.0 } }
    end
    result = RequestPairs.summarize(rounds, seed: 1, tolerance: 0.5,
      metrics: ["instructions"], controls: ["instructions"])
    assert result[:aa][:pass]
    assert_in_delta(-12.5, result[:layers]["fast"]["instructions"][:delta_pct][:median], 1e-9)
    rounds.each { _1["off_b"]["instructions"] += 10.0 }
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 0.5,
      metrics: ["instructions"], controls: ["instructions"])[:aa][:pass]
  end

  def test_repeated_blocks_do_not_hide_process_specific_bias
    cohorts = [-3, -1, 0, 2, 4].map do |bias|
      Array.new(40) do
        { "off_a" => RequestPairs::METRICS.to_h { [_1, 100.0] },
          "off_b" => RequestPairs::METRICS.to_h { [_1, 100.0 + bias] } }
      end
    end
    result = RequestPairs.summarize(cohorts.flatten, cohorts: cohorts, seed: 1, tolerance: 2)
    refute result[:aa][:pass]
    low, high = result[:layers]["off_b"]["cpu_us"][:delta_pct][:ci95]
    assert_in_delta(-3, low, 1e-9)
    assert_in_delta 4, high, 1e-9
  end
end
