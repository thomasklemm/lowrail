# frozen_string_literal: true

# Whole-request PRICING specimen, not production token/collection admission.
# Keep the real passive form unit. Do not use the micro installers: they
# construct views, resolve templates and require objspace. Observe only the
# first natural original render, symmetrically, then attach identical named
# seams in both arms. No filter flattening or template/preloader delivery.
require_relative "sealed_collection"
require_relative "sealed_tokens"

if $PROGRAM_NAME == __FILE__
  require_relative "../pass"
  app, output, gate_file = ARGV.map { File.expand_path(_1) }
  abort "usage: sealed_combined.rb APP NEW_OUTPUT GATE_REPORT" unless app && output && gate_file
  raise "new cohort output required; never retry to green" if File.exist?(output)
  raise "interpreter only" unless JitStability.mode == "interpreter"
  jobs = Integer(ENV.fetch("BENCH_JOBS", "2"))
  raise "one or two allocated slots only" unless (1..2).cover?(jobs)
  ENV["BENCH_JOBS"] = jobs.to_s
  gate = JSON.parse(File.read(gate_file))
  raise "combined artifact review gates required" unless gate.fetch("status") == "pass" &&
    gate.fetch("cold").fetch("status") == "equivalent_for_executed_scenarios" &&
    gate.fetch("pairs").keys.sort == %w[none render_subscriber] &&
    gate.fetch("pairs").values.all? { _1.fetch("pairs") == 192 } &&
    %w[form token collection].all? { gate.fetch("native").fetch("hits").fetch(_1).positive? } &&
    gate.fetch("native").fetch("fallbacks").values.all?(&:zero?)
  root = File.expand_path("../..", __dir__)
  lib = File.join(root, "gem/lib")
  pin = ->(path) { Digest::SHA256.file(path).hexdigest }
  raise "reviewed manifest changed" unless pin.call(File.join(app, ".lowrail/manifest.json")) == gate.fetch("manifest_sha256")
  runtime = PassBench.runtime_fingerprint(lib)
  harness = PassBench.harness_fingerprint
  raise "reviewed runtime changed" unless runtime == gate.fetch("runtime_files_sha256")
  raise "reviewed harness changed" unless harness == gate.fetch("harness_files_sha256")
  framework = gate.fetch("native").fetch("framework_sources")
  raise "reviewed framework changed" unless framework.all? { |file, sha| pin.call(file) == sha }
  binary = gate.fetch("native").fetch("native_binary")
  raise "reviewed native binary changed" unless binary.size == 1 && binary.all? { |file, sha| pin.call(file) == sha }
  Dir.chdir(app) { PassBench.preflight(File.join(app, ".lowrail"), lib, root: app) }
  env = {"RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1",
    "LOWRAIL_SEALED" => "1", "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"),
    "LOWRAIL_UNITS" => nil, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_SHADOW" => nil,
    "LOWRAIL_DEBUG" => nil, "RUBYOPT" => "-I#{lib} -rlowrail/setup -r#{File.expand_path(__FILE__)}",
    "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil, "BENCH_JIT" => "0", "BENCH_WARMUP" => "50"}
  arms = %w[off_a off_b combined].to_h { [_1, env.merge("LOWRAIL" => _1 == "combined" ? "1" : "0")] }
  FileUtils.mkdir_p(output, mode: 0o700)
  File.write(File.join(output, "gates.json"), JSON.pretty_generate(gate))
  metadata = {seed: 41231, rounds: 6, workers: {}, gate_report_sha256: pin.call(gate_file),
    manifest_sha256: gate.fetch("manifest_sha256"), provenance: gate.fetch("provenance"),
    scope: "Whole GET /articles/1, passive form + token/collection pricing specimens. Symmetric seams in off/on; not production support or additive micro arithmetic."}
  accepted = RequestPairs.heap_instructions(arms, app, output, "GET:/articles/1", metadata,
    worker: "heap_requests.rb", requests: 50)
  raise "runtime changed during cohort" unless runtime == PassBench.runtime_fingerprint(lib)
  raise "harness changed during cohort" unless harness == PassBench.harness_fingerprint
  raise "framework changed during cohort" unless framework.all? { |file, sha| pin.call(file) == sha }
  raise "native binary changed during cohort" unless binary.all? { |file, sha| pin.call(file) == sha }
  raise "manifest changed during cohort" unless pin.call(File.join(app, ".lowrail/manifest.json")) == gate.fetch("manifest_sha256")
  puts "SEALED_COMBINED_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
  exit(accepted ? 0 : 2)
end

