# frozen_string_literal: true

# Cumulative, measurement-only removals. Not an installer/certificate for apps.
require_relative "blog_layers"

module BlogAblation
  STAGES = %w[L1 filters events templates endpoint_comment L2 L2_events].freeze

  def self.install(stage)
    raise "unknown ablation #{stage}" unless STAGES.include?(stage)
    if stage == "L2_events"
      require_relative "blog_eventful"
      return BlogEventful.install
    end
    BlogLayers.install(%w[endpoint_comment L2].include?(stage) ? "L2" : "L1")
    return if %w[L1 L2].include?(stage)
    if stage == "endpoint_comment"
      # The original show template constructs this blank form model. Nothing
      # about relation building, preloading or row instantiation is removed.
      BlogLayers::Endpoint.singleton_class.prepend(Module.new do
        def show(view, article)
          Comment.new
          super
        end
      end)
      return
    end

    AbstractController::Callbacks.module_eval do
      def process_action(...)
        verify_authenticity_token
        result = ActionText::Content.with_renderer(self) do
          turbo_tracking_request_id do
            # No User-Agent is part of this experiment's entry shape, so the
            # allow_browser callback immediately passes. Keep show's query.
            set_article if action_name == "show"
            super
          end
        end
        verify_same_origin_request
        result
      end
      private :process_action
    end
    return if stage == "filters"

    # Preserve the controller execution context: downstream code can read it.
    ActionController::Instrumentation.module_eval do
      def process_action(...)
        ActiveSupport::ExecutionContext[:controller] = self
        super
      end
      private :process_action
      remove_method :render
    end
    # Copy the original rendering algorithms, removing ONLY notifications and
    # their payloads. These definitions apply to warmed templates, not compile.
    ActionView::Template.class_eval do
      def instrument_render_template
        yield
      end
      private :instrument_render_template
    end
    ActionView::TemplateRenderer.class_eval do
      def render_template(view, template, layout_name, locals)
        render_with_layout(view, template, layout_name, locals) do
          template.render(view, locals) { |*name| view._layout_for(*name) }
        end
      end

      def render_with_layout(view, template, path, locals)
        layout = path && find_layout(path, locals.keys, [formats.first])
        body = if layout
          view.view_flow.set(:layout, yield(layout))
          layout.render(view, locals) { |*name| view._layout_for(*name) }
        else
          yield
        end
        build_rendered_template(body, template)
      end
      private :render_template, :render_with_layout
    end
    ActionView::PartialRenderer.class_eval do
      def render_partial_template(view, locals, template, layout, block)
        content = template.render(view, locals, add_to_stack: !block) do |*name|
          view._layout_for(*name, &block)
        end
        content = layout.render(view, locals) { content } if layout
        build_rendered_template(content, template)
      end
      private :render_partial_template
    end
    ActionView::CollectionRenderer.class_eval do
      def render_collection(collection, view, path, template, layout, block)
        spacer = if @options.key?(:spacer_template)
          spacer_template = find_template(@options[:spacer_template], @locals.keys)
          build_rendered_template(spacer_template.render(view, @locals), spacer_template)
        else
          ActionView::AbstractRenderer::RenderedTemplate::EMPTY_SPACER
        end
        collection_body = if template
          cache_collection_render({}, view, template, collection) do |filtered_collection|
            collection_with_template(view, template, layout, filtered_collection)
          end
        else
          collection_with_template(view, nil, layout, collection)
        end
        return ActionView::AbstractRenderer::RenderedCollection.empty(@lookup_context.formats.first) if collection_body.empty?
        build_rendered_collection(collection_body, spacer)
      end
      private :render_collection
    end
    return if stage == "events"

    ArticlesController.class_eval do
      def default_render
        view = view_context
        view.lookup_context.formats = [:html]
        body = if action_name == "index"
          BlogLayers::Endpoint.index(view, @articles)
        else
          Comment.new
          BlogLayers::Endpoint.show(view, @article)
        end
        response.set_header("content-type", "text/html; charset=utf-8")
        self.response_body = BlogLayers::Endpoint.layout(view, body, action_name)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # Reuse the exact paired body/all-header/ordered-SQL comparator, without
  # editing its frozen study source. Only its installer is substituted.
  module AblationCheckerInstall
    def install(stage)
      return super unless BlogAblation::STAGES.include?(stage) && stage != "L1" && stage != "L2"
      BlogAblation.install(stage)
    end
  end
  BlogLayers.singleton_class.prepend(AblationCheckerInstall)
  load File.join(__dir__, "blog_check.rb")
end
