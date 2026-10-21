# frozen_string_literal: true

# Isolate the callback interpreter, NOT callback bodies or controller dispatch.
# This is a measurement specimen, not an inventory learned as a certificate.
module SealedFilterCost
  EPOCH = [0]
  class << self
    attr_accessor :hits, :fallbacks
    attr_reader :sources

    def prepare
      raise "only selected blog / Rails 8.1.4" unless Rails.version == "8.1.4" && Rails.root.realpath.to_s == File.realpath(Dir.pwd)
      require "objspace"
      require "digest"
      @holder = ObjectSpace.method(:internal_class_of)
      @controller_class = ArticlesController
      @chain = ArticlesController._process_action_callbacks
      callbacks = @chain.to_a
      shape = callbacks.map { [_1.kind, _1.filter.is_a?(Symbol) ? _1.filter : :proc] }
      raise "unknown callback chain" unless shape == [[:before, :verify_authenticity_token], [:after, :verify_same_origin_request],
        [:around, :proc], [:around, :turbo_tracking_request_id], [:before, :proc], [:before, :set_article]]
      raise "unknown around callback arguments" unless callbacks[2].filter.arity == 2
      raise "unknown callback conditions" unless callbacks.first(5).all? { _1.instance_variable_get(:@if).empty? && _1.instance_variable_get(:@unless).empty? }
      condition = callbacks.last.instance_variable_get(:@if)
      raise "unknown action condition" unless condition.size == 1 && condition.first.instance_of?(AbstractController::Callbacks::ActionFilter) &&
        condition.first.instance_variable_get(:@filters) == [:set_article] && condition.first.instance_variable_get(:@conditional_key) == :only &&
        condition.first.instance_variable_get(:@actions) == %w[show edit update destroy].to_set && callbacks.last.instance_variable_get(:@unless).empty?
      outer = @chain.compile(nil)
      middle = outer.nested
      inner = middle&.nested
      raise "unknown callback sequence" unless middle && inner&.final? && inner.nested.nil? &&
        outer.instance_variable_get(:@user_conditions) == [] && middle.instance_variable_get(:@user_conditions) == [] &&
        outer.instance_variable_get(:@before)&.size == 1 && outer.instance_variable_get(:@after)&.size == 1 &&
        middle.instance_variable_get(:@before).nil? && middle.instance_variable_get(:@after).nil? &&
        inner.instance_variable_get(:@before)&.size == 2 && inner.instance_variable_get(:@after).nil?
      @verify = outer.instance_variable_get(:@before).first
      @after = outer.instance_variable_get(:@after).first
      @browser, @article = inner.instance_variable_get(:@before)
      @around = callbacks[2].filter
      paths = callbacks.map { _1.filter.is_a?(Symbol) ? ArticlesController.instance_method(_1.filter).source_location.first : _1.filter.source_location.first }
      paths += [ActiveSupport::Callbacks.instance_method(:run_callbacks).source_location.first,
        AbstractController::Callbacks.instance_method(:process_action).source_location.first,
        ActionText::Content.method(:with_renderer).source_location.first, Turbo.method(:with_request_id).source_location.first]
      @sources = paths.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
      self.hits = self.fallbacks = 0
    end

    def target?(controller)
      controller.action_name == "show" && controller.request.get? &&
        %w[/articles/1 /articles/2 /articles/3].include?(controller.request.path)
    end

    def eligible?(controller)
      Ractor.current.equal?(Ractor.main) && EPOCH[0].zero? && @holder.call(controller).equal?(@controller_class) &&
        target?(controller) && controller._process_action_callbacks.equal?(@chain)
    end

    def run(controller, &body)
      env = ActiveSupport::Callbacks::Filters::Environment.new(controller, false, nil)
      # Retain Rails' compiled Before/After objects: real conditions, performed?
      # terminator, halted_callback_hook and skip-after-on-halt stay untouched.
      @verify.call(env)
      if env.halted
        env.value = false
      else
        controller.instance_exec(controller, -> {
          controller.send(:turbo_tracking_request_id) do
            @browser.call(env)
            @article.call(env)
            env.value = !env.halted && body.call
          end
        }, &@around)
      end
      # Not an ensure: Rails does NOT execute after callbacks on exceptions.
      @after.call(env)
      env.value
    end

    def install
      prepare
      ArticlesController.prepend(Variant)
    end
  end

  module Variant
    def run_callbacks(kind, type = nil, &block)
      if kind == :process_action && SealedFilterCost.target?(self)
        if type.nil? && block && SealedFilterCost.eligible?(self)
          result = SealedFilterCost.run(self, &block)
          SealedFilterCost.hits += 1
          return result
        end
        SealedFilterCost.fallbacks += 1
      end
      super
    end
  end
  self.hits = self.fallbacks = 0
end

