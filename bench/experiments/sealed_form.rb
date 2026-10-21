# frozen_string_literal: true

# Pre-implementation price, NOT a Lowrail pass or a production certificate.
# Replay the actual captured ERB block, not a cheaper handwritten baseline.
# Stock methods/config/I18n and the literal site are prerequisites, not facts
# established by observing one request. Unknown holders/values use the original.
module SealedFormCost
  EPOCH = [0]
  class << self
    attr_accessor :hits, :capture

    def prepare
      raise "only stock blog / Rails 8.1.4" unless Rails.version == "8.1.4" && Rails.application.class.name == "RealBlogR4::Application"
      require "objspace"
      @holder = ObjectSpace.method(:internal_class_of)
      @view_class = ArticlesController.view_context_class
      @article_class, @model_class = Article, Comment
      @builder_class = ActionView::Helpers::TagHelper::TagBuilder
      @table = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
      @ivars = Object.instance_method(:instance_variable_get)
      path = Rails.root.join("app/views/articles/show.html.erb").to_s
      @site = [path, File.readlines(path).index { _1.include?("form_with model:") } + 1]
      raise "initialize callback boundary" unless Comment._initialize_callbacks.empty?
      raise "nonblank schema defaults" unless %w[commenter body].all? { Comment.column_defaults.fetch(_1).nil? }
      self.hits = 0
    end

    def site?(model, options, block)
      model.instance_of?(Array) && model.size == 2 && options == {class: "space-y-4"} &&
        block && block.source_location == @site
    end

    def eligible?(view, article, model)
      # Conservative per-hit authorization charge. No method/visibility lookup,
      # singleton-class creation, TracePoint or memoized model/token/HTML.
      return false unless Ractor.current.equal?(Ractor.main) && EPOCH[0].zero? &&
        @holder.call(view).equal?(@view_class) && @holder.call(article).equal?(@article_class) &&
        @holder.call(model).equal?(@model_class) && I18n.locale == :en && article.persisted? &&
        !model.persisted? && model.commenter.nil? && model.body.nil? && model.errors.empty?
      builder = view.send(:tag_builder)
      @holder.call(builder).equal?(@builder_class) && @ivars.bind_call(builder, :@view_context).equal?(view)
    end

    def render(view, article)
      # Preserve both original URL calls. Token generation is AFTER the field
      # scaffold, as in form_with; arbitrary security behavior is not folded.
      path = view.article_comments_path(article)
      fields = %(
  <div>
    <label class="block font-medium" for="comment_commenter">#{@table[:label]}Commenter</label>
    <input class="block w-full border rounded p-2" type="text" name="comment[commenter]" id="comment_commenter" />
  </div>
  <div>
    <label class="block font-medium" for="comment_body">#{@table[:label]}Body</label>
    <textarea rows="3" class="block w-full border rounded p-2" name="comment[body]" id="comment_body">#{@table["textarea"]}</textarea>
  </div>
  <input type="submit" name="commit" value="Add Comment" class="bg-blue-600 text-white px-4 py-2 rounded" data-disable-with="Add Comment" />
)
      path = view.url_for(path)
      token = view.send(:token_tag, nil, form_options: {action: path, method: "post"})
      %(<form class="space-y-4" action="#{ERB::Util.html_escape(path)}" accept-charset="UTF-8" method="post">#{token}#{fields}</form>).html_safe
    end

    def install(arm)
      prepare
      @view_class.prepend(Module.new do
        define_method(:form_with) do |model: false, **options, &block|
          site = SealedFormCost.site?(model, options, block)
          SealedFormCost.capture = [self, model.first, block] if site && arm == "capture"
          if site && arm == "candidate" && SealedFormCost.eligible?(self, *model)
            SealedFormCost.hits += 1
            SealedFormCost.render(self, model.first)
          else
            super(model: model, **options, &block)
          end
        end
      end)
    end
  end
  self.hits = 0
end

if $PROGRAM_NAME == __FILE__ && ENV["SEALED_FORM_WORKER"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json"
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  raise "interpreter only" if RubyVM::YJIT.enabled?
  SealedFormCost.install("capture")
  response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
  raise "capture request failed" unless response.status == 200
  view, article, block = SealedFormCost.capture
  raise "real form block missing" unless view && article && block
  # Remove the capture method. Replay calls the stock method directly, with
  # the original block's real view/output-buffer ownership still intact.
  view.method(:form_with).owner.send(:remove_method, :form_with)
  original = ->(model) { view.form_with(model: [article, model], class: "space-y-4", &block) }
  candidate = ->(model) { SealedFormCost.eligible?(view, article, model) ? SealedFormCost.render(view, article) : original.call(model) }
  # Raw byte equivalence is checked separately in isolated requests. Here real
  # entropy stays enabled; only token values differ, and each must be valid.
  normalize = ->(html) { html.gsub(/(<input type="hidden" name="authenticity_token" value=")[^"]+("[^>]*>)/, '\\1TOKEN\\2') }
  validate = ->(model) {
    left, right = original.call(model), candidate.call(model)
    raise "form bytes/safety/encoding differ" unless normalize.call(left) == normalize.call(right) &&
      left.encoding == right.encoding && left.html_safe? == right.html_safe?
    [left, right].each do |html|
      value = html[/name="authenticity_token" value="([^"]+)"/, 1]
      raise "live token missing" unless value
      controller = view.controller
      decoded = controller.send(:unmask_token, controller.send(:decode_csrf_token, value))
      action = html[/action="([^"]+)"/, 1]
      verb = html[/name="_method" value="([^"]+)"/, 1] || "post"
      expected = controller.send(:per_form_csrf_token, view.session, URI.parse(action).path, verb)
      raise "invalid live per-form token" unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded, expected)
    end
  }
  validate.call(Comment.new)
  changed = Comment.new(commenter: "<& Ω", body: "not blank")
  raise "nonblank input accepted" if SealedFormCost.eligible?(view, article, changed)
  validate.call(changed)
  changed = Comment.new
  changed.errors.add(:body, "not accepted")
  raise "errors accepted" if SealedFormCost.eligible?(view, article, changed)
  validate.call(changed)
  changed = Comment.new
  changed.define_singleton_method(:commenter) { "foreign holder" }
  raise "singleton model accepted" if SealedFormCost.eligible?(view, article, changed)
  validate.call(changed)
  changed = Comment.first!
  raise "persisted model accepted" if SealedFormCost.eligible?(view, article, changed)
  validate.call(changed)
  locales = I18n.available_locales
  I18n.available_locales = locales | [:fr]
  I18n.with_locale(:fr) do
    raise "locale accepted" if SealedFormCost.eligible?(view, article, Comment.new)
    validate.call(Comment.new)
  end
  I18n.available_locales = locales
  original_builder = view.instance_variable_get(:@tag_builder)
  view.instance_variable_set(:@tag_builder, ActionView::Helpers::TagHelper::TagBuilder.new(Object.new))
  raise "foreign builder context accepted" if SealedFormCost.eligible?(view, article, Comment.new)
  view.instance_variable_set(:@tag_builder, original_builder)
  I18n.with_locale(:en) do
    SealedFormCost::EPOCH[0] = 1
    raise "deopt accepted" if SealedFormCost.eligible?(view, article, Comment.new)
    validate.call(Comment.new)
  ensure
    SealedFormCost::EPOCH[0] = 0
  end
  table = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
  saved = table.dup
  table[:label], table["label"], table["textarea"] = "live-symbol-label", "wrong-string-key", "live-textarea"
  validate.call(Comment.new)
  table.replace(saved)
  raise "restoration failed" unless SealedFormCost.eligible?(view, article, Comment.new)
  arm = ENV.fetch("SEALED_FORM_WORKER")
  operation = case arm
  when "original" then -> { original.call(Comment.new) }
  when "checks" then -> { SealedFormCost.eligible?(view, article, Comment.new) }
  when "residue" then -> { Comment.new; SealedFormCost.render(view, article) }
  when "candidate" then -> { candidate.call(Comment.new) }
  else raise "unknown form arm"
  end
  200.times { operation.call }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ["form"])
  anchors = HeapWindows.run(windows) { |n, _| n.times { operation.call } }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: false,
    windows: windows, heap_anchors: anchors, ar_installed: 0,
    operations: {form: {invocations_per_iteration: 1, model_new_in_every_arm: true}},
    captured_block: block.source_location)}"
