# frozen_string_literal: true

require_relative "sealed"

module Lowrail
  module FormScaffold
    PASS = "sealed/form_scaffold"

    # A separate helper variant, not an if/else spliced into the template.
    # Ruby has already evaluated the original model/options/block once. The
    # original form_with remains immediately below this method as fallback.
    module Variant
      def form_with(model: false, scope: nil, url: nil, format: nil, **options, &block)
        if ::Lowrail::FormScaffold.valid?(self, model, scope, url, format, options, block)
          ::Lowrail::FormScaffold.render(self, model.first)
        else
          super
        end
      end
    end

    class << self
      attr_reader :refusal, :input_refusal

      def install(units)
        @unit = units.fetch(0)
        @active = false
      end

      def decline(reason)
        @active = false
        @refusal = reason
        Lowrail.debug("sealed form refused: #{reason}")
        false
      end

      def activate
        return decline("production_only; this test runs unoptimized") unless ENV["RAILS_ENV"] == "production"
        require_relative "form_scaffold_inventory"
        # Keep the build audit and candidate guards, but never reproduce its
        # controller/view/I18n/ERB effects in a real application. No variant is
        # installed, so an uninstrumented original form is intentionally 0/0.
        decline(FormScaffoldInventory.check(runtime: true))
      rescue StandardError, ScriptError => error
        decline("#{error.class}: #{error.message.lines.first&.strip}")
      end

      def valid?(view, model, scope, url, format, options, block)
        return count(false, "foreign Ractor") unless Ractor.current.equal?(Ractor.main)
        return count(false, "activation refused") unless @active
        return count(false, "seal epoch changed") unless @epoch[0].zero?
        return count(false, "unknown form site/options") unless scope.nil? && url.nil? && format.nil? &&
          @holder.call(model).equal?(Array) && model.size == 2 && options == {class: "space-y-4"} &&
          block && block.source_location == @site.fetch("source_location")
        article, child = model
        return count(false, "unknown view/model holder") unless @holder.call(view).equal?(@view_class) &&
          @holder.call(article).equal?(@article_class) && @holder.call(child).equal?(@model_class)
        form_class = @ivars.bind_call(view, :@_default_form_builder)
        return count(false, "unknown form builder") unless form_class.nil? || form_class.equal?(@form_class)
        # Acquire the real builder before checking the values any live factory
        # could affect. Never create its singleton class or inspect only public
        # singleton methods. Foreign/reinitialized contexts stay original.
        builder = view.send(:tag_builder)
        return count(false, "unknown builder/context") unless @holder.call(builder).equal?(@builder_class) &&
          @ivars.bind_call(builder, :@view_context).equal?(view)
        return count(false, "unknown output buffer") unless @holder.call(view.output_buffer).equal?(@buffer_class)
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
