# frozen_string_literal: true

# Pricing specimen only, never loaded by the runtime. Keep real templates,
# security helpers, token generation/masking, sessions and configuration live.
module SealedTokenCost
  EPOCH = [0]
  class << self
    attr_accessor :hits, :fallbacks, :capture
    attr_reader :sources

    def prepare
      raise "only selected blog / Rails 8.1.4" unless Rails.version == "8.1.4" && Rails.root.realpath.to_s == File.realpath(Dir.pwd)
      require "objspace"
      require "digest"
      @holder = ObjectSpace.method(:internal_class_of)
      @view_class = ArticlesController.view_context_class
      @sources = %w[actionview actionpack activesupport].flat_map do |name|
        root = Gem.loaded_specs.fetch(name).full_gem_path
        paths = case name
        when "actionview" then %w[action_view/helpers/url_helper.rb action_view/helpers/tag_helper.rb]
        when "actionpack" then %w[action_controller/metal/request_forgery_protection.rb]
        else %w[active_support/core_ext/erb/util.rb active_support/core_ext/string/output_safety.rb]
        end
        paths.map { [File.join(root, "lib", _1), Digest::SHA256.file(File.join(root, "lib", _1)).hexdigest] }
      end.to_h
      raise "custom token tag attributes" unless %i[type name value autocomplete].all? { ActionView::Helpers::TagHelper::TAG_TYPES[_1].nil? }
      self.hits = self.fallbacks = 0
      self.capture = []
    end

    def target?(view)
      view.request.get? && %w[/articles/1 /articles/2 /articles/3].include?(view.request.path)
    end

    def eligible?(view, token, options)
      Ractor.current.equal?(Ractor.main) && EPOCH[0].zero? && @holder.call(view).equal?(@view_class) &&
        target?(view) && token.nil? && @holder.call(options).equal?(Hash) &&
        options.size == 2 && options.key?(:action) && options.key?(:method)
    end

    def render(view, options)
      return "" unless view.send(:protect_against_forgery?)
      value = view.form_authenticity_token(form_options: options.merge(authenticity_token: nil))
      name = view.send(:request_forgery_protection_token).to_s
      autocomplete = ActionView::Base.remove_hidden_field_autocomplete ? "" : ' autocomplete="off"'
      # TagBuilder also replaces quotes in html_safe values; html_escape alone
      # would trust those quotes and change the attribute boundary.
      name = ERB::Util.unwrapped_html_escape(name).gsub('"', "&quot;")
      value = ERB::Util.unwrapped_html_escape(value).gsub('"', "&quot;")
      %(<input type="hidden" name="#{name}" value="#{value}"#{autocomplete} />).html_safe
    end

    def install(arm)
      prepare
      @view_class.prepend(Module.new do
        define_method(:token_tag) do |token = nil, form_options: {}|
          if SealedTokenCost.target?(self)
            SealedTokenCost.capture << [self, token, form_options.dup] if arm == "capture"
            if arm == "candidate"
              if SealedTokenCost.eligible?(self, token, form_options)
                result = SealedTokenCost.render(self, form_options)
                SealedTokenCost.hits += 1
                next result
              end
              SealedTokenCost.fallbacks += 1
            end
          end
          super(token, form_options: form_options)
        end
        private :token_tag
      end)
    end
  end
  self.hits = self.fallbacks = 0
end

if $PROGRAM_NAME == __FILE__ && ENV["SEALED_TOKEN_WORKER"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json"
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  raise "interpreter only" if RubyVM::YJIT.enabled?
  client = Rack::MockRequest.new(Rails.application)
  request = -> { client.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on") }
  SealedTokenCost.install("capture")
  raise "capture request failed" unless request.call.status == 200
  captured = SealedTokenCost.capture.dup
  raise "expected delete and post token calls" unless captured.size == 4 && captured.map { _1.last.fetch(:method) } == %w[delete delete delete post]
  view = captured.first.first
  original = view.method(:token_tag).super_method
  view.method(:token_tag).owner.send(:remove_method, :token_tag)
  candidate = ->(token, options) {
    SealedTokenCost.eligible?(view, token, options) ? SealedTokenCost.render(view, options) : original.call(token, form_options: options)
  }
  normalize = ->(html) { html.gsub(/ value="[^"]*"/, ' value="MASK"') }
  validate = ->(token, options) {
    left, right = original.call(token, form_options: options), candidate.call(token, options)
    generated = (token.nil? || token == true) && view.send(:protect_against_forgery?)
    raise "token bytes/class/safety/encoding differ" unless (generated ? normalize.call(left) == normalize.call(right) : left == right) &&
      left.class == right.class && left.encoding == right.encoding && left.html_safe? == right.html_safe?
    if generated
      [left, right].each do |html|
        value = html[/ value="([^"]+)"/, 1] or raise "missing token"
        controller = view.controller
        decoded = controller.send(:unmask_token, controller.send(:decode_csrf_token, value))
        expected = controller.send(:per_form_csrf_token, view.session, URI.parse(options.fetch(:action)).path, options.fetch(:method))
        raise "invalid live per-form token" unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded, expected)
      end
      raise "token mask reused" if left == right
    end
  }
  captured.each { |_, token, options| validate.call(token, options) }
  options = captured.last.last
  [false, true, 'literal<&" Ω'].each do |token|
    raise "explicit token accepted" if SealedTokenCost.eligible?(view, token, options)
    validate.call(token, options)
  end
  saved = ActionView::Base.remove_hidden_field_autocomplete
  [true, false].each do |value|
    ActionView::Base.remove_hidden_field_autocomplete = value
    validate.call(nil, options)
  end
  ActionView::Base.remove_hidden_field_autocomplete = saved
  controller = view.controller
  saved = controller.class.request_forgery_protection_token
  controller.class.request_forgery_protection_token = 'csrf<&" Ω'.html_safe
  validate.call(nil, options)
  controller.class.request_forgery_protection_token = saved
  saved = controller.class.allow_forgery_protection
  controller.class.allow_forgery_protection = false
  validate.call(nil, options)
  controller.class.allow_forgery_protection = saved
  foreign = options.dup
  foreign.define_singleton_method(:merge) { |other| super(other) }
  raise "singleton options accepted" if SealedTokenCost.eligible?(view, nil, foreign)
  SealedTokenCost::EPOCH[0] = 1
  raise "epoch accepted" if SealedTokenCost.eligible?(view, nil, options)
  validate.call(nil, options)
  SealedTokenCost::EPOCH[0] = 0
  operations = {
    "original" => -> { captured.each { |_, token, opts| original.call(token, form_options: opts.dup) } },
    "checks" => -> { captured.each { |_, token, opts| SealedTokenCost.eligible?(view, token, opts.dup) } },
    "residue" => -> { captured.each { |_, _, opts| SealedTokenCost.render(view, opts.dup) } },
    "candidate" => -> { captured.each { |_, token, opts| candidate.call(token, opts.dup) } }
  }
  operation = operations.fetch(ENV.fetch("SEALED_TOKEN_WORKER"))
  if ENV["SEALED_TOKEN_CHECK"] == "1"
    operations.each_value { |call| 3.times { call.call } }
    SealedTokenCost.install("candidate")
    50.times { raise "native request failed" unless request.call.status == 200 }
    raise "native liveness missing" unless SealedTokenCost.hits == 200 && SealedTokenCost.fallbacks.zero?
    live = {hits: SealedTokenCost.hits, fallbacks: SealedTokenCost.fallbacks}
    SealedTokenCost::EPOCH[0] = 1
    raise "epoch request failed" unless request.call.status == 200
    raise "epoch fallback missing" unless SealedTokenCost.hits == 200 && SealedTokenCost.fallbacks == 4
    puts "SEALED_TOKEN_CHECK #{JSON.generate(untimed: true, requests: 50, **live, epoch_fallback: true,
      tokens_per_request: captured.length, arms: operations.keys, framework_sources: SealedTokenCost.sources)}"
    exit
  end
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  200.times { operation.call }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ["tokens"])
  anchors = HeapWindows.run(windows) { |n, _| n.times { operation.call } }
  raise "framework changed" unless SealedTokenCost.sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: false, windows: windows, heap_anchors: anchors,
    ar_installed: 0, framework_sources: SealedTokenCost.sources, operations: {tokens: {invocations_per_iteration: captured.length}})}"
