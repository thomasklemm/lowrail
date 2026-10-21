# frozen_string_literal: true

# Pre-implementation price only, never required by the runtime. The fixed
# collection plan comes from sealed_renderer.rb, but retains STOCK partials,
# templates, form helpers, filters and dispatch. Not a production certificate.
module SealedCollectionCost
  EPOCH = [0]
  class << self
    attr_accessor :hits, :capture
    attr_reader :sources

    def prepare
      raise "only stock blog / Rails 8.1.4" unless Rails.version == "8.1.4" && Rails.application.class.name == "RealBlogR4::Application"
      require "objspace"
      require "digest"
      @sources = %w[helpers/rendering_helper.rb renderer/renderer.rb renderer/abstract_renderer.rb renderer/partial_renderer.rb
        renderer/collection_renderer.rb renderer/object_renderer.rb renderer/partial_renderer/collection_caching.rb template.rb].to_h do |path|
        file = File.join(Gem.loaded_specs.fetch("actionview").full_gem_path, "lib/action_view", path)
        [file, Digest::SHA256.file(file).hexdigest]
      end
      @holder = ObjectSpace.method(:internal_class_of)
      @view_class = ArticlesController.view_context_class
      @proxy_class = Article.first!.comments.class
      @article_class, @comment_class = Article, Comment
      reflection = Article.reflect_on_association(:comments)
      raise "association scope boundary" unless reflection.scope.nil? && Comment.default_scopes.empty?
      raise "initialization boundary" unless Comment._initialize_callbacks.empty? && Comment._find_callbacks.empty?
      lookup = ArticlesController.new.view_context.lookup_context
      lookup.formats = [:html]
      @template = lookup.find_template("comments/comment", [], true, %i[comment comment_counter comment_iteration])
      self.hits = 0
    end

    def eligible?(view, records)
      Ractor.current.equal?(Ractor.main) && EPOCH[0].zero? && I18n.locale == :en &&
        @holder.call(view).equal?(@view_class) && @holder.call(records).equal?(@proxy_class) &&
        view.instance_variable_get(:@virtual_path) == "articles/show" && view.lookup_context.formats == [:html] &&
        @holder.call(records.proxy_association.owner).equal?(@article_class) &&
        records.proxy_association.owner.equal?(view.instance_variable_get(:@article)) && Comment.current_scope.nil?
    end

    def values?(values)
      values.all? { @holder.call(_1).equal?(@comment_class) }
    end

    def render(view, values)
      # Materialization happens BEFORE the collection event, exactly as in the
      # derived-partial renderer. Keep the original empty result (nil), not an
      # empty SafeBuffer, and every real Template#render/event/buffer boundary.
      ActiveSupport::Notifications.instrument("render_collection.action_view",
        identifier: values.empty? ? nil : @template.identifier, layout: nil, count: values.length) do
        unless values.empty?
          locals = {}
          iteration = ActionView::PartialIteration.new(values.length)
          values.map do |record|
            locals[:comment] = record
            locals[:comment_counter] = iteration.index
            locals[:comment_iteration] = iteration
            body = @template.render(view, locals, implicit_locals: %i[comment_counter comment_iteration])
            iteration.iterate!
            body
          end.join.html_safe
        end
      end
    end

    def install(arm)
      prepare
      @view_class.prepend(Module.new do
        define_method(:render) do |options = {}, locals = {}, &block|
          if locals.empty? && !block && SealedCollectionCost.eligible?(self, options)
            SealedCollectionCost.capture = [self, options.proxy_association.owner] if arm == "capture"
            if arm == "candidate"
              values = options.to_a
              if SealedCollectionCost.values?(values)
                SealedCollectionCost.hits += 1
                next SealedCollectionCost.render(self, values)
              end
            end
          end
          super(options, locals, &block)
        end
      end)
    end
  end
  self.hits = 0
end

