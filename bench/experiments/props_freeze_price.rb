# frozen_string_literal: true

# Reproducible orchestration only; props_freeze.rb's specimen stays unchanged.
require_relative "../request_pairs"
require_relative "props_freeze"

module PropsFreezePrice
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.expand_path(__FILE__)
  ARMS = %w[original native_split frozen_split native_checks_original frozen_checks_original each].freeze
  LABELS = (%w[off_a off_b] + ARMS.drop(1)).freeze
  ROUTE = "unused"

  class WorkerLimit
    def initialize
      @mutex = Mutex.new
      @active = @peak = @started = @refused = 0
    end

    def around
      @mutex.synchronize do
        if @active >= 2
          @refused += 1
          raise "two-worker process cap exceeded before spawn"
        end
        @active += 1
        @started += 1
        @peak = [@peak, @active].max
      end
      begin
        yield
      ensure
        @mutex.synchronize { @active -= 1 }
      end
    end

    def report
      @mutex.synchronize { {active: @active, peak: @peak, started: @started, refused: @refused} }
    end
  end

  module SupervisedLaunch
    def system(*args, **options)
      return super unless args.include?("--tool=callgrind") || args.include?(SCRIPT)
      ::PropsFreezePrice.limit.around { super }
    end
  end

  class << self
    attr_reader :limit

    def block_children!
      # Install identically in every disposable worker BEFORE freezing Kernel.
      # Open3 delegates to spawn; cover direct fork/exec/popen/backticks too.
      {Kernel => %i[system spawn fork exec `],
        Kernel.singleton_class => %i[system spawn fork exec `],
        Process.singleton_class => %i[spawn fork _fork exec daemon],
        IO.singleton_class => %i[popen]}.each do |holder, names|
        patch = Module.new
        names.each { |name| patch.define_method(name) { |*| raise "props worker cannot create or replace processes" } }
        patch.send(:private, *names) if holder == Kernel
        holder.prepend(patch)
      end
    end

    def worker(role, argv)
      raise "worker cannot enter controller: expected route #{ROUTE}" unless argv == [ROUTE]
      raise "unknown worker role" unless %w[worker liveness].include?(role)
      raise "worker parent is not the controller" unless Process.ppid == Integer(ENV.fetch("PROPS_FREEZE_CONTROLLER"))
      arm = ENV.fetch("PROPS_FREEZE_ARM")
      raise "unknown arm" unless ARMS.include?(arm)
      proof = JSON.parse(File.read(ENV.fetch("PROPS_FREEZE_PROOF")))
      raise "stale worker inputs" unless proof.fetch("sources").all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
      if role == "worker"
        claim = proof.fetch("arms").fetch(arm)
        raise "missing positive authorization" unless claim.fetch("pass") && claim.fetch("guard_valid") &&
          claim.fetch("actual_jit") == "interpreter" && claim.fetch("fallbacks").empty? &&
          claim.fetch("hits") == (%w[original each].include?(arm) ? {} : {"0" => 20})
      end
      require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
      block_children!
      if role == "liveness"
        result = PropsFreeze.liveness(arm)
        raise "untimed authorization refused" unless result.fetch(:pass)
        return result.merge(pid: Process.pid, ppid: Process.ppid)
      end
      runner, metadata = PropsFreeze.setup(arm, counted: false)
      raise "Stats enabled in measured worker" if Lowrail::Stats.enabled?
      raise "observer enabled in measured worker" if ObjectSpace.each_object(TracePoint).any?(&:enabled?)
      raise "manifest/mode mismatch" unless metadata.fetch(:guard_valid) &&
        Lowrail::Guard.manifest.format == Lowrail::FORMAT &&
        Lowrail::Guard.manifest.certification_jit == "interpreter"
      runner.run(2000)
      windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
      anchors = HeapWindows.run(windows) { |n, _| runner.run(n) }
      metadata.merge(**JitStability.state, ruby: RUBY_DESCRIPTION, windows: windows,
        jit_warmup: nil, heap_anchors: anchors, ar_installed: 0,
        pid: Process.pid, ppid: Process.ppid, role: role,
        measured: ENV.fetch("PROPS_FREEZE_KIND") == "cohort")
    end

    def controller(kind, out)
      raise "controller cannot be entered from a worker" if ENV["PROPS_FREEZE_CONTROLLER"] || ENV["PROPS_FREEZE_ARM"] || ENV["BENCH_CALLGRIND_EXTENSION"]
      raise "BENCH_JOBS must be 2" unless Integer(ENV.fetch("BENCH_JOBS", "2")) == 2
      out = File.expand_path(out)
      raise "new output required" if File.exist?(out)
      head, status = Open3.capture2("/usr/bin/git", "rev-parse", "HEAD", chdir: ROOT)
      raise "cannot identify source" unless status.success?
      if kind == "cohort"
        raise "published source pin required" unless head.strip == ENV.fetch("PROPS_FREEZE_PIN")
        raise "dirty tracked source" unless system("/usr/bin/git", "diff", "--quiet", "HEAD", chdir: ROOT)
        raise "N must be 1000" unless Integer(ENV.fetch("BENCH_REQUESTS", "1000")) == 1000
      end
      FileUtils.mkdir_p(out, mode: 0o700)
      # Compile once for admission. The unchanged shared driver also compiles
      # its own identical client before pricing; its binary stays source-pinned.
      extension = RequestPairs.compile_counter_extension(out)
      sources = [SCRIPT, *PropsFreeze.source_proof.keys, *Dir[File.join(ROOT, "gem/lib/**/*.rb")],
        *%w[request_pairs heap_windows jit_stability].map { File.join(ROOT, "bench/#{_1}.rb") },
        File.join(ROOT, "bench/callgrind.c"), extension].uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
      proof_path = File.join(out, "liveness.json")
      File.write(proof_path, JSON.pretty_generate(sources: sources))
      base = %w[RUBYOPT RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_UNITS
        LOWRAIL_JIT_DIAGNOSTICS LOWRAIL_ROOT LOWRAIL_DIR LOWRAIL_SEALED BUNDLE_GEMFILE
        BENCH_YJIT_LOG BENCH_JIT_CALL_THRESHOLD].to_h { [_1, nil] }.merge(
          "LOWRAIL_FREEZE" => "1", "BENCH_CALLGRIND_EXTENSION" => extension,
          "PROPS_FREEZE_CONTROLLER" => Process.pid.to_s, "PROPS_FREEZE_PROOF" => proof_path,
          "PROPS_FREEZE_KIND" => kind, "BENCH_JOBS" => "2", "BENCH_REQUESTS" => kind == "check" ? "3" : "1000")
      liveness = ARMS.to_h do |arm|
        stdout, stderr, child = Open3.capture3(base.merge("PROPS_FREEZE_ROLE" => "liveness", "PROPS_FREEZE_ARM" => arm),
          RbConfig.ruby, *JitStability.flags, SCRIPT, ROUTE, chdir: ROOT)
        File.write(File.join(out, "liveness-#{arm}.stdout"), stdout)
        File.write(File.join(out, "liveness-#{arm}.log"), stderr)
        raise "#{arm}: untimed authorization refused before any window" unless child.success?
        claim = JSON.parse(stdout.lines.last)
        raise "invalid admission companion" unless claim.fetch("pass") && claim.fetch("ppid") == Process.pid
        [arm, claim]
      end
      raise "inputs changed during admission" unless sources.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
      File.write(proof_path, JSON.pretty_generate(arms: liveness, sources: sources))
      @limit = WorkerLimit.new
      RequestPairs.singleton_class.prepend(SupervisedLaunch)
      environments = LABELS.to_h do |label|
        [label, base.merge("PROPS_FREEZE_ROLE" => "worker",
          "PROPS_FREEZE_ARM" => label.start_with?("off_") ? "original" : label)]
      end
      metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources, measured_commit: head.strip,
        ruby_executable_sha256: Digest::SHA256.file(RbConfig.ruby).hexdigest,
        group: "props_frozen_selected_stats", diagnosis_only: true, liveness: liveness,
        maximum_concurrent_workers: 2, kind: kind}
      if kind == "cohort"
        accepted = RequestPairs.heap_instructions(environments, ROOT, out, ROUTE, metadata,
          worker: SCRIPT, requests: 1000)
      else
        workers = {}
        floors = HeapWindows.floors.each_with_index.to_h { |n, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", n.to_s] }
        queue = Queue.new
        LABELS.each { queue << _1 }
        mutex = Mutex.new
        Array.new(2) do
          Thread.new do
            loop do
              label = queue.pop(true)
              log = File.join(out, "#{label}.log")
              ok = RequestPairs.send(:system, environments.fetch(label).merge(floors), RbConfig.ruby,
                *JitStability.flags, SCRIPT, ROUTE, chdir: ROOT, out: log, err: [:child, :out])
              raise "native exact-route worker failed: #{label}; inspect #{log}" unless ok
              result = JSON.parse(File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
              positive = result.fetch("windows").select { _1.fetch("requests").positive? }
              raise "missing native operation windows" unless result.fetch("windows").size == 4 && positive.size == 2 &&
                positive.all? { _1.fetch("requests") == 3 && _1.fetch("after").fetch("total_allocated_objects") > _1.fetch("before").fetch("total_allocated_objects") } &&
                result.fetch("ppid") == Process.pid
              mutex.synchronize { workers[label] = result }
            rescue ThreadError
              break
            end
          rescue StandardError => error
            error
          end
        end.map(&:value).each { raise _1 if _1.is_a?(Exception) }
        metadata[:workers] = workers
        accepted = workers.size == LABELS.size && workers.values.map { _1.fetch("pid") }.uniq.size == LABELS.size
        File.write(File.join(out, "native-check.json"), JSON.pretty_generate(metadata.merge(accepted: accepted, measured: false)))
      end
      report = @limit.report
      raise "process limit violation" unless report.fetch(:active).zero? && report.fetch(:peak) <= 2 && report.fetch(:refused).zero?
      raise "sources changed" unless sources.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
      File.write(File.join(out, "verdict.json"), JSON.pretty_generate(accepted: accepted, kind: kind, process_limit: report))
      puts JSON.generate(accepted: accepted, kind: kind, process_limit: report)
      accepted
    ensure
      File.write(File.join(out, "process-limit.json"), JSON.pretty_generate(@limit.report)) if @limit && out && File.directory?(out)
    end

    def main(argv)
      JitStability.assert_mode!
      raise "interpreter only" unless JitStability.mode == "interpreter"
      if (role = ENV["PROPS_FREEZE_ROLE"])
        result = worker(role, argv)
        puts(role == "liveness" ? JSON.generate(result) : "LOWRAIL_BENCH #{JSON.generate(result)}")
        true
      else
        raise "usage: props_freeze_price.rb --check|--cohort NEW_OUTDIR" unless %w[--check --cohort].include?(argv.first) && argv.size == 2
        controller(argv.first.delete_prefix("--"), argv.last)
      end
    end
  end
end

exit(PropsFreezePrice.main(ARGV) ? 0 : 2) if $PROGRAM_NAME == __FILE__
