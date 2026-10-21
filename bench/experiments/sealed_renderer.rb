# frozen_string_literal: true

# Finite, handwritten real-blog-r4 specimen. NEVER loaded by Lowrail runtime.
# Installation/materialization happens before the experimental seal. No method
# or subscriber is installed during requests. No models/results/tokens cached.
require_relative "blog_layers"

module SealedRenderer
  STAGES = %w[restored form filters tokens collection].freeze
  AFTER_CALLBACKS = ActionController::Rendering.instance_method(:process_action)
  class << self
    attr_accessor :hits, :stage, :comment_template
  end
  self.hits = 0

  def self.eligible?(request)
    request.get? && %w[/articles/1 /articles/2 /articles/3].include?(request.path) &&
      request.query_string.empty? && request.script_name.empty? &&
      !request.get_header("HTTP_ACCEPT") && !request.get_header("HTTP_USER_AGENT") &&
      !request.get_header("HTTP_IF_NONE_MATCH") && !request.get_header("HTTP_IF_MODIFIED_SINCE")
  end

  class Envelope < BlogLayers::Envelope
    def eligible?(env)
      super && %w[/articles/1 /articles/2 /articles/3].include?(env["PATH_INFO"])
    end
  end

  module Filters
    private
    def process_action(...)
      return super unless SealedRenderer.eligible?(request)
      # Exact stock chain: GET's CSRF callback, ActionText/Turbo around bodies,
      # no-UA allow_browser, set_article, and same-origin after callback.
      verify_authenticity_token
      result = ActionText::Content.with_renderer(self) do
        turbo_tracking_request_id do
          set_article
          # Skip ONLY the callback interpreter, not action/instrumentation.
          AFTER_CALLBACKS.bind_call(self, ...)
        end
      end
      verify_same_origin_request
      result
    end
  end

  module Tokens
    private
    def token_tag(token = nil, form_options: {})
      return super unless token.nil? && SealedRenderer.eligible?(request)
      return "" unless protect_against_forgery?
      value = form_authenticity_token(form_options: form_options.merge(authenticity_token: nil))
      autocomplete = ActionView::Base.remove_hidden_field_autocomplete ? "" : ' autocomplete="off"'
      %(<input type="hidden" name="#{ERB::Util.html_escape(request_forgery_protection_token.to_s)}" value="#{ERB::Util.html_escape(value)}"#{autocomplete} />).html_safe
    end
  end

  def self.h(value) = ERB::Util.html_escape(value)

  def self.collection(view, records)
    values = records.to_a
    template = comment_template
    ActiveSupport::Notifications.instrument("render_collection.action_view",
      identifier: values.empty? ? nil : template.identifier, layout: nil, count: values.length) do
      locals = {}
      iteration = ActionView::PartialIteration.new(values.length)
      values.map do |record|
        locals[:comment] = record
        locals[:comment_counter] = iteration.index
        locals[:comment_iteration] = iteration
        body = template.render(view, locals, implicit_locals: %i[comment_counter comment_iteration])
        iteration.iterate!
        body
      end.join.html_safe
    end
  end

  def self.destroy(view, label, path, klass, form_class = "button_to")
    BlogLayers::Endpoint.destroy(view, label, path, klass, form_class)
  end

  def self.comment(view, comment)
    out = view.output_buffer
    out.safe_append = %(<div id="#{view.dom_id(comment)}" class="p-4 bg-gray-50 rounded">\n  <p class="font-semibold">#{h(comment.commenter)}</p>\n  <p class="text-gray-700">#{h(comment.body)}</p>\n  )
    path = view.article_comment_path(comment.article, comment)
    out.safe_append = destroy(view, "Delete", path, "text-red-600 text-sm mt-2")
    out.safe_append = "\n</div>\n"
    out
  end

  def self.show(view, article)
    self.hits += 1
    out = view.output_buffer
    view.content_for(:title, "Showing article")
    view.content_for(:head) do
      view.turbo_exempts_page_from_preview
      %(  \n  <meta name="article-id" content="#{h(article.id)}">\n).html_safe
    end
    out.safe_append = "\n\n<div class=\"md:w-2/3 w-full\">\n"
    if view.notice.present?
      out.safe_append = %(    <p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block" id="notice">#{h(view.notice)}</p>\n)
    end
    out.safe_append = %(
  <h1 class="font-bold text-4xl">#{h(article.title)}</h1>

  <div class="my-4">
    <p class="text-gray-700">#{h(article.body)}</p>
  </div>

  <a class="w-full sm:w-auto text-center rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="#{h(view.edit_article_path(article))}">Edit this article</a>
  <a class="w-full sm:w-auto text-center mt-2 sm:mt-0 sm:ml-2 rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="#{h(view.articles_path)}">Back to articles</a>
  )
    out.safe_append = destroy(view, "Destroy this article", view.article_path(article),
      "w-full rounded-md px-3.5 py-2.5 text-white bg-red-600 hover:bg-red-500 font-medium cursor-pointer",
      "sm:inline-block mt-2 sm:mt-0 sm:ml-2")
    out.safe_append = %(\n</div>\n\n<hr class="my-8">\n\n<h2 class="text-xl font-bold mb-4">Comments</h2>\n\n#{view.turbo_stream_from("article_#{article.id}_comments")}\n\n<div id="comments" class="space-y-4 mb-8">\n  )
    # Real collection renderer: preload timing, real objects/associations,
    # locals/iteration, template stack, buffers and nested events stay Rails'.
    out.append = stage == "collection" ? collection(view, article.comments) : view.render(article.comments)
    out.safe_append = "\n</div>\n\n<h3 class=\"text-lg font-semibold mb-2\">Add a Comment</h3>\n\n"
    model = Comment.new
    out.append = if stage == "restored"
      view.form_with(model: [article, model], class: "space-y-4") do |form|
        %(\n  <div>\n    #{form.label(:commenter, class: "block font-medium")}\n    #{form.text_field(:commenter, class: "block w-full border rounded p-2")}\n  </div>\n  <div>\n    #{form.label(:body, class: "block font-medium")}\n    #{form.text_area(:body, rows: 3, class: "block w-full border rounded p-2")}\n  </div>\n  #{form.submit("Add Comment", class: "bg-blue-600 text-white px-4 py-2 rounded")}\n).html_safe
      end
    else
      # Stock blank Comment: schema has nil field defaults, no initialize
      # callbacks, no errors. Keep construction; fold only its form scaffold.
      raise "blank form model contract" unless model.commenter.nil? && model.body.nil? && model.errors.empty? && !model.persisted?
      path = view.article_comments_path(article)
      token = view.send(:token_tag, nil, form_options: { action: path, method: "post" })
      %(<form class="space-y-4" action="#{h(path)}" accept-charset="UTF-8" method="post">#{token}
  <div>
    <label class="block font-medium" for="comment_commenter">Commenter</label>
    <input class="block w-full border rounded p-2" type="text" name="comment[commenter]" id="comment_commenter" />
  </div>
  <div>
    <label class="block font-medium" for="comment_body">Body</label>
    <textarea rows="3" class="block w-full border rounded p-2" name="comment[body]" id="comment_body">
</textarea>
  </div>
  <input type="submit" name="commit" value="Add Comment" class="bg-blue-600 text-white px-4 py-2 rounded" data-disable-with="Add Comment" />
</form>).html_safe
    end
    out
  end

  def self.install(stage)
    raise "unknown stage" unless STAGES.include?(stage)
    raise "only selected blog / Rails 8.1.4" unless Rails.version == "8.1.4" && Rails.root.realpath.to_s == File.realpath(Dir.pwd)
    self.stage = stage
    Rails.application.eager_load!
    require "rack/mock"
    client = Rack::MockRequest.new(Rails.application)
    %w[/articles/1 /articles/2 /articles/3].each do |path|
      raise "materialization failed" unless client.get(path, "HTTP_HOST" => "localhost", "HTTPS" => "on").status == 200
    end
    controller = ArticlesController.new
    view = controller.view_context
    lookup = view.lookup_context
    lookup.formats = [:html]
    templates = {
      show: lookup.find_template("articles/show", [], false, []),
      comment: lookup.find_template("comments/comment", [], true, %i[comment comment_counter comment_iteration]),
      layout: lookup.find_template("layouts/application", [], false, [])
    }
    self.comment_template = templates.fetch(:comment)
    templates.each do |kind, template|
      template.send(:compile!, view)
      container = view.compiled_method_container
      original = container.instance_method(template.method_name)
      container.define_method(template.method_name) do |locals, buffer, &block|
        unless SealedRenderer.eligible?(request)
          next original.bind_call(self, locals, buffer, &block)
        end
        @virtual_path = template.virtual_path
        case kind
        when :show then SealedRenderer.show(self, @article)
        when :comment then SealedRenderer.comment(self, locals.fetch(:comment))
        when :layout
          # Keep every security/asset helper and the actual view_flow slot.
          buffer.safe_append = BlogLayers::Endpoint.layout(self, _layout_for, "show")
          buffer
        end
      end
    end
    # Insert at Callbacks' position in the process_action ancestor chain.
    AbstractController::Callbacks.prepend(Filters) if %w[filters tokens collection].include?(stage)
    ArticlesController.view_context_class.prepend(Tokens) if %w[tokens collection].include?(stage)
    Rails.application.instance_variable_set(:@app, Envelope.new(Rails.application.app))
    self.hits = 0
  end
end