module SealedCombined
  CLASS = Object.instance_method(:class)
  BLOCK_SOURCE = Proc.instance_method(:source_location)

  module FormObservation
    def observe(view, block)
      super
      SealedCombined.admit(view, block)
    end
  end

  module Variant
    def render(options = {}, locals = {}, &block)
      if SealedCombined.collection_site?(self, options, locals, block)
        values = options.to_a
        if SealedCombined.values?(values)
          SealedCombined.count(:collection)
          return SealedCollectionCost.render(self, values)
        end
        SealedCombined.count(:collection_fallback)
      end
      super
    end

    private

    def token_tag(token = nil, form_options: {})
      if SealedCombined.token_site?(self)
        if SealedCombined.token_input?(token, form_options)
          SealedCombined.count(:token)
          return SealedTokenCost.render(self, form_options)
        end
        SealedCombined.count(:token_fallback)
      end
      super
    end
  end

  class << self
    attr_reader :refusal, :sources, :counts, :witness_seconds

    def install
      raise "sealed opt-in and explicit off/on required" unless ENV["LOWRAIL_SEALED"] == "1" && %w[0 1].include?(ENV["LOWRAIL"])
      raise "native actual-holder predicate required" unless Lowrail.loaded_constant("Lowrail::Native")
      @exact = Lowrail::Native.method(:exact_class?)
      @enabled = ENV["LOWRAIL"] == "1"
      @count = !ENV["LOWRAIL_STATS"].nil?
      @counts = Hash.new(0)
      manifest = Lowrail::MiniJSON.parse(File.read(File.join(ENV.fetch("LOWRAIL_DIR"), "manifest.json")))
      raise "only an isolated passive form artifact" unless manifest.fetch("units").size == 1 &&
        manifest.fetch("units").first.fetch("pass") == "sealed/form_scaffold" &&
        manifest.fetch("files").empty? && manifest.fetch("templates", {}).empty?
      @site = manifest.fetch("units").first.fetch("data").fetch("site").fetch("source_location").dup
      @site[0] = File.expand_path(@site.first, ENV.fetch("LOWRAIL_ROOT"))
      Lowrail::FormScaffold.singleton_class.prepend(FormObservation)
      Lowrail::LoadHooks.active_support do
        ActiveSupport.on_load(:action_view) { SealedCombined.watch }
      end
    end

    def watch
      template = Lowrail.loaded_constant("ActionView::Template")
      rendering = Lowrail.loaded_constant("ActionView::Helpers::RenderingHelper")
      raise "natural Action View boundary incomplete" unless template && rendering
      @template_trace = TracePoint.new(:call) do |event|
        object = event.self
        @template = object if object.instance_variable_get(:@identifier)&.end_with?("/app/views/comments/_comment.html.erb")
      end
      @template_trace.enable(target: template.instance_method(:render))
      @collection_trace = TracePoint.new(:call) do |event|
        options = event.binding.local_variable_get(:options)
        type = Lowrail.loaded_constant("ActiveRecord::Associations::CollectionProxy")
        @proxy_class = CLASS.bind_call(options) if type && type === options
      end
      @collection_trace.enable(target: rendering.instance_method(:render))
    end

    def admit(view, block)
      return if @attempted || !block || BLOCK_SOURCE.bind_call(block) != @site
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @attempted = true
      @template_trace&.disable
      @collection_trace&.disable
      raise "natural comment partial/proxy missing" unless @template && @proxy_class
      raise "production interpreter blog required" unless Rails.env.production? && Rails.version == "8.1.4" && Lowrail.jit_mode == "interpreter"
      raise "passive form failed before combined specimen" if @enabled && !Lowrail::FormScaffold.admitted?
      @view_class = CLASS.bind_call(view)
      raise "foreign natural view" unless @exact.call(view, @view_class)
      @article_class = Lowrail.loaded_constant("Article")
      @comment_class = Lowrail.loaded_constant("Comment")
      @epoch = defined?(Lowrail::Seal) ? Lowrail::Seal::EPOCH : Lowrail::Sealed::EPOCH
      @thread = Thread.current
      # Template came from the app's real partial render; never perform lookup
      # or compile it here. Keep the accepted collection operation unchanged.
      SealedCollectionCost.instance_variable_set(:@template, @template)
      @sources = %w[actionview actionpack activesupport].flat_map do |name|
        Dir[File.join(Gem.loaded_specs.fetch(name).full_gem_path, "lib/**/*.rb")]
      end.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
      @view_class.prepend(Variant)
      @ready = true
    rescue StandardError, ScriptError => error
      @refusal = "combined pricing admission: #{error.class}: #{error.message}; original"
      @ready = false
    ensure
      @witness_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started if started
    end

    def active?(view)
      @enabled && @ready && Thread.current.equal?(@thread) && Ractor.current.equal?(Ractor.main) && @epoch[0].zero? &&
        @exact.call(view, @view_class)
    end

    def collection_site?(view, records, locals, block)
      active?(view) && locals.empty? && !block && I18n.locale == :en && @exact.call(records, @proxy_class) &&
        view.instance_variable_get(:@virtual_path) == "articles/show" && view.lookup_context.formats == [:html] &&
        @exact.call(records.proxy_association.owner, @article_class) &&
        records.proxy_association.owner.equal?(view.instance_variable_get(:@article)) && Comment.current_scope.nil?
    end

    def values?(values) = values.all? { @exact.call(_1, @comment_class) }

    def token_site?(view)
      active?(view) && view.request.get? && %w[/articles/1 /articles/2 /articles/3].include?(view.request.path)
    end

    def token_input?(token, options)
      token.nil? && @exact.call(options, Hash) && options.size == 2 && options.key?(:action) && options.key?(:method)
    end

    def count(key)
      @counts[key] += 1 if @count
    end
  end
end

SealedCombined.install
