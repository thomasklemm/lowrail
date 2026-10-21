# frozen_string_literal: true

# Fork-only native timing experiment, NOT an accepted Lowrail Ir cohort.
# Usage: ruby method_token_experiment.rb study NEW_DIRECTORY
# Workers are fresh processes; no production pass flags or defaults change.
require "json"
require "open3"
require "fileutils"
require "digest/sha2"
require_relative "../request_pairs"
require_relative "../jit_stability"
$LOAD_PATH.unshift(File.expand_path("../../gem/lib", __dir__))
require "lowrail"
require "lowrail/manifest"
require "lowrail/guard"
require "lowrail/memo"
require "lowrail/memo_facts"
require "lowrail/stats"

module MethodTokenExperiment
  IM = Module.instance_method(:instance_method)
  EQ = UnboundMethod.instance_method(:==)
  PUBLIC = Module.instance_method(:public_method_defined?)
  PROTECTED = Module.instance_method(:protected_method_defined?)

  # Equality certifies the definition, not wrapper object identity or visibility.
  # Capture core reflection, rather than trusting an overridden instance_method.
  def self.public_snapshot(holder, name)
    [holder, name, IM.bind_call(holder, name), PUBLIC.bind_call(holder, name), PROTECTED.bind_call(holder, name)]
  end

  def self.public_valid?(snapshots)
    snapshots.all? do |holder, name, saved, public, protected|
      EQ.bind_call(saved, IM.bind_call(holder, name)) &&
        PUBLIC.bind_call(holder, name) == public && PROTECTED.bind_call(holder, name) == protected
    end
  rescue NameError
    false
  end

  # Only this existing memo/sha256 unit switches guard implementation. It
  # retains tracing, constants, input, fresh-result and source certificates.
  # Token/public modes ignore Guard.state and do not rely on hook revocation.
  module MemoGuard
    def prepared(id)
      return super if MethodTokenExperiment.arm == "hooks"
      return false unless Ractor.main? && @units[id] && !@tracing
      return false unless Lowrail::Memo::TRACE_STAT.call.each_value.all? { _1.first == 0 }
      unless defined?(@experiment_guard)
        pairs = @units.fetch(id).fetch("facts").map do |fact|
          mod = Lowrail.loaded_constant(fact.fetch("receiver"))
          [fact["singleton"] ? mod.singleton_class : mod, fact.fetch("method").to_sym]
        end
        # Subscribe BEFORE validating. Check again after all certification
        # calls, so mutation during admission cannot bless the new definition.
        @experiment_guard = if MethodTokenExperiment.arm == "tokens"
          tokens = pairs.map { |holder, name| Lowrail::Native.method_token(holder, name) }.freeze
          -> { Lowrail::Native.method_tokens_valid?(tokens) }
        else
          snapshots = pairs.map { |holder, name| MethodTokenExperiment.public_snapshot(holder, name) }
          -> { MethodTokenExperiment.public_valid?(snapshots) }
        end
        @experiment_memo = Lowrail::Guard.validate(id) && prepare(@units.fetch(id))
        @experiment_memo = false unless @experiment_guard.call
      end
      @experiment_guard.call && @experiment_memo
    end
  end

  class << self
    attr_accessor :arm

    def install
      ENV["RAILS_ENV"] = "production"
      ENV["LOWRAIL_SEALED"] = "1"
      cert = Lowrail::MemoFacts.digest
      raise cert.fetch("decline") if cert["decline"]
      unit = {"id" => 0, "kind" => "file", "file" => __FILE__, "pass" => "memo/sha256",
        "facts" => cert.fetch("facts"), "memo" => cert}
      manifest = Lowrail::Manifest.new({"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "compile_option" => "", "files" => {}, "units" => [unit], "tier" => "sealed-v1", "rails_env" => "production"}, Dir.pwd)
      Lowrail::Guard.install(manifest)
      Lowrail::Memo.install(manifest.units)
      Lowrail::Memo.singleton_class.prepend(MemoGuard)
      raise "refused unit" unless Lowrail::Memo.prepared(0)
      cert.fetch("facts").size
    end

    def digest(input)
      Lowrail::Memo.digest(0, Digest::SHA256, input) { |r, s| r.base64digest(s) }
    end

    def stamp
      {ruby: RUBY_DESCRIPTION, revision: RUBY_REVISION, lowrail: `git rev-parse HEAD`.strip,
        source_sha256: Digest::SHA256.file(__FILE__).hexdigest, yjit: RubyVM::YJIT.enabled?,
        native_sha256: Digest::SHA256.file(Lowrail::NATIVE_PATH + ".so").hexdigest}
    end

    def observe(n)
      before = RubyVM::YJIT.runtime_stats&.slice(*JitStability::COUNTERS)
      allocations = GC.stat(:total_allocated_objects)
      collections = GC.stat(:count)
      cpu_start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield n
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      cpu_elapsed = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_start
      allocated = GC.stat(:total_allocated_objects) - allocations
      collected = GC.stat(:count) - collections
      after = RubyVM::YJIT.runtime_stats&.slice(*JitStability::COUNTERS)
      {seconds: elapsed, cpu_seconds: cpu_elapsed, allocated: allocated, collections: collected, jit_before: before, jit_after: after,
        jit_flat: !RubyVM::YJIT.enabled? || (before.values.all? { Integer === _1 } && before == after)}
    end
  end
end

if ENV["METHOD_TOKEN_WORKER"]
  kind, arm = ENV.fetch("METHOD_TOKEN_WORKER").split(":")
  MethodTokenExperiment.arm = arm
  case kind
  when "probe"
    dependencies = MethodTokenExperiment.install
    Lowrail::Stats.enable!
    3.times { MethodTokenExperiment.digest("asymmetric-left") }
    hits_before = Lowrail::Stats.unit_hits.fetch("0", 0)
    Digest::SHA256.define_singleton_method(:singleton_method_added) { |_| }
    Digest::SHA256.define_singleton_method(:base64digest) { |_| "changed-under-suppressed-hook" }
    expected = Digest::SHA256.base64digest("asymmetric-left")
    actual = MethodTokenExperiment.digest("asymmetric-left")
    hits_after = Lowrail::Stats.unit_hits.fetch("0", 0)
    puts JSON.generate(MethodTokenExperiment.stamp.merge(arm: arm, dependencies: dependencies,
      hits_before: hits_before, hits_after: hits_after, expected: expected, actual: actual,
      detected: actual == expected, hook_state_still_true: Lowrail::Guard.state[0]))
    exit
  when "micro"
    klass = Class.new { def target = :value }
    receiver = klass.new
    saved = receiver.method(:target)
    unbound = klass.instance_method(:target)
    owner = unbound.owner
    tokens = [Lowrail::Native.method_token(klass, :target)].freeze
    snapshots = [MethodTokenExperiment.public_snapshot(klass, :target)]
    hash = {}
    operation = case arm
    when "off_a", "off_b" then ->(n) { n.times { true } }
    when "tokens" then ->(n) { n.times { Lowrail::Native.method_tokens_valid?(tokens) } }
    when "method" then ->(n) { n.times { receiver.method(:target) == saved } }
    when "unbound" then ->(n) { n.times { klass.instance_method(:target) == unbound } }
    when "owner_only" then ->(n) { n.times { klass.instance_method(:target).owner.equal?(owner) } }
    when "public" then ->(n) { n.times { MethodTokenExperiment.public_valid?(snapshots) } }
    when "public_c" then ->(n) { n.times { Lowrail::Native.same_method?(receiver, :target, saved) } }
    when "stat" then ->(n) { n.times { RubyVM.stat(:global_cvar_state) } }
    when "basic_c" then ->(n) { n.times { Lowrail::Native.plain_hash_iteration?(hash) } }
    end
    n = 500_000
  when "request"
    ENV["RAILS_ENV"] = "production"
    require "action_controller/railtie"
    class TokenApp < Rails::Application
      config.eager_load = false
      config.secret_key_base = "public-method-token-fixture-" * 4
      config.hosts.clear
      config.logger = Logger.new(File::NULL)
      config.action_controller.allow_forgery_protection = false
      config.action_dispatch.show_exceptions = :none
    end
    class TokenController < ActionController::Base
      INPUT = "asset-cache-key/left/v1".freeze
      OFF = %w[off_a off_b].include?(MethodTokenExperiment.arm)
      def show
        result = OFF ? Digest::SHA256.base64digest(INPUT) : MethodTokenExperiment.digest(INPUT)
        render plain: result
      end
    end
    TokenApp.initialize!
    TokenApp.routes.draw { get "/digest", to: "token#show" }
    dependencies = MethodTokenExperiment.install
    request = Rack::MockRequest.new(TokenApp)
    expected = Digest::SHA256.base64digest(TokenController::INPUT)
    operation = ->(count) do
      count.times do
        response = request.get("/digest")
        raise "response mismatch" unless response.status == 200 && response.body == expected
      end
    end
    n = 2_000
  else
    abort "unknown worker"
  end
  # Rehearse exact measurement path, including counter consumers, before the
  # single finite cohort. GC remains enabled; report collections, do not hide it.
  3.times { MethodTokenExperiment.observe(200, &operation) }
  warmup = if RubyVM::YJIT.enabled?
    JitStability.warm { |count, _| operation.call(count) }
  else
    operation.call(2_000)
    nil
  end
  GC.start
  result = MethodTokenExperiment.observe(n, &operation)
  puts JSON.generate(MethodTokenExperiment.stamp.merge(kind: kind, arm: arm, n: n,
    dependencies: dependencies, warmup: warmup, window: result))
  exit
end

command, out = ARGV
abort "usage: method_token_experiment.rb study NEW_DIRECTORY" unless command == "study" && out
abort "output must be new" if File.exist?(out)
FileUtils.mkdir_p(out)
rng = Random.new(41231)
samples = []
%w[interpreter yjit].each do |jit|
  flags = jit == "yjit" ? %w[--yjit --disable-zjit] : %w[--disable-yjit --disable-zjit]
  {"micro" => %w[off_a off_b tokens method unbound owner_only public public_c stat basic_c],
   "request" => %w[off_a off_b hooks public tokens], "probe" => %w[hooks public tokens]}.each do |kind, arms|
    (kind == "probe" ? 1 : 8).times do |round|
      arms.shuffle(random: rng).each do |arm|
        log, status = Open3.capture2e({"METHOD_TOKEN_WORKER" => "#{kind}:#{arm}", "RUBYOPT" => nil,
          "BENCH_JIT" => jit}, RbConfig.ruby, *flags, File.expand_path(__FILE__))
        File.write(File.join(out, "#{jit}-#{kind}-#{round}-#{arm}.log"), log)
        raise log unless status.success?
        sample = JSON.parse(log.lines.reverse.find { _1.start_with?("{") })
        samples << sample.merge("mode" => jit, "round" => round)
        File.write(File.join(out, "samples.json"), JSON.pretty_generate(samples))
        warn "#{jit} #{kind} #{round} #{arm}"
      end
    end
  end
end
summaries = samples.reject { _1["kind"].nil? }.group_by { [_1.fetch("mode"), _1.fetch("kind")] }.to_h do |key, group|
  pairs = group.group_by { _1.fetch("round") }
  flat = group.all? { _1.fetch("window").fetch("jit_flat") && (!_1["warmup"] || _1.fetch("warmup").fetch("stable")) }
  rounds = pairs.values.map do |rows|
    rows.to_h do |row|
      window, n = row.fetch("window"), row.fetch("n")
      [row.fetch("arm"), {"wall_us" => window.fetch("seconds") * 1e6 / n,
        "cpu_us" => window.fetch("cpu_seconds") * 1e6 / n,
        "allocations" => window.fetch("allocated").fdiv(n)}]
    end
  end
  summary = RequestPairs.summarize(rounds, seed: 41231, tolerance: 2)
  [key.join("/"), summary.merge(jit_flat: flat, accepted_native: flat && summary.fetch(:aa).fetch(:pass))]
end
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summaries))
puts JSON.pretty_generate(summaries)
