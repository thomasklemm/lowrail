# frozen_string_literal: true

# Census 4: broad Rails workloads across corpus apps. Dependency overlays only;
# no Lowrail preload. From the app's frozen bundle:
#   ruby SCRIPT prepare|profile|list APP [NEW_JSON]
# Workloads are ordinary app requests (GET pages, form POST/PATCH, JSON,
# Turbo Streams) plus Active Job perform and mailer delivery. State lives only
# in the disposable census copy of each app.
require "json"
require "digest"
require "objspace"
require "fileutils"

module RailsMainCensus4
  RAILS_PIN = ENV.fetch("CENSUS_RAILS_PIN", "b5be03636e0ac5c3d763411b8be9300e589a0953")
  ROOT = File.expand_path("../..", __dir__)
  UA = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"

  Op = Struct.new(:name, :kind, :call)
  # BasicObject proxies (Jbuilder) would treat #class as a missing method.
  KERNEL_CLASS = Kernel.instance_method(:class)

  # Rack::Test session that keeps cookies and checks every response.
  class Client
    attr_reader :last

    def initialize(headers = {})
      require "rack/test"
      @session = Rack::Test::Session.new(Rails.application, "localhost")
      @headers = { "HTTPS" => "on", "HTTP_USER_AGENT" => UA, "HTTP_ACCEPT" => "text/html",
        "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://localhost" }.merge(headers)
    end

    def cookie(name, value) = @session.set_cookie("#{name}=#{value}; path=/; secure", URI("https://localhost/"))

    def request(verb, path, params: {}, headers: {}, expect: [200], body: nil)
      env = @headers.merge(headers)
      env[:input] = body if body
      @session.custom_request(verb.to_s.upcase, "https://localhost#{path}", body ? {} : params, env)
      @last = @session.last_response
      unless Array(expect).include?(@last.status)
        raise "#{verb} #{path}: HTTP #{@last.status} (expected #{expect.inspect}): #{@last.body.to_s[0, 300]}"
      end
      raise "#{verb} #{path}: empty body" if @last.status == 200 && @last.body.empty? && verb == :get
      @last
    end

    %i[get post patch put delete].each do |verb|
      define_method(verb) { |path, **kw| request(verb, path, **kw) }
    end

    # The page's token, or nil for apps that verify Sec-Fetch-Site instead.
    def csrf(path, required: true)
      body = get(path).body
      body[/<meta name="csrf-token" content="([^"]+)"/, 1] || (required ? raise("no csrf-token on #{path}") : nil)
    end
  end

  module_function

  def boot(name)
    raise "disposable census copy required" unless Dir.pwd.match?(%r{\A#{Regexp.escape(ROOT)}/\.corpus/census[45]-})
    raise "no Lowrail preload" if defined?(Lowrail)
    ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
      "SECRET_KEY_BASE_DUMMY" => "1", "SKIP_TELEMETRY" => "1", "RAILS_LOG_LEVEL" => "fatal",
      "APP_VERSION" => "census", "GIT_REVISION" => RAILS_PIN)
    ENV["DATABASE_ADAPTER"] ||= "sqlite"
    require File.expand_path("config/application")
    mode = ENV.fetch("CENSUS_MODE", "interpreter")
    raise "unknown mode #{mode}" unless %w[interpreter yjit zjit].include?(mode)
    Rails.application.config.yjit = mode == "yjit"
    # Writebook enables YJIT itself; hide only that entry point outside YJIT mode.
    manual_enable = RubyVM::YJIT.method(:enable) if name == "writebook" && mode != "yjit"
    RubyVM::YJIT.singleton_class.undef_method(:enable) if manual_enable
    begin
      require File.expand_path("config/environment")
    ensure
      RubyVM::YJIT.define_singleton_method(:enable, manual_enable) if manual_enable
    end
    raise "wrong Rails revision" unless Gem.loaded_specs.fetch("railties").full_gem_path.include?(RAILS_PIN[0, 12])
    raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (mode == "yjit")
    raise "wrong ZJIT mode" unless !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?) == (mode == "zjit")
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    # External measurement controls, the same for every app: jobs are captured
    # (and performed as their own workloads), mail goes to the test deliverer,
    # and host authorization admits the mock host.
    ActiveJob::Base.queue_adapter = :test
    ActionMailer::Base.delivery_method = :test if defined?(ActionMailer)
    ActionMailer::Base.perform_deliveries = true if defined?(ActionMailer)
    # Production configs read the public host from deployment settings.
    ActionMailer::Base.default_url_options = { host: "localhost", protocol: "https" }.merge(ActionMailer::Base.default_url_options) if defined?(ActionMailer)
    Rails.application.routes.default_url_options = { host: "localhost", protocol: "https" }.merge(Rails.application.routes.default_url_options)
    Rails.application.config.hosts.clear if Rails.application.config.respond_to?(:hosts)
  end

  def captured_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
  end

  def reset_side_effects
    captured_jobs.clear
    ActionMailer::Base.deliveries.clear if defined?(ActionMailer)
  end

  # Jobs a block enqueues, serialized as a queue would store them.
  def jobs_from
    reset_side_effects
    yield
    captured_jobs.map { |job| job.transform_keys(&:to_s).except("job", "args", "at") }
  ensure
    reset_side_effects
  end

  def job_op(name, payload)
    Op.new(name, :job, -> { ActiveJob::Base.execute(payload.deep_dup) })
  end

  def mail_op(name, &build)
    Op.new(name, :mailer, -> {
      build.call.deliver_now
      raise "#{name}: nothing delivered" if ActionMailer::Base.deliveries.empty?
    })
  end

  def signed_cookie(name, value)
    require "action_dispatch/testing/test_request"
    request = ActionDispatch::TestRequest.create
    request.env.merge!(Rails.application.env_config)
    request.cookie_jar.signed[name] = value
    request.cookie_jar.to_header.split("=", 2)
  end

  def prepare(name)
    marker = "tmp/census4-fixtures.json"
    raise "fixtures already prepared" if File.exist?(marker)
    require "active_record/fixtures"
    case name
    when "blog"
      load "db/seeds.rb"
    when "fizzy", "fizzy-mysql"
      helper = File.read("test/test_helper.rb").split("module FixturesTestHelper\n", 2).fetch(1)
      eval("module FixturesTestHelper\n" + helper, TOPLEVEL_BINDING, "test/test_helper.rb")
      load_fixtures
    when "campfire", "writebook", "codetriage"
      load_fixtures
    else
      raise "#{name} is prepared by its own seed step"
    end
    FileUtils.mkdir_p("tmp")
    File.write(marker, JSON.generate(name: name, rails: RAILS_PIN, lock: Digest::SHA256.file("Gemfile.lock").hexdigest))
  end

  def load_fixtures
    path = File.expand_path("test/fixtures")
    names = Dir["#{path}/**/*.yml"].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
    ActiveRecord::FixtureSet.create_fixtures(path, names)
  end

  def flip(counter, a, b) = (counter[0] += 1).odd? ? a : b

  def workloads(name)
    load File.join(__dir__, "census_4_workloads.rb")
    Census4Workloads.public_send(name.tr("-", "_"), self)
  end

  def site_key(file)
    if file.nil?
      "<no Ruby source>"
    elsif file.start_with?(Rails.root.to_s + "/")
      file.sub(Rails.root.to_s + "/", "APP/")
    elsif file.include?("/rails-#{RAILS_PIN[0, 12]}/")
      "RAILS/" + file.split("/rails-#{RAILS_PIN[0, 12]}/", 2).last
    elsif file.include?("/gems/")
      "GEM/" + file.split("/gems/", 2).last
    elsif file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/")
      file.sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/")
    else
      file.sub(ROOT + "/", "LOWRAIL/")
    end
  end

  def measure(op)
    run = -> { op.call.call; reset_side_effects }
    warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
    warmup.times { run.call }
    gc_keys = %i[count minor_gc_count major_gc_count time]
    gc_windows = []
    totals = 3.times.map do
      GC.start
      before = GC.stat(:total_allocated_objects)
      stat = GC.stat.slice(*gc_keys)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      20.times { run.call }
      wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      gc_windows << gc_keys.to_h { [_1, GC.stat(_1) - stat[_1]] }.merge(wall_ms_per_op: (wall * 1000 / 20).round(3))
      (GC.stat(:total_allocated_objects) - before) / 20.0
    end
    GC.start
    heap = GC.stat.slice(:heap_allocated_pages, :heap_live_slots, :old_objects, :malloc_increase_bytes,
      :oldmalloc_increase_bytes).merge(rss_kb: File.read("/proc/self/statm").split[1].to_i * 4)
    callgrind = callgrind_window(run) if defined?(LowrailCallgrindBench)
    gc_long = gc_window(run, Integer(ENV["CENSUS_GC_OPS"]), op.name) if ENV["CENSUS_GC_OPS"]
    count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
    GC.start
    ObjectSpace.trace_object_allocations_clear
    raise "GC already disabled" if GC.disable
    generation = GC.count
    before = GC.stat(:total_allocated_objects)
    ObjectSpace.trace_object_allocations_start
    count.times { run.call }
    ObjectSpace.trace_object_allocations_stop
    allocated = GC.stat(:total_allocated_objects) - before
    rows = Hash.new(0)
    bytes = Hash.new(0)
    ObjectSpace.each_object do |object|
      next unless ObjectSpace.allocation_generation(object) == generation
      key = [site_key(ObjectSpace.allocation_sourcefile(object)), ObjectSpace.allocation_sourceline(object),
        KERNEL_CLASS.bind_call(object)&.name || "<classless>"]
      rows[key] += 1
      # Slot plus out-of-slot (malloc) storage, as the object ended the window.
      bytes[key] += ObjectSpace.memsize_of(object)
    end
    GC.enable
    ObjectSpace.trace_object_allocations_clear
    { workload: op.name, kind: op.kind, ops: count, warmup: warmup, gc_enabled_objects_per_op: totals,
      gc_windows: gc_windows, heap_after_windows: heap, callgrind: callgrind, gc_long: gc_long,
      traced_gc_objects: allocated, enumerated: rows.values.sum, enumerated_bytes: bytes.values.sum,
      sites: rows.sort_by { |key, n| [-n, key.to_s] }.map { |(file, line, klass), n|
        { file: file, line: line, class: klass, objects_per_op: n.fdiv(count),
          bytes_per_op: bytes[[file, line, klass]].fdiv(count) } } }
  ensure
    ObjectSpace.trace_object_allocations_stop
    GC.enable
  end

  # Compile and invalidation counters for the JIT-flat gate (docs/bench.md); ZJIT has no invalidation count, and
  # every invalidation runs inside its invalidation_time_ns timer.
  def jit_counters
    if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
      RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
    elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
      RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
    end
  end

  # Under valgrind --tool=callgrind --instr-atstart=no with CENSUS_CALLGRIND_EXT
  # (bench/callgrind.c): one dump per window, numbered in order. The empty
  # window measures the start/finish seam; no_gc toggles collection off
  # inside each collector segment.
  def callgrind_window(run)
    ops = Integer(ENV.fetch("CENSUS_CALLGRIND_OPS", "10"))
    [["seam", 0, false], ["total", ops, false], ["no_gc", ops, true]].map do |kind, n, exclude|
      GC.start
      gcs = GC.count
      jit_before = jit_counters
      LowrailCallgrindBench.start(exclude)
      n.times { run.call }
      segments = LowrailCallgrindBench.finish
      { kind: kind, ops: n, gc_count: GC.count - gcs, gc_segments: segments, dump: (@dumps = (@dumps || 0) + 1),
        jit_flat: jit_before == jit_counters, jit_counters: jit_before }
    end
  end

  # One long GC-enabled window: collector runs, heap growth and retained
  # out-of-slot memory per operation, which the 20-operation windows rarely see.
  # GCSTEP_LOG needs a Ruby built with fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch.
  def gc_window(run, ops, workload = nil)
    GC.start
    step_log = ENV["GCSTEP_LOG"] if GC.respond_to?(:__step_log)
    GC.__step_log(true) if step_log
    keys = %i[count minor_gc_count major_gc_count time total_allocated_objects heap_allocated_pages heap_live_slots
      oldmalloc_increase_bytes]
    before = GC.stat.slice(*keys)
    rss = File.read("/proc/self/statm").split[1].to_i * 4
    major_by = Hash.new(0)
    forced = -> { GC.stat_heap.to_h { |_, h| [h[:slot_size], h[:force_major_gc_count]] } } if ENV["CENSUS_GC_MAJOR_BY"]
    forced_before = forced&.call
    if ENV["CENSUS_GC_MAJOR_BY"] # why each major ran (at most one major per operation is seen)
      ops.times do
        majors = GC.stat(:major_gc_count)
        run.call
        major_by[GC.latest_gc_info(:major_by)] += 1 if GC.stat(:major_gc_count) != majors
      end
    else
      ops.times { run.call }
    end
    after = GC.stat.slice(*keys)
    if step_log
      GC.__step_log(false)
      log = "#{step_log}.#{Process.pid}"
      File.rename(log, "#{step_log}-#{workload.to_s.gsub(/[^\w.-]/, "_")}.bin") if File.exist?(log)
    end
    keys.to_h { [_1, after[_1] - before[_1]] }.merge(ops: ops, latest_gc_by: GC.latest_gc_info(:gc_by),
      major_by: major_by, forced_major_by_slot: forced&.call&.to_h { |s, n| [s, n - forced_before.fetch(s, 0)] },
      heaps: (GC.stat_heap.to_h { |_, h| [h[:slot_size], h.slice(:heap_eden_pages, :heap_free_slots, :heap_live_slots)] } if forced),
      rss_kb_growth: File.read("/proc/self/statm").split[1].to_i * 4 - rss)
  end

  def profile(name, output)
    raise "fresh output required" if File.exist?(output)
    require ENV["CENSUS_CALLGRIND_EXT"] if ENV["CENSUS_CALLGRIND_EXT"]
    ops = workloads(name)
    only = ENV["CENSUS_ONLY"]&.split(",")
    ops = ops.select { only.include?(_1.name) } if only
    results = ops.map { |op| measure(op) }
    result = { app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?,
      zjit: !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?), rails: RAILS_PIN,
      adapter: ActiveRecord::Base.connection_db_config.adapter,
      lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest, workloads: results }
    File.write(output, JSON.pretty_generate(result) + "\n")
    puts JSON.generate(result.except(:workloads).merge(workloads: results.map { _1.except(:sites) }))
  end

  # JIT counters for steady-state workloads (run with --yjit-stats or
  # --zjit-stats): warm every workload, reset, then run each 20 times.
  def stats(name, output)
    raise "fresh output required" if File.exist?(output)
    jit = RubyVM::YJIT.enabled? ? RubyVM::YJIT : RubyVM::ZJIT
    raise "run with --yjit-stats or --zjit-stats" unless jit.stats_enabled?
    ops = workloads(name)
    ops.each { |op| Integer(ENV.fetch("CENSUS_WARMUP", "50")).times { op.call.call; reset_side_effects } }
    jit.reset_stats!
    ops.each { |op| 20.times { op.call.call; reset_side_effects } }
    stats = jit == RubyVM::YJIT ? jit.runtime_stats : jit.stats
    File.write(output, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, jit: jit.name, ops: ops.size * 20,
      stats: stats.select { |_, v| v.is_a?(Numeric) && v != 0 }) + "\n")
  end

  def list(name)
    workloads(name).each do |op|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      3.times { op.call.call; reset_side_effects }
      puts format("%-8s %-40s ok (%.0f ms for 3)", op.kind, op.name, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsMainCensus4.boot(name)
  case command
  when "prepare" then RailsMainCensus4.prepare(name)
  when "profile" then RailsMainCensus4.profile(name, output)
  when "list" then RailsMainCensus4.list(name)
  when "stats" then RailsMainCensus4.stats(name, output)
  else abort "usage: rails_main_census_4.rb prepare|profile|stats|list APP [NEW_JSON]"
  end
end
