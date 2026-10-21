# frozen_string_literal: true

module BlogProduction
  # Ports source assertions, not Rails' test environment. Each case gets a
  # fresh production process and the same closed four-database snapshot.
  module Breadth
    BODY = "A sufficiently long body for validation."
    TITLE = "Getting Started with Rails"
    CASES = {
      "article_new" => ["ArticlesControllerTest", "should get new"],
      "article_create" => ["ArticlesControllerTest", "should create article"],
      "article_create_invalid" => ["ArticlesControllerTest", "should not create article with invalid params"],
      "article_edit" => ["ArticlesControllerTest", "should get edit"],
      "article_update" => ["ArticlesControllerTest", "should update article"],
      "article_update_invalid" => ["ArticlesControllerTest", "should not update article with invalid params"],
      "article_destroy" => ["ArticlesControllerTest", "should destroy article"],
      "comment_create" => ["CommentsControllerTest", "should create comment"],
      "comment_create_invalid" => ["CommentsControllerTest", "should not create comment with invalid params"],
      "comment_destroy" => ["CommentsControllerTest", "should destroy comment"],
      "article_fixture" => ["ArticleTest", "creates an article with valid attributes"],
      "article_title" => ["ArticleTest", "validates title presence"],
      "article_body" => ["ArticleTest", "validates body minimum length"],
      "article_dependents" => ["ArticleTest", "destroys comments when article is destroyed"],
      "comment_fixture" => ["CommentTest", "creates a comment on an article"],
      "comment_association" => ["CommentTest", "belongs to article association"],
      "comment_commenter" => ["CommentTest", "requires commenter"],
      "comment_body" => ["CommentTest", "requires body"],
      "comment_article" => ["CommentTest", "requires valid article"],
      "system_article" => ["ArticlesSystemTest", "full article lifecycle"],
      "system_comments" => ["ArticlesSystemTest", "article with comments"],
      "csrf_missing" => ["BlogProductionControl", "rejects missing CSRF"],
      "csrf_invalid" => ["BlogProductionControl", "rejects invalid CSRF"]
    }.map do |key, (klass, name)|
      {"key" => key, "id" => "#{klass}#test_#{name.tr(' ', '_')}",
        "boundary" => klass == "ArticlesSystemTest" ? "server_workflow_only" : "production_request_or_model"}
    end.freeze

    class Driver
      attr_reader :steps, :checks, :response

      def initialize(id, app_events)
        @id, @app_events = id, app_events
        @cookies, @steps, @checks = {}, [], []
      end

      def check(name, passed)
        checks << {"name" => name, "passed" => !!passed}
      end

      def document
        require "nokogiri"
        Nokogiri::HTML(response.body)
      end

      def request(method, path, params: nil)
        Entropy.expect_request!
        first_event = @app_events.events.size
        options = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ORIGIN" => "https://localhost",
          "HTTP_ACCEPT" => "text/html", "HTTP_COOKIE" => @cookies.map { |k, v| "#{k}=#{v}" }.join("; "),
          "HTTP_X_REQUEST_ID" => "#{@id}/#{steps.size}"}
        options.merge!("CONTENT_TYPE" => "application/x-www-form-urlencoded", input: Rack::Utils.build_nested_query(params)) if params
        @response = Rack::MockRequest.new(Rails.application).request(method, path, options)
        Array(response.headers["set-cookie"]).flat_map { _1.split("\n") }.each do |cookie|
          name, val = cookie.split(";", 2).first.split("=", 2)
          @cookies[name] = val
        end
        action = @app_events.events.drop(first_event).reverse.find { _1["name"] == "process_action.action_controller" && _1["phase"] == "finish" }
        @flash = action&.fetch("payload")&.fetch("flash", nil)
        steps << {"kind" => "request", "method" => method, "path" => path, "params" => BlogProduction.value(params),
          "response" => {"status" => response.status, "headers" => BlogProduction.value(response.headers.to_h),
            "body" => BlogProduction.value(response.body)}, "flash" => @flash, "effects" => BlogProduction.effects}
        response
      end

      def get(path) = request("GET", path)

      def submit(action, fields = {})
        form = document.css("form").find { _1["action"] == action }
        raise "missing form for #{action}" unless form
        hidden = form.css('input[type="hidden"][name]').to_h { [_1["name"], _1["value"].to_s] }
        raise "missing natural CSRF input" unless hidden["authenticity_token"]&.length&.positive?
        request("POST", action, params: hidden.merge(fields))
      end

      def redirect(path, status, flash)
        check("redirect #{status} #{path}", response.status == status && response.headers["location"] == "https://localhost#{path}")
        check("flash #{flash}", @flash && @flash.values.include?(BlogProduction.value(flash)))
        get(path)
        check("redirect target succeeds", response.status == 200)
        check("flash survives redirect", @flash && @flash.values.include?(BlogProduction.value(flash)))
      end

      def notice_consumed(path)
        get(path)
        check("flash consumed after one read", @flash == {})
        check("notice absent after one read", document.at_css("#notice").nil?)
      end

      def observe(name)
        result = yield
        steps << {"kind" => "model", "name" => name, "result" => BlogProduction.value(result), "effects" => BlogProduction.effects}
        result
      end

      def run(key)
        case key
        when "article_new", "article_edit"
          get(key == "article_new" ? "/articles/new" : "/articles/1/edit")
          check("form succeeds", response.status == 200 && document.at_css('input[name="article[title]"]') && document.at_css('textarea[name="article[body]"]'))
        when "article_create", "article_create_invalid"
          before = Article.count
          get("/articles/new")
          valid = key == "article_create"
          submit("/articles", "article" => {"title" => valid ? "New Title" : "", "body" => valid ? BODY : ""})
          check("article count", Article.count == before + (valid ? 1 : 0))
          if valid
            check("created title", Article.find(3).title == "New Title")
            redirect("/articles/3", 302, "Article was successfully created.")
            check("created page", document.at_css("h1")&.text == "New Title")
            notice_consumed("/articles/3")
          else
            check("validation re-render", response.status == 422 && document.at_css("#error_explanation")&.text&.include?("can't be blank"))
          end
        when "article_update", "article_update_invalid"
          body = Article.find(1).body
          get("/articles/1/edit")
          valid = key == "article_update"
          submit("/articles/1", "article" => {"title" => valid ? "Updated Title" : "", "body" => valid ? body : ""})
          if valid
            check("updated title", Article.find(1).title == "Updated Title")
            redirect("/articles/1", 303, "Article was successfully updated.")
            notice_consumed("/articles/1")
          else
            check("validation re-render", response.status == 422 && document.at_css("#error_explanation")&.text&.include?("can't be blank"))
            check("invalid update preserves title/body", Article.find(1).attributes.slice("title", "body") == {"title" => TITLE, "body" => body})
          end
        when "article_destroy"
          before = Article.count
          get("/articles/1")
          submit("/articles/1")
          check("destroyed article and dependent comment", Article.count == before - 1 && !Comment.exists?(1))
          redirect("/articles", 303, "Article was successfully destroyed.")
          notice_consumed("/articles")
        when "comment_create", "comment_create_invalid"
          before = Comment.count
          get("/articles/1")
          valid = key == "comment_create"
          submit("/articles/1/comments", "comment" => {"commenter" => valid ? "Test" : "", "body" => valid ? "A test comment." : ""})
          check("comment count", Comment.count == before + (valid ? 1 : 0))
          redirect("/articles/1", 302, valid ? "Comment was successfully created." : "Could not create comment.")
          check("comment visible", document.at_css("#comments")&.text&.include?("A test comment.")) if valid
          notice_consumed("/articles/1")
        when "comment_destroy"
          before = Comment.count
          get("/articles/1")
          submit("/articles/1/comments/1")
          check("comment destroyed", Comment.count == before - 1 && !Comment.exists?(1))
          redirect("/articles/1", 302, "Comment was successfully deleted.")
          notice_consumed("/articles/1")
        when "article_fixture"
          observe(key) do
            article = Article.find(1)
            check("fixture id and title", article.id == 1 && article.title == TITLE)
            article.attributes
          end
        when "article_title", "article_body"
          observe(key) do
            article = Article.new(title: key == "article_title" ? "" : "Valid Title", body: key == "article_body" ? "Short" : "Valid body content here.")
            saved = article.save
            check("invalid article not saved", !saved && !article.persisted?)
            {"saved" => saved, "errors" => article.errors.full_messages}
          end
        when "article_dependents"
          observe(key) do
            article = Article.find(1)
            before = Comment.count
            article.destroy
            check("dependent destruction", article.destroyed? && Comment.count == before - 1)
            {"destroyed" => article.destroyed?, "comments" => Comment.count}
          end
        when "comment_fixture"
          observe(key) do
            comment = Comment.find(1)
            check("fixture association", comment.id == 1 && comment.article_id == Article.find(1).id)
            comment.attributes
          end
        when "comment_association"
          observe(key) do
            article = Article.find(1)
            comment = article.comments.create(commenter: "Commenter", body: "Comment body text.")
            check("created association", comment.persisted? && comment.article_id == article.id)
            comment.attributes
          end
        when "comment_commenter", "comment_body", "comment_article"
          observe(key) do
            comment = case key
            when "comment_commenter" then Article.find(1).comments.build(body: "Comment without commenter")
            when "comment_body" then Article.find(1).comments.build(commenter: "Someone")
            else Comment.new(commenter: "Test", body: "A test comment.", article_id: 999999)
            end
            saved = comment.save
            check("invalid comment not saved", !saved && !comment.persisted?)
            {"saved" => saved, "errors" => comment.errors.full_messages}
          end
        when "system_article", "system_comments"
          system_workflow(key)
        when "csrf_missing", "csrf_invalid"
          before = Article.count
          get("/articles/new")
          params = {"article" => {"title" => "Must not persist", "body" => BODY}}
          params["authenticity_token"] = "deliberately-invalid" if key == "csrf_invalid"
          request("POST", "/articles", params: params)
          check("production rejects bad CSRF", response.status == 422 && Article.count == before)
        else
          raise "unknown blog scenario #{key}"
        end
        {"completed" => true, "steps" => steps, "checks" => checks}
      end

      def system_workflow(key)
        get("/articles")
        check("new link", document.css("a").any? { _1.text == "New article" && _1["href"] == "/articles/new" })
        get("/articles/new")
        if key == "system_article"
          submit("/articles", "article" => {"title" => "", "body" => ""})
          check("invalid form errors", response.status == 422 && document.text.include?("prohibited this article from being saved") && document.text.include?("can't be blank"))
        end
        title = key == "system_article" ? "My First Article" : "Article for Comments"
        body = key == "system_article" ? "This is the body of my first article, long enough to pass validation." : "This article will have comments added and removed."
        submit("/articles", "article" => {"title" => title, "body" => body})
        redirect("/articles/3", 302, "Article was successfully created.")
        if key == "system_article"
          get("/articles")
          check("new title on index", document.text.include?(title))
          get("/articles/3")
          get("/articles/3/edit")
          submit("/articles/3", "article" => {"title" => "My Updated Article", "body" => body})
          redirect("/articles/3", 303, "Article was successfully updated.")
          check("updated page", document.text.include?("My Updated Article"))
          submit("/articles/3")
          redirect("/articles", 303, "Article was successfully destroyed.")
          check("deleted title absent", !document.text.include?("My Updated Article"))
        else
          submit("/articles/3/comments", "comment" => {"commenter" => "Alice", "body" => "Great article!"})
          redirect("/articles/3", 302, "Comment was successfully created.")
          check("comment visible", document.text.include?("Alice") && document.text.include?("Great article!"))
          submit("/articles/3/comments/3")
          redirect("/articles/3", 302, "Comment was successfully deleted.")
          check("deleted comment absent", !document.text.include?("Great article!"))
        end
      end
    end
  end
end
