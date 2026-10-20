# frozen_string_literal: true

require_relative "blog_layers"

# L2 with the controller/render notification boundaries preserved. Payloads
# remain live; no subscriber checks or cached notification results are used.
module BlogEventful
  def self.template(action)
    @templates.fetch(action).dup
  end

  def self.collection(records, partial)
    metadata = template(partial)
    records.define_singleton_method(:each) do |&block|
      # Rails evaluates CollectionIterator#length (loading/preloading) before
      # entering the render_collection event. Preserve that SQL nesting too.
      values = to_a
      ActiveSupport::Notifications.instrument("render_collection.action_view",
        identifier: values.empty? ? nil : metadata[:identifier], layout: nil, count: values.length) do
        values.each do |record|
          ActiveSupport::Notifications.instrument("!render_template.action_view", metadata.dup) { block.call(record) }
        end
      end
    end
    records
  end

  def self.render(controller, view, records, action)
    metadata = template(action)
    layout = template("layout")
    body = ActiveSupport::Notifications.instrument("render_layout.action_view", identifier: layout[:identifier]) do
      content = ActiveSupport::Notifications.instrument("render_template.action_view",
        identifier: metadata[:identifier], layout: layout[:virtual_path], locals: {}) do
        ActiveSupport::Notifications.instrument("!render_template.action_view", metadata) do
          if action == "index"
            BlogLayers::Endpoint.index(view, collection(records, "article"))
          else
            collection(records.comments, "comment")
            BlogLayers::Endpoint.show(view, records)
          end
        end
      end
      # Preserve view_flow's layout slot as the original renderer does.
      view.view_flow.set(:layout, content)
      ActiveSupport::Notifications.instrument("!render_template.action_view", layout) do
        BlogLayers::Endpoint.layout(view, content, action)
      end
    end
    controller.response.set_header("content-type", "text/html; charset=utf-8")
    controller.response_body = body
  end

  module Endpoint
    def call(controller, request, response, action)
      controller.set_request!(request)
      controller.set_response!(response)
      controller.action_name = action
      ActiveRecord::RuntimeRegistry.reset
      ActiveSupport::ExecutionContext[:controller] = controller
      payload = { controller: controller.class.name, action: controller.action_name,
        request: request, params: request.filtered_parameters, headers: request.headers,
        format: request.format.ref, method: request.request_method, path: request.filtered_path }
      ActiveSupport::Notifications.instrument("start_processing.action_controller", payload)
      ActiveSupport::Notifications.instrument("process_action.action_controller", payload) do |event|
        controller.send(:verify_authenticity_token)
        ActionText::Content.with_renderer(controller) do
          Turbo.with_request_id(request.headers["X-Turbo-Request-Id"]) do
            records = if action == "index"
              Article.includes(:comments).order(created_at: :desc)
            else
              Article.find(controller.params.expect(:id))
            end
            view = controller.view_context
            view.lookup_context.formats = [:html]
            controller.view_runtime = controller.send(:cleanup_view_runtime) do
              ActiveSupport::Benchmark.realtime(:float_millisecond) do
                BlogEventful.render(controller, view, records, action)
              end
            end
          end
        end
        controller.send(:verify_same_origin_request)
        event[:response] = response
        event[:status] = response.status
      rescue => error
        event[:status] = ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name)
        raise
      ensure
        controller.send(:append_info_to_payload, event)
      end
      request.commit_flash
      response.to_a
    end
  end

  def self.install
    @templates = %w[index show article comment layout].to_h do |action|
      name = { "article" => "articles/_article", "comment" => "comments/_comment",
        "layout" => "layouts/application" }.fetch(action, "articles/#{action}")
      [action, { virtual_path: name, identifier: Rails.root.join("app/views/#{name}.html.erb").to_s }]
    end
    BlogLayers.install("L2")
    BlogLayers::Endpoint.singleton_class.prepend(Endpoint)
  end
end
