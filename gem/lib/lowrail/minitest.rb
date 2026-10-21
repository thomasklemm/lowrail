# frozen_string_literal: true

module Lowrail
  # Per-test outcomes for `lowrail verify` (LOWRAIL_OUTCOMES=path).
  #
  # Loading without touching the app's Gemfile: lowrail/setup runs from
  # RUBYOPT before Minitest exists. Minitest 6 no longer discovers plugins
  # (Minitest.load_plugins is opt-in; Rails calls `Minitest.load :rails`), and
  # Minitest 5's Gem.find_files discovery would see our -I path but is not
  # reliable across versions. So we wait for the Minitest constant
  # (Object.const_added) and prepend Minitest.init_plugins, which every
  # Minitest.run calls with the reporter set. minitest/lowrail_plugin.rb uses
  # the same attach, so discovery through load_plugins does not double up.
  #
  # Output files:
  #   * every process that ran Minitest.run writes `<path>.<pid>` with its
  #     tests and unit hits when the reporter reports;
  #   * every forked child of such a process (Rails `parallelize` workers run
  #     tests in forks and send results back over DRb, so the parent's
  #     reporter sees all tests but the hits happen in the children) writes
  #     `<path>.<pid>` with its unit hits at exit;
  #   * the reporting process then merges its own file with the files of its
  #     direct children (matched by ppid, so stale files of earlier runs are
  #     ignored) into `<path>`. Rails waits for its workers before
  #     reporter.report, so their files exist by then.
  #
  #   {"tests": {"ArticleTest#test_x": {"result": "pass|fail|error|skip",
  #              "failure": "Class: first line"}},
  #    "unit_hits": {"0": 12}, "unit_fallbacks": {...}, "pid": .., "ppid": ..,
  #    "sql": {"ArticleTest#test_x": {"digest": .., "n": .., "skipped": ..}}}
  #   (SQL traces: lowrail/sql_trace.rb)
  module Minitest
    class << self
      attr_reader :path, :reporter

      def install(path)
        return if @installed
        @installed = true
        @path = path
        if defined?(::Minitest) && ::Minitest.respond_to?(:init_plugins)
          hook_minitest
        else
          Object.singleton_class.prepend(ConstHook)
        end
        at_exit { write_child_file }
      end

      def hook_minitest
        return if @hooked
        @hooked = true
        ::Minitest.singleton_class.prepend(InitHook)
      end

      # Idempotent: adds one Reporter to the composite reporter.
      def attach(composite)
        return unless composite && @path
        return if composite.reporters.any?(Reporter)
        @reporter = Reporter.new(@path)
        composite << @reporter
      end

      # In a forked worker of a reporting process: write this process's hits.
      def write_child_file
        return unless @reporter && @reporter.pid != Process.pid
        Lowrail.write_json("#{@path}.#{Process.pid}", file_data({}))
      rescue StandardError, ScriptError => e
        warn "[lowrail] could not write outcomes: #{e.message}"
      end

      def file_data(tests)
        stats = defined?(Stats) && Stats.enabled? ? Stats.snapshot : { "unit_hits" => {}, "unit_fallbacks" => {} }
        data = { "pid" => Process.pid, "ppid" => Process.ppid, "tests" => tests, "ruby" => RUBY_DESCRIPTION,
          "unit_hits" => stats["unit_hits"], "unit_fallbacks" => stats["unit_fallbacks"],
          "jit_modes" => [Lowrail.jit_status.merge("pid" => Process.pid)],
          "sql" => SqlTrace.snapshot }
        data["jit_diagnostics"] = [JitDiagnostics.snapshot] if defined?(JitDiagnostics)
        data["verify_loads"] = VerifyLoads.snapshot if defined?(VerifyLoads)
        data
      end
    end

    # Duck-typed Minitest reporter (CompositeReporter only calls these), so
    # this file does not need Minitest loaded.
    class Reporter
      attr_reader :pid, :tests

      def initialize(path)
        @path = path
        @pid = Process.pid
        @tests = {}
        @mutex = Mutex.new
      end

      def start; end

      def prerecord(_klass, _name)
        VerifyLoads.capture("first_test") if defined?(VerifyLoads)
      end

      def passed? = true

      def synchronize(&) = @mutex.synchronize(&)

      def record(result)
        key = "#{result.respond_to?(:klass) ? result.klass : result.class.name}##{result.name}"
        entry = { "result" => Reporter.result_of(result) }
        failure = result.failures.first
        entry["failure"] = Reporter.describe(failure) if failure && entry["result"] != "pass"
        @mutex.synchronize { @tests[key] = entry }
      end

      def report
        Lowrail::Minitest.write_report(@path, @tests)
      end

      def self.result_of(result)
        if result.skipped? then "skip"
        elsif result.passed? then "pass"
        elsif result.error? then "error"
        else "fail"
        end
      end

      # "ExceptionClass: first line of message", with object addresses masked
      # so runs compare equal. For errors, the class is the original
      # exception's (also through Rails' DRb workers: DRbRemoteError#reason).
      def self.describe(failure)
        error = failure.respond_to?(:error) ? failure.error : failure
        klass = error.class.name
        msg = error.message.to_s
        if defined?(::DRb::DRbRemoteError) && error.is_a?(::DRb::DRbRemoteError)
          klass = error.reason
          msg = msg.sub(/ \(#{Regexp.escape(klass.to_s)}\)\z/, "")
        end
        line = msg.lines.first.to_s.chomp.gsub(/0x\h{4,16}/, "0x?")
        "#{klass}: #{line}"
      end
    end

    def self.write_report(path, tests)
      own = file_data(tests)
      Lowrail.write_json("#{path}.#{Process.pid}", own)
      merged = { "tests" => {}, "unit_hits" => Hash.new(0), "unit_fallbacks" => Hash.new(0), "sql" => {}, "processes" => [] }
      children = Dir.glob("#{path}.*").filter_map do |f|
        next unless f.match?(/\.\d+\z/) && f != "#{path}.#{Process.pid}"
        data = read_json(f)
        data if data && data["ppid"] == Process.pid
      end
      [own, *children].each do |data|
        merged["tests"].merge!(data["tests"] || {})
        merged["sql"].merge!(data["sql"] || {})
        data["unit_hits"]&.each { |id, n| merged["unit_hits"][id] += n }
        data["unit_fallbacks"]&.each { |id, n| merged["unit_fallbacks"][id] += n }
        merged["processes"] << data["pid"]
        (merged["ruby_descriptions"] ||= []) << data["ruby"] if data["ruby"]
        (merged["jit_modes"] ||= []).concat(data["jit_modes"]) if data["jit_modes"]
        (merged["jit_diagnostics"] ||= []).concat(data["jit_diagnostics"]) if data["jit_diagnostics"]
        if (loads = data["verify_loads"])
          target = (merged["verify_loads"] ||= { "stages" => {}, "snapshot_seconds" => 0.0 })
          target["snapshot_seconds"] += loads.fetch("snapshot_seconds")
          loads.fetch("stages").each do |stage, categories|
            snapshot = (target["stages"][stage] ||= {})
            categories.each { |category, values| snapshot[category] = ((snapshot[category] || []) | values).sort }
          end
        end
      end
      merged["unit_hits"] = merged["unit_hits"].to_h
      merged["unit_fallbacks"] = merged["unit_fallbacks"].to_h
      Lowrail.write_json(path, merged)
    rescue StandardError, ScriptError => e
      warn "[lowrail] could not write outcomes to #{path}: #{e.class}: #{e.message}"
    end

    def self.read_json(file)
      require "json"
      JSON.parse(File.read(file))
    rescue StandardError
      nil
    end

    module ConstHook
      private

      def const_added(name)
        super
        Lowrail::Minitest.hook_minitest if name == :Minitest && equal?(Object)
      end
    end

    module InitHook
      def init_plugins(options)
        super
        Lowrail::Minitest.attach(reporter)
        Lowrail::SqlTrace.hook_minitest
      end
    end
  end
end