elsif $PROGRAM_NAME == __FILE__
  require_relative "../request_pairs"
  app, out = ARGV.map { File.expand_path(_1) }
  abort "usage: sealed_tokens.rb APP NEW_OUTPUT" unless app && out
  raise "new output required" if File.exist?(out)
  raise "interpreter only" unless ENV.fetch("BENCH_JIT", "0") == "0"
  raise "one to four workers" unless (1..4).cover?(Integer(ENV.fetch("BENCH_JOBS", "4")))
  FileUtils.mkdir_p(out, mode: 0o700)
  env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
    "LOWRAIL_STATS" => nil, "LOWRAIL_SHADOW" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0", "SEALED_TOKEN_CHECK" => nil}
  environments = %w[off_a off_b checks residue candidate].to_h do |arm|
    [arm, env.merge("SEALED_TOKEN_WORKER" => arm.start_with?("off") ? "original" : arm)]
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
    worker: File.expand_path(__FILE__), requests: 200)
  raw = JSON.parse(File.read(File.join(out, "samples.json")))
  raise "framework changed between workers" unless raw.fetch("workers").values.map { _1.fetch("framework_sources") }.uniq.one?
  raise "measured source changed" unless sources.all? { |file, sha| Digest::SHA256.file(File.join(root, file)).hexdigest == sha }
  raise "fixture changed" unless provenance.fetch(:fixture_sources).all? { |file, sha| Digest::SHA256.file(File.join(app, file)).hexdigest == sha }
  raise "lock changed" unless Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest == provenance.fetch(:lock_sha256)
  puts "SEALED_TOKEN_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
  exit(accepted ? 0 : 2)
end