if $PROGRAM_NAME == __FILE__ && ENV["SEALED_COLLECTION_WORKER"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json"
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  raise "interpreter only" if RubyVM::YJIT.enabled?
  SealedCollectionCost.install("capture")
  response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
  raise "capture failed" unless response.status == 200 && SealedCollectionCost.capture
  view, article = SealedCollectionCost.capture
  view.method(:render).owner.send(:remove_method, :render)
  # Template#render restores the caller's virtual path after a request. Replay
  # is this literal collection site, with its original view and parent assign.
  view.instance_variable_set(:@virtual_path, "articles/show")
  original = ->(records) { view.render(records) }
  candidate = ->(records) {
    if SealedCollectionCost.eligible?(view, records)
      values = records.to_a
      SealedCollectionCost.values?(values) ? SealedCollectionCost.render(view, values) : original.call(records)
    else
      original.call(records)
    end
  }
  # Fresh association/records AND SQL on every replay, not a hot loaded
  # collection masquerading as the request operation. Both arms pay reset.
  fresh = -> { article.association(:comments).reset; article.comments }
  normalize = ->(html) { html&.gsub(/(name="authenticity_token" value=")[^"]+/, '\\1MASK') }
  parents = [article, Article.find(2), Article.find(3)]
  fixture_counts = parents.map { _1.comments.size }
  raise "expected two/one/zero comment fixture" unless fixture_counts == [2, 1, 0]
  parents.each do |parent|
    view.instance_variable_set(:@article, parent)
    parent.association(:comments).reset
    left = original.call(parent.comments)
    parent.association(:comments).reset
    right = candidate.call(parent.comments)
    raise "collection bytes/class/safety differ" unless normalize.call(left) == normalize.call(right) && left.class == right.class &&
      (left.nil? || (left.encoding == right.encoding && left.html_safe? == right.html_safe?))
    [left, right].each do |html|
      forms = html.to_s.scan(/<form\b[^>]*action="([^"]+)"[^>]*>(.*?)<\/form>/m)
      raise "missing live delete forms" unless forms.length == parent.comments.length
      forms.each do |action, body|
        token = body[/name="authenticity_token" value="([^"]+)"/, 1] or raise "token missing"
        verb = body[/name="_method" value="([^"]+)"/, 1] || "post"
        decoded = view.controller.send(:unmask_token, view.controller.send(:decode_csrf_token, token))
        expected = view.controller.send(:per_form_csrf_token, view.session, URI.parse(action).path, verb)
        raise "invalid live token" unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded, expected)
      end
    end
  end
  view.instance_variable_set(:@article, article)
  raise "array accepted" if SealedCollectionCost.eligible?(view, article.comments.to_a)
  foreign = Comment.new
  foreign.define_singleton_method(:commenter) { "foreign holder" }
  raise "singleton row accepted" if SealedCollectionCost.values?([foreign])
  raise "foreign owner accepted" if SealedCollectionCost.eligible?(view, Article.find(2).comments)
  SealedCollectionCost::EPOCH[0] = 1
  raise "deopt accepted" if SealedCollectionCost.eligible?(view, article.comments)
  SealedCollectionCost::EPOCH[0] = 0
  operations = {
    "original" => -> { original.call(fresh.call) },
    "checks" => -> { records = fresh.call; SealedCollectionCost.eligible?(view, records) && SealedCollectionCost.values?(records.to_a) },
    "residue" => -> { SealedCollectionCost.render(view, fresh.call.to_a) },
    "candidate" => -> { candidate.call(fresh.call) }
  }
  operation = operations.fetch(ENV.fetch("SEALED_COLLECTION_WORKER"))
  raise "replay would refuse" unless operations.fetch("checks").call
  if ENV["SEALED_COLLECTION_CHECK"] == "1"
    operations.each_value { |call| 3.times { call.call } }
    puts "SEALED_COLLECTION_CHECK #{JSON.generate(untimed: true, comments: article.comments.length, arms: operations.keys,
      fresh_association: true, fixture_counts: fixture_counts, framework_sources: SealedCollectionCost.sources)}"
    exit
  end
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  200.times { operation.call }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ["collection"])
  anchors = HeapWindows.run(windows) { |n, _| n.times { operation.call } }
  raise "framework changed" unless SealedCollectionCost.sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: false, windows: windows, heap_anchors: anchors,
    ar_installed: 0, framework_sources: SealedCollectionCost.sources,
    operations: {collection: {invocations_per_iteration: 1, fresh_association: true, comments: article.comments.length}})}"
elsif $PROGRAM_NAME == __FILE__
  require_relative "../request_pairs"
  app, out = ARGV.map { File.expand_path(_1) }
  abort "usage: sealed_collection.rb APP NEW_OUTPUT" unless app && out
  raise "new output required" if File.exist?(out)
  raise "interpreter only" unless ENV.fetch("BENCH_JIT", "0") == "0"
  raise "one to four workers" unless (1..4).cover?(Integer(ENV.fetch("BENCH_JOBS", "4")))
  FileUtils.mkdir_p(out, mode: 0o700)
  env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
    "LOWRAIL_STATS" => nil, "LOWRAIL_SHADOW" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0",
    "SEALED_COLLECTION_CHECK" => nil}
  environments = %w[off_a off_b checks residue candidate].to_h do |arm|
    [arm, env.merge("SEALED_COLLECTION_WORKER" => arm.start_with?("off") ? "original" : arm)]
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
  puts "SEALED_COLLECTION_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
  exit(accepted ? 0 : 2)
end