elsif $PROGRAM_NAME == __FILE__
  require_relative "../request_pairs"
  app, out = ARGV.map { File.expand_path(_1) }
  abort "usage: sealed_form.rb APP NEW_OUTPUT" unless app && out
  raise "new output required" if File.exist?(out)
  raise "interpreter only" unless ENV.fetch("BENCH_JIT", "0") == "0"
  raise "one to four workers" unless (1..4).cover?(Integer(ENV.fetch("BENCH_JOBS", "4")))
  FileUtils.mkdir_p(out, mode: 0o700)
  env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
    "LOWRAIL_STATS" => nil, "LOWRAIL_SHADOW" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0"}
  environments = %w[off_a off_b checks residue candidate].to_h do |arm|
    [arm, env.merge("SEALED_FORM_WORKER" => arm.start_with?("off") ? "original" : arm)]
  end
  root = File.expand_path("../..", __dir__)
  sources = [__FILE__, File.expand_path("blog_endpoint_check.rb", __dir__),
    File.expand_path("../callgrind.c", __dir__),
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
  raise "measured source changed" unless sources.all? { |file, sha| Digest::SHA256.file(File.join(root, file)).hexdigest == sha }
  raise "fixture changed" unless provenance.fetch(:fixture_sources).all? { |file, sha| Digest::SHA256.file(File.join(app, file)).hexdigest == sha }
  raise "lock changed" unless Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest == provenance.fetch(:lock_sha256)
  puts "SEALED_FORM_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
  exit(accepted ? 0 : 2)
end
