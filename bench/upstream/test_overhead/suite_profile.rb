# frozen_string_literal: true

# Loaded with -r (RUBYOPT) into every Ruby process of an app's own suite run (docs/upstream/test-overhead-2.md).
# In the process that runs the tests it brackets the run (Minitest.run_all_suites, RSpec's Runner#run_specs),
# counts tests, wall/CPU time and allocated objects in that window. With PT2_COUNTERS=1 or a stackprof mode it also
# wraps a few framework entry points with exact counters and marks Minitest's hooks; with PT2_STACKPROF=wall|cpu|object, samples the window with stackprof (raw stacks) for
# bench/upstream/test_overhead/classify.rb. Output: PT2_OUT.PID.json (and .stackprof). Everything else is untouched.
out = ENV["PT2_OUT"] or return

module PT2
  OUT = ENV.fetch("PT2_OUT")
  T0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  @tests = 0
  @counters = Hash.new { |h, k| h[k] = { "calls" => 0, "wall" => 0.0, "allocs" => 0, "nested" => Hash.new(0.0) } }
  @stack = []

  class << self
    attr_accessor :tests, :window, :parallel
    attr_reader :counters

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    def cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    def allocs = GC.stat(:total_allocated_objects)

    # Inclusive wall time and allocations of the outermost call per label; time spent in other labels'
    # calls inside it is recorded under "nested", so the summary can subtract the app's request handling
    # from the integration session that drove it.
    def measure(label)
      return yield if @stack.include?(label)
      @stack.push(label)
      t, a = now, allocs
      begin
        yield
      ensure
        dt = now - t
        c = @counters[label]
        c["calls"] += 1
        c["wall"] += dt
        c["allocs"] += allocs - a
        @stack.pop
        @stack.each { |outer| @counters[outer]["nested"][label] += dt }
      end
    end

    def wrap(owner, meth, label, singleton: false)
      target = singleton ? owner.singleton_class : owner
      return unless target.method_defined?(meth) || target.private_method_defined?(meth)
      private = target.private_method_defined?(meth)
      mod = Module.new do
        define_method(meth) { |*args, **kw, &blk| PT2.measure(label) { super(*args, **kw, &blk) } }
        private meth if private
      end
      target.prepend(mod)
    end

    def instrument
      if defined?(ActiveRecord::TestFixtures)
        wrap(ActiveRecord::TestFixtures, :setup_fixtures, "fixtures.setup")
        wrap(ActiveRecord::TestFixtures, :teardown_fixtures, "fixtures.teardown")
        wrap(ActiveRecord::TestFixtures, :access_fixture, "fixtures.access")
        wrap(ActiveRecord::FixtureSet, :create_fixtures, "fixtures.load", singleton: true)
        wrap(ActiveRecord::TestFixtures, :setup_transactional_fixtures, "fixtures.tx_setup")
        wrap(ActiveRecord::TestFixtures, :teardown_transactional_fixtures, "fixtures.tx_teardown")
      end
      wrap(Rack::Test::Session, :request, "rack_test.request") if defined?(Rack::Test::Session)
      wrap(ActionDispatch::Integration::Session, :process, "integration.process") if defined?(ActionDispatch::Integration::Session)
      wrap(ActionController::TestCase::Behavior, :process, "controller_test.process") if defined?(ActionController::TestCase::Behavior)
      wrap(Rails::Engine, :call, "app.call") if defined?(Rails::Engine)
      wrap(FactoryBot::FactoryRunner, :run, "factory_bot.run") if defined?(FactoryBot::FactoryRunner)
      wrap(Fabrication::Generator::Base, :build, "fabrication.build") if defined?(Fabrication::Generator::Base)
      wrap(Fabrication::Generator::Base, :create, "fabrication.create") if defined?(Fabrication::Generator::Base)
    end

    # Parallel workers (Rails' parallelize with processes) write PT2_OUT.PID.worker.json at exit: database
    # setup after the fork, the queue loop, and the DRb round trips that return each result.
    def instrument_workers
      return unless defined?(ActiveSupport::Testing::Parallelization::Worker)
      ActiveSupport::Testing::Parallelization::Worker.prepend(Module.new do
        def after_fork
          PT2.worker_started
          PT2.measure("parallel.after_fork") { super }
        end

        def work_from_queue = PT2.measure("parallel.work_from_queue") { super }
        def perform_job(job) = PT2.measure("parallel.perform_job") { super }
        def safe_record(...) = PT2.measure("parallel.record") { super }
      end)
    end

    def worker_started
      @tests = 0
      @counters.clear
      @stack.clear
      w0 = now
      at_exit do
        require "json"
        File.write("#{OUT}.#{Process.pid}.worker.json", JSON.pretty_generate(
          "tests" => @tests, "wall" => now - w0, "counters" => @counters.sort.to_h) + "\n")
      end
    end

    def detailed? = !ENV["PT2_STACKPROF"].to_s.empty? || ENV["PT2_COUNTERS"] == "1"

    # PT2_LOG_LEVEL=info: the suite as if config.log_level were :info, which also turns off Rails.event's
    # debug mode the way boot does (railties' bootstrap), so debug-only structured events are silenced.
    def log_level(level)
      loggers = [(Rails.logger if defined?(Rails) && Rails.respond_to?(:logger)),
        (ActiveRecord::Base.logger if defined?(ActiveRecord::Base))].compact.uniq
      loggers.each { _1.level = level.to_sym }
      ActiveSupport.event_reporter.debug_mode = level.to_s == "debug" if ActiveSupport.respond_to?(:event_reporter)
    end

    def start
      log_level(ENV["PT2_LOG_LEVEL"]) unless ENV["PT2_LOG_LEVEL"].to_s.empty?
      instrument if detailed?
      mode = ENV["PT2_STACKPROF"]
      if mode && !mode.empty?
        $LOAD_PATH.unshift(ENV.fetch("PT2_STACKPROF_LIB"))
        require "stackprof"
        interval = Integer(ENV.fetch("PT2_INTERVAL", mode == "object" ? "20" : "1000"))
        StackProf.start(mode: mode.to_sym, interval: interval, raw: true)
        @stackprof = mode
      end
      @w0, @c0, @a0, @gc0 = now, cpu, allocs, GC.stat(:count)
    end

    def finish
      require "json" # after Bundler, so the app's locked json loads
      w, c, a, gc = now - @w0, cpu - @c0, allocs - @a0, GC.stat(:count) - @gc0
      if @stackprof
        StackProf.stop
        File.binwrite("#{OUT}.#{Process.pid}.stackprof", Marshal.dump(StackProf.results))
      end
      jit = { "yjit" => !!(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?),
        "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?) }
      File.write("#{OUT}.#{Process.pid}.json", JSON.pretty_generate(
        "ruby" => RUBY_DESCRIPTION, **jit, "pwd" => Dir.pwd, "tests" => @tests, "stackprof" => @stackprof,
        "boot_wall" => @w0 - T0, "window" => { "wall" => w, "cpu" => c, "allocs" => a, "gc_count" => gc },
        "counters" => @counters.sort.to_h) + "\n")
    end
  end
end

case ENV["PT2_KIND"]
when "minitest"
  require "bundler/setup"
  require "minitest"
  # With Rails' parallelize, run_all_suites only queues the tests; the workers run them until the executor's
  # shutdown, so the window spans the executor's start to its shutdown instead.
  module PT2Parallel
    def start
      require "active_support/testing/parallelization"
      PT2.instrument_workers if PT2.detailed?
      PT2.parallel = true
      PT2.start
      super
    end

    def shutdown
      super
    ensure
      PT2.finish
    end
  end
  Minitest.singleton_class.prepend(Module.new do
    # After process_args, which loads the test files (and their parallelize call), before the executor starts.
    def init_plugins(*)
      ActiveSupport::Testing::ParallelizeExecutor.prepend(PT2Parallel) if defined?(ActiveSupport::Testing::ParallelizeExecutor)
      super
    end

    def run_all_suites(*)
      PT2.start unless PT2.parallel
      super
    ensure
      PT2.finish unless PT2.parallel
    end
  end)
  Minitest::Test.prepend(Module.new { def run = super.tap { PT2.tests += 1 } })
  # Named frames around Minitest's lifecycle hooks, prepended to every test class so they sit above the
  # modules the class includes (fixtures, Active Support callbacks): classify.rb reads setup and teardown
  # from them.
  module PT2Hooks
    %i[before_setup setup after_setup before_teardown teardown after_teardown].each do |hook|
      define_method(hook) { super() }
    end
  end
  if PT2.detailed?
    Minitest::Test.singleton_class.prepend(Module.new do
      def inherited(klass)
        super
        klass.prepend(PT2Hooks)
      end
    end)
  end
when "rspec"
  require "bundler/setup"
  require "rspec/core"
  RSpec::Core::Runner.prepend(Module.new do
    def run_specs(*)
      PT2.start
      super
    ensure
      PT2.finish
    end
  end)
  RSpec::Core::Example.prepend(Module.new { def run(*) = super.tap { PT2.tests += 1 } })
end
