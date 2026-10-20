# frozen_string_literal: true

# Measurement specimens, NOT a pass, installer, or general Rails replacement.
# Only loaded by an initializer in a disposable copy of real-blog-r4.
module BlogLayers
  # L1 retains Rails' exception and logging handlers as live residue, but
  # flattens the successful route's other middleware and routing setup.
  class Envelope
    def initialize(original, endpoint: false)
      @original, @endpoint = original, endpoint
      chain = []
      node = original
      while node
        chain << node
        node = node.instance_variable_get(:@app)
      end
      @session = chain.find { _1.is_a?(ActionDispatch::Session::CookieStore) }
      @request_id = chain.find { _1.is_a?(ActionDispatch::RequestId) }
      @remote_ip = chain.find { _1.is_a?(ActionDispatch::RemoteIp) }
      @etag = chain.find { _1.is_a?(Rack::ETag) }
      @cache = chain.find { _1.class.name == "ActiveSupport::Cache::Strategy::LocalCache::Middleware" }.cache
      core = method(:dispatch)
      # Preserve original exception rendering and request event/tag lifetimes.
      [ActionDispatch::DebugExceptions, ActionDispatch::ShowExceptions, Rails::Rack::Logger].each do |klass|
        wrapper = chain.find { _1.is_a?(klass) }.dup
        wrapper.instance_variable_set(:@app, core)
        core = wrapper
      end
      @core = core
    end

    def eligible?(env)
      env["REQUEST_METHOD"] == "GET" && env["QUERY_STRING"].to_s.empty? &&
        (env["PATH_INFO"] == "/articles" || env["PATH_INFO"].match?(%r{\A/articles/[1-9][0-9]*\z})) &&
        !env["HTTP_IF_NONE_MATCH"] && !env["HTTP_IF_MODIFIED_SINCE"] &&
        !env["HTTP_USER_AGENT"] && !env["HTTP_ACCEPT"] &&
        !env["rack.response_finished"] && env["SCRIPT_NAME"].to_s.empty?
    end

    def call(env)
      return @original.call(env) unless eligible?(env)
      state = Rails.application.executor.run!(reset: true)
      @cache.new_local_cache
      start = Rack::Utils.clock_time
      request = ActionDispatch::Request.new(env)
      request.request_id = @request_id.send(:make_request_id, env["HTTP_X_REQUEST_ID"])
      request.remote_ip = ActionDispatch::RemoteIp::GetIp.new(request, @remote_ip.check_ip, @remote_ip.proxies)
      response = @core.call(env)
      response[1]["x-request-id"] = request.request_id
      response[1]["x-runtime"] ||= "%0.6f" % (Rack::Utils.clock_time - start)
      response[2] = Rack::BodyProxy.new(response[2]) do
        @cache.unset_local_cache
        state.complete!
      end
      returned = true
      response
    ensure
      if state && !returned
        @cache.unset_local_cache
        state.complete!
      end
    end

    def dispatch(env)
      request = ActionDispatch::Request.new(env)
      @session.send(:prepare_session, request)
      path = env.fetch("PATH_INFO")
      action = path == "/articles" ? "index" : "show"
      params = { controller: "articles", action: action }
      params[:id] = path.delete_prefix("/articles/") if action == "show"
      request.path_parameters = params
      env["action_dispatch.route_uri_pattern"] = action == "index" ? "/articles(.:format)" : "/articles/:id(.:format)"
      env["rack.tempfiles"] ||= []
      controller = ArticlesController.new
      response = ArticlesController.make_response!(request)
      result = if @endpoint
        Endpoint.call(controller, request, response, action)
      else
        controller.dispatch(action, request, response)
      end
      status, headers, body = result
      if (status == 200 || status == 201) && body.respond_to?(:to_ary) && !headers.key?("etag") && !headers.key?("last-modified")
        body = body.to_ary
        digest = @etag.send(:digest_body, body)
        headers["etag"] = %(W/"#{digest}") if digest
        result[2] = body
      end
      headers["cache-control"] ||= digest ? "max-age=0, private, must-revalidate" : "no-cache"
      @session.commit_session(request, Rack::Response::Raw.new(result[0], result[1]))
      if request.have_cookie_jar? && !request.cookie_jar.committed?
        result = Rack::Response[*result]
        request.cookie_jar.write(result)
        result = result.to_a
      end
      result[2] = Rack::BodyProxy.new(result[2]) { env["rack.tempfiles"]&.each(&:close!) }
      result
    end
  end

  # L2 has real AR relations/instances and real cryptography. Only dispatch,
  # templates and fixed helper interpretation disappear. No response cache.
  module Endpoint
    def self.call(controller, request, response, action)
      controller.set_request!(request)
      controller.set_response!(response)
      controller.action_name = action
      controller.send(:verify_authenticity_token)
      # The measured no-UA request passes allow_browser without parsing.
      ActionText::Content.with_renderer(controller) do
        Turbo.with_request_id(request.headers["X-Turbo-Request-Id"]) do
          view = controller.view_context
          view.lookup_context.formats = [:html]
          body = if action == "index"
            articles = Article.includes(:comments).order(created_at: :desc)
            index(view, articles)
          else
            article = Article.find(controller.params.expect(:id))
            show(view, article)
          end
          body = layout(view, body, action)
          response.set_header("content-type", "text/html; charset=utf-8")
          response.body = body
          # Rails' implicit-render response etag includes the importmap digest.
          controller.send(:verify_same_origin_request)
          request.commit_flash
          response.to_a
        end
      end
    end

    def self.h(value)
      ERB::Util.html_escape(value)
    end

    def self.destroy(view, label, path, klass, form_class = "button_to")
      token = view.send(:token_tag, nil, form_options: { action: path, method: "delete" })
      %(<form class="#{form_class}" method="post" action="#{h(path)}"><input type="hidden" name="_method" value="delete" /><button class="#{klass}" data-turbo-confirm="Are you sure?" type="submit">#{label}</button>#{token}</form>)
    end

    def self.index(view, articles)
      view.content_for(:title, "Articles")
      view.turbo_exempts_page_from_cache
      body = +"#{view.turbo_stream_from('articles')}\n\n\n\n<div class=\"w-full\">\n"
      notice = view.notice
      body << %(    <p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block" id="notice">#{h(notice)}</p>\n) if notice.present?
      body << %(
  <div class="flex justify-between items-center">
    <h1 class="font-bold text-4xl">Articles</h1>
    <a class="rounded-md px-3.5 py-2.5 bg-blue-600 hover:bg-blue-500 text-white block font-medium" href="/articles/new">New article</a>
  </div>

  <div id="articles" class="min-w-full divide-y divide-gray-200 space-y-5">
)
      if articles.any?
        body << "      "
        articles.each { body << article(view, _1) }
        body << "\n"
      else
        body << "      <p class=\"text-center my-10\">No articles found.</p>\n"
      end
      body << "  </div>\n</div>\n"
    end

    def self.article(view, article)
      path = "/articles/#{article.to_param}"
      <<~HTML
        <div id="#{view.dom_id(article)}" class="flex flex-col sm:flex-row justify-between items-center pb-5 sm:pb-0">
          <div class="p-4 border rounded mb-4 flex-grow">
            <h2 class="text-xl font-bold">
              <a class="text-blue-600 hover:underline" href="#{h(path)}">#{h(article.title)}</a>
              <span id="#{view.dom_id(article, :comments_count)}" class="text-gray-500 text-sm font-normal ml-2">
                (#{h(view.pluralize(article.comments.size, 'comment'))})
              </span>
            </h2>
            <p class="text-gray-700 mt-2">#{view.truncate(article.body, length: 100)}</p>
          </div>
          <div class="w-full sm:w-auto flex flex-col sm:flex-row space-x-2 space-y-2">
            <a class="w-full sm:w-auto text-center rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="#{h(path)}">Show</a>
            <a class="w-full sm:w-auto text-center rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="#{h(path)}/edit">Edit</a>
            #{destroy(view, 'Destroy', path, 'w-full sm:w-auto rounded-md px-3.5 py-2.5 text-white bg-red-600 hover:bg-red-500 font-medium cursor-pointer')}
          </div>
        </div>
      HTML
    end

    def self.show(view, article)
      view.content_for(:title, "Showing article")
      # provide in turbo_exempts_page_from_preview appends BEFORE block capture.
      view.turbo_exempts_page_from_preview
      view.content_for(:head, %(  \n  <meta name="article-id" content="#{article.id}">\n).html_safe)
      path = "/articles/#{article.to_param}"
      body = +"\n\n<div class=\"md:w-2/3 w-full\">\n"
      notice = view.notice
      body << %(    <p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block" id="notice">#{h(notice)}</p>\n) if notice.present?
      body << <<~HTML

          <h1 class="font-bold text-4xl">#{h(article.title)}</h1>

          <div class="my-4">
            <p class="text-gray-700">#{h(article.body)}</p>
          </div>

          <a class="w-full sm:w-auto text-center rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="#{h(path)}/edit">Edit this article</a>
          <a class="w-full sm:w-auto text-center mt-2 sm:mt-0 sm:ml-2 rounded-md px-3.5 py-2.5 bg-gray-100 hover:bg-gray-50 inline-block font-medium" href="/articles">Back to articles</a>
          #{destroy(view, 'Destroy this article', path, 'w-full rounded-md px-3.5 py-2.5 text-white bg-red-600 hover:bg-red-500 font-medium cursor-pointer', 'sm:inline-block mt-2 sm:mt-0 sm:ml-2')}
        </div>

        <hr class="my-8">

        <h2 class="text-xl font-bold mb-4">Comments</h2>

        #{view.turbo_stream_from("article_#{article.id}_comments")}

        <div id="comments" class="space-y-4 mb-8">
      HTML
      body << "  "
      article.comments.each do |comment|
        comment_path = "/articles/#{comment.article.to_param}/comments/#{comment.to_param}"
        body << <<~HTML
          <div id="#{view.dom_id(comment)}" class="p-4 bg-gray-50 rounded">
            <p class="font-semibold">#{h(comment.commenter)}</p>
            <p class="text-gray-700">#{h(comment.body)}</p>
            #{destroy(view, 'Delete', comment_path, 'text-red-600 text-sm mt-2')}
          </div>
        HTML
      end
      token = view.send(:token_tag, nil, form_options: { action: "#{path}/comments", method: "post" })
      body << <<~HTML.chomp

        </div>

        <h3 class="text-lg font-semibold mb-2">Add a Comment</h3>

        <form class="space-y-4" action="#{h(path)}/comments" accept-charset="UTF-8" method="post">#{token}
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
        </form>
      HTML
    end

    def self.layout(view, body, action)
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <title>#{view.content_for(:title)}</title>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <meta name="apple-mobile-web-app-capable" content="yes">
            <meta name="application-name" content="Real Blog R4">
            <meta name="mobile-web-app-capable" content="yes">
            #{view.csrf_meta_tags}
            #{view.csp_meta_tag}

            #{view.content_for(:head)}


            <link rel="icon" href="/icon.png" type="image/png">
            <link rel="icon" href="/icon.svg" type="image/svg+xml">
            <link rel="apple-touch-icon" href="/icon.png">

            #{view.stylesheet_link_tag(:app, 'data-turbo-track': 'reload')}
            #{view.javascript_importmap_tags}
          </head>

          <body>
            <main class="container mx-auto mt-28 px-5 flex flex-col">
              #{body}
            </main>
          </body>
        </html>
      HTML
    end
  end

  module Components
    # Avoid internal reader dispatch, duplicate misses and two extra fetch
    # blocks on hits. Real Attribute objects, types and dirty tracking remain.
    module Attributes
      def fetch_value(name, &block)
        return @attributes[name].value(&block) if @attributes[name]
        return @casted_values[name] if @casted_values.key?(name)
        if @values.key?(name)
          type = @additional_types.fetch(name, @types[name])
          @casted_values[name] = type.deserialize(@values[name])
        else
          super
        end
      end
    end

    # Precompile the finite format at boot, not path values. Preserve parameter
    # evaluation BEFORE children, including missing-parameter short circuit.
    def self.formats
      ObjectSpace.each_object(ActionDispatch::Journey::Format) do |format|
        parts = format.instance_variable_get(:@parts)
        parameters = format.instance_variable_get(:@parameters)
        children = format.instance_variable_get(:@children)
        next unless parts.all? { _1.is_a?(String) || _1.is_a?(ActionDispatch::Journey::Format) || _1.is_a?(ActionDispatch::Journey::Format::Parameter) }
        source = +"def evaluate(hash);"
        parameters.each do |i|
          source << "v#{i}=hash[@parts[#{i}].name];return '' if v#{i}.nil?;v#{i}=@parts[#{i}].escape(v#{i});"
        end
        children.each { |i| source << "v#{i}=@parts[#{i}].evaluate(hash);" }
        source << "[#{parts.each_index.map { |i| (parameters + children).include?(i) ? "v#{i}" : "@parts[#{i}]" }.join(',')}].join;end"
        format.singleton_class.class_eval(source, __FILE__, __LINE__)
      end
    end

    # No subscriber-result caching: Rails' live fanout is still consulted.
    # Only use the already-empty array fast path before per-listener silence.
    module Fanout
      def listening?(name)
        listeners = all_listeners_for(name)
        return false if listeners.empty?
        listeners.any? { !_1.silenced?(name) }
      end
    end

    def self.install
      ActiveModel::LazyAttributeSet.prepend(Attributes)
      ActiveSupport::Notifications::Fanout.prepend(Fanout)
      formats
    end
  end

  def self.install(layer)
    raise "only Rails 8.1.4" unless Rails.version == "8.1.4"
    raise "only real-blog-r4" unless Rails.application.class.name == "RealBlogR4::Application"
    Rails.application.eager_load!
    original = Rails.application.app
    case layer
    when "L1", "L2"
      Rails.application.instance_variable_set(:@app, Envelope.new(original, endpoint: layer == "L2"))
    when "L3"
      Components.install
    else
      raise "unknown experimental layer #{layer}"
    end
  end
end
