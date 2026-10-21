# frozen_string_literal: true

require_relative "sealed"

module Lowrail
  module FormScaffold
    PASS = "sealed/form_scaffold"
    BLOCK_SOURCE = Proc.instance_method(:source_location)

    # The same observer is installed even LOWRAIL=0. The first natural form
    # runs wholly original; only later entries may see a published admission.
    module Variant
      def form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
        admitted = ::Lowrail::FormScaffold.admitted?
        if admitted && ::Lowrail::FormScaffold.valid?(self, model, scope, url, format, options, block)
          ::Lowrail::FormScaffold.render(self, model.first)
        else
          result = super
          ::Lowrail::FormScaffold.observe(self, block) unless admitted
          result
        end
      end
    end

    class << self
      attr_reader :refusal, :input_refusal, :admission

      def observe_forms
        require_relative "load_hooks"
        LoadHooks.active_support do
          ::ActiveSupport.on_load(:action_view) do
            # Both arms load identical Lowrail seam files after Bundler, not
            # default gems during RUBYOPT's pre-Bundler startup.
            require_relative "form_scaffold_inventory"
            require_relative "form_scaffold_admission"
            helper = Lowrail.loaded_constant("ActionView::Helpers::FormHelper")
            helper.prepend(Variant) if helper && !(helper < Variant)
          end
        end
      end

      def install(units)
        if @unit
          @reinstalled = true
          return decline("form admission already configured; restart before another setup")
        end
        @unit = units.fetch(0)
        @data = @unit.fetch("data")
        @active = false
        @attempted = false
        @lock ||= Mutex.new
        @admission = {state: "pending", attempts: 0}.freeze
      end

      def decline(reason)
        @active = false
        attempts = @attempted ? 1 : 0
        reason = "#{reason}; terminal admission, attempts=#{attempts}/1"
        @refusal = reason
        @pending = false
        @admission = {state: "refused", attempts: attempts, reason: reason}.freeze
        Lowrail.debug("sealed form refused: #{reason}")
        false
      end

      def activate
        return false if @reinstalled
        return decline("production_only; this test runs unoptimized") unless ENV["RAILS_ENV"] == "production" ||
          (defined?(TestCertificate) && TestCertificate.active?)
        return decline("old effectful form certificate; rebuild for passive admission; keep original") unless @data.dig("passive", "version") == 1
        return decline("missing actual-holder primitive; keep original") unless Lowrail.loaded_constant("Lowrail::Native")
        @site = @data.fetch("site")
        @epoch = defined?(Lowrail::Seal) ? Lowrail::Seal::EPOCH : Sealed::EPOCH
        @pending = true
        @refusal = "pending first natural certified form; this request runs original"
      rescue StandardError, ScriptError => error
        decline("#{error.class}: #{error.message.lines.first&.strip}")
      end

      def admitted? = @active

      def observe(view, block)
        return unless @pending && !@attempted && Ractor.current.equal?(Ractor.main) &&
          block && BLOCK_SOURCE.bind_call(block) == @site.fetch("source_location")
        return unless @lock.try_lock
        begin
          return if @attempted || !@pending
          @attempted = true
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = FormScaffoldAdmission.check(@data, view, block)
          return decline(result) if String === result
          return decline("seal epoch changed during admission; keep original") unless @epoch[0].zero?
          # No app/view/model/template instance escapes the witness. Publish
          # only after every check; concurrent prepublication entries already
          # chose original, and failed attempts leave no half-active state.
          result.each { |key, value| instance_variable_set(:"@#{key}", value) }
          @ivars = FormScaffoldAdmission::IVAR
          @pending = false
          @refusal = nil
          @admission = {state: "active", attempts: 1,
            witness_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started}.freeze
          @active = true
        rescue StandardError, ScriptError => error
          decline("passive admission: #{error.class}: #{error.message.lines.first&.strip}; keep original")
        ensure
          @lock.unlock
        end
      end

      def valid?(view, model, scope, url, format, options, block)
        return count(false, "foreign Ractor") unless Ractor.current.equal?(Ractor.main)
        return count(false, "activation refused") unless @active
        return count(false, "seal epoch changed") unless @epoch[0].zero?
        return count(false, "unknown form site/options") unless scope.nil? && url.nil? && format.nil? &&
          @holder.call(model, Array) && model.size == 2 && options == {class: "space-y-4"} &&
          block && @holder.call(block, Proc) && BLOCK_SOURCE.bind_call(block) == @site.fetch("source_location")
        article, child = model
        return count(false, "unknown view/model holder") unless @holder.call(view, @view_class) &&
          @holder.call(article, @article_class) && @holder.call(child, @model_class)
        form_class = @ivars.bind_call(view, :@_default_form_builder)
        return count(false, "unknown form builder") unless form_class.nil? || form_class.equal?(@form_class)
        # Acquire the real builder before checking the values any live factory
        # could affect. Never create its singleton class or inspect only public
        # singleton methods. Foreign/reinitialized contexts stay original.
        builder = view.send(:tag_builder)
        return count(false, "unknown builder/context") unless @holder.call(builder, @builder_class) &&
          @ivars.bind_call(builder, :@view_context).equal?(view)
        return count(false, "unknown output buffer") unless @holder.call(view.output_buffer, @buffer_class)
        return count(false, "non-English locale") unless I18n.locale == :en
        return count(false, "nonblank/error/persisted form model") unless article.persisted? && !child.persisted? &&
          child.commenter.nil? && child.body.nil? && child.errors.empty?
        count(true)
      end

      def count(ok, reason = nil)
        @input_refusal = reason unless ok
        Stats.count(@unit.fetch("id"), ok) if defined?(Stats) && Stats.enabled?
        ok
      end

      def render(view, article)
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
    end
  end

  module Passes
    FormScaffold = Lowrail::FormScaffold
  end
end