if $PROGRAM_NAME == __FILE__ && ENV["SEALED_FILTER_WORKER"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json"
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  raise "interpreter only" if RubyVM::YJIT.enabled?
  arm = ENV.fetch("SEALED_FILTER_WORKER")
  raise "unknown filter arm" unless %w[original candidate].include?(arm)
  arm == "candidate" ? SealedFilterCost.install : SealedFilterCost.prepare
  client = Rack::MockRequest.new(Rails.application)
  # A fresh Rack/controller/request/response and real SQL/render on every hit.
  # Never replay a previously performed controller or a captured super block.
  operation = -> { raise "request failed" unless client.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on").status == 200 }
  if ENV["SEALED_FILTER_CHECK"] == "1"
    raise "native check needs candidate" unless arm == "candidate"
    50.times { operation.call }
    raise "native liveness missing" unless SealedFilterCost.hits == 50 && SealedFilterCost.fallbacks.zero?
    live = {hits: SealedFilterCost.hits, fallbacks: SealedFilterCost.fallbacks}
    SealedFilterCost::EPOCH[0] = 1
    operation.call
    raise "epoch fallback missing" unless SealedFilterCost.hits == 50 && SealedFilterCost.fallbacks == 1
    SealedFilterCost::EPOCH[0] = 0
    ArticlesController.before_action { response.set_header("x-live-callback", "once") }
    response = client.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
    raise "changed chain did not fall back" unless response.status == 200 && response["x-live-callback"] == "once" &&
      SealedFilterCost.hits == 50 && SealedFilterCost.fallbacks == 2
    puts "SEALED_FILTER_CHECK #{JSON.generate(untimed: true, requests: 50, **live, epoch_fallback: true, chain_fallback: true,
      fresh_request: true, framework_sources: SealedFilterCost.sources)}"
    exit
  end
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  200.times { operation.call }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ["filters"])
  anchors = HeapWindows.run(windows) { |n, _| n.times { operation.call } }
  raise "framework changed" unless SealedFilterCost.sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: false, windows: windows, heap_anchors: anchors,
    ar_installed: 0, framework_sources: SealedFilterCost.sources, operations: {filters: {invocations_per_iteration: 1, fresh_request: true}})}"
elsif $PROGRAM_NAME == __FILE__
  require_relative "../request_pairs"
  app, out = ARGV.map { File.expand_path(_1) }
  abort "usage: sealed_filters.rb APP NEW_OUTPUT" unless app && out
  raise "new output required" if File.exist?(out)
  raise "interpreter only" unless ENV.fetch("BENCH_JIT", "0") == "0"
  raise "one to four workers" unless (1..4).cover?(Integer(ENV.fetch("BENCH_JOBS", "4")))
  FileUtils.mkdir_p(out, mode: 0o700)
  env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
    "LOWRAIL_STATS" => nil, "LOWRAIL_SHADOW" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0", "SEALED_FILTER_CHECK" => nil}
  environments = %w[off_a off_b candidate].to_h do |arm|
    [arm, env.merge("SEALED_FILTER_WORKER" => arm.start_with?("off") ? "original" : arm)]
  end
  root = File.expand_path("../..", __dir__)
  sources = [__FILE__, File.expand_path("blog_endpoint_check.rb", __dir__), File.expand_path("../callgrind.c", __dir__),
    *%w[request_pairs heap_windows jit_stability].map { File.expand_path("../#{_1}.rb", __dir__) }].to_h {
    [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] }
  provenance = {revision: `git -C #{root.shellescape} rev-parse HEAD`.strip, sources: sources,
    lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
    fixture_sources: Dir[File.join(app, "{app,config,db}/**/*")].select { File.file?(_1) }.to_h {
      [_1.delete_prefix(app + "/"), Digest::SHA256.file(_1).hexdigest] }}
  File.write(File.join(out, "provenance.json"), JSON.pretty_generate(provenance))
  metadata = {seed: 41231, rounds: 6, workers: {}, provenance: provenance}
  accepted = RequestPairs.heap_instructions(environments, app, out, "GET:/articles/1", metadata,
    worker: File.expand_path(__FILE__), requests: 50)
  raw = JSON.parse(File.read(File.join(out, "samples.json")))
  raise "framework changed between workers" unless raw.fetch("workers").values.map { _1.fetch("framework_sources") }.uniq.one?
  raise "measured source changed" unless sources.all? { |file, sha| Digest::SHA256.file(File.join(root, file)).hexdigest == sha }
  raise "fixture changed" unless provenance.fetch(:fixture_sources).all? { |file, sha| Digest::SHA256.file(File.join(app, file)).hexdigest == sha }
  raise "lock changed" unless Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest == provenance.fetch(:lock_sha256)
  puts "SEALED_FILTER_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
  exit(accepted ? 0 : 2)
end
