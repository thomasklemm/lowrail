# frozen_string_literal: true

require_relative "test_helper"

# Runtime pieces of the route-helper pass: Lowrail::Routes (prefix, seg) and
# per-class "@self" facts, including route facts against a stand-in route
# set. Real Rails behavior is checked at build time by the oracle probes and
# end to end by `lowrail verify` on the corpus apps.
class RoutesTest < Minitest::Test
  include LowrailTest

  def test_prefix_mirrors_find_script_name_and_path_for
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/routes"
      Routes = Struct.new(:relative_url_root)
      T = Struct.new(:_routes)
      t = T.new(Routes.new(nil))
      r = Lowrail::Routes
      dflt = Hash.new(1)
      res = {
        empty: r.prefix({}, t),
        blank: r.prefix({ script_name: "" }, t),
        sub: r.prefix({ script_name: "/sub/" }, t),
        nil_script: r.prefix({ script_name: nil }, T.new(Routes.new("/root/"))),
        root: r.prefix({ host: "x" }, T.new(Routes.new("/root"))),
        slash: r.prefix({ trailing_slash: true }, t),
        original: r.prefix({ original_script_name: "/a" }, t),
        params: r.prefix({ params: {} }, t),
        anchor: r.prefix({ anchor: "x" }, t),
        default: r.prefix(dflt, t),
        subclass: r.prefix(Class.new(Hash).new, t),
        new_string: (s = +"/s"; !r.prefix({ script_name: s }, t).equal?(s))
      }
      puts JSON.generate(res)
    RUBY
    assert_equal({ "empty" => "", "blank" => "", "sub" => "/sub", "nil_script" => "/root", "root" => "/root",
                   "slash" => nil, "original" => nil, "params" => nil, "anchor" => nil, "default" => nil,
                   "subclass" => nil, "new_string" => true }, out)
  end

  # url_prefix + path must equal Rails' url_for for the same options; the
  # cases Rails raises on return nil so the real helper raises.
  def test_url_prefix_matches_rails_url_for
    out = ruby_json(<<~'RUBY')
      require "json"
      require "active_support/core_ext/object/to_query"
      require "action_dispatch"
      require "lowrail"
      require "lowrail/routes"
      Routes = Struct.new(:relative_url_root)
      T = Struct.new(:_routes)
      t = T.new(Routes.new("/root/"))
      cases = [
        { host: "example.org" },
        { host: "example.org", protocol: "https", port: 443 },
        { host: "example.org", protocol: "http://", port: 8080, script_name: "/sub/" },
        { host: "https://a.example.co.uk:9443" },
        { host: "a.example.co.uk", subdomain: "api", tld_length: 2 },
        { host: "a.example.org", domain: "other.net", protocol: "//" },
        { host: "example.org", user: "u s", password: "p@w" },
        { host: "example.org", only_path: true },
        { host: "[::1]", port: 3000 }
      ]
      res = cases.map do |o|
        want = ActionDispatch::Http::URL.url_for(o.merge(path: "/x/7", script_name: o[:script_name] || "/root/"))
        pre = Lowrail::Routes.url_prefix(o, t)
        [want, pre && (pre << "/x/7")]
      end
      declined = [{}, { host: nil }, { host: :sym }, { host: "x", protocol: "bad:proto:" }].map { Lowrail::Routes.url_prefix(_1, t) }
      puts JSON.generate(res: res, declined: declined)
    RUBY
    out["res"].each { |want, have| assert_equal want, have }
    assert_equal "https://a.example.co.uk:9443/root/x/7", out["res"][3][1]
    assert_equal [nil, nil, nil, nil], out["declined"]
  end

  def test_url_completion_tracks_request_options_and_returns_an_unshared_string
    out = ruby_json(<<~'RUBY')
      require "json"
      require "rails"
      require "active_support/core_ext/object/to_query"
      require "action_controller"
      require "action_view"
      require "lowrail/routes"
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw { resources :widgets }
      Rails.define_singleton_method(:application) { Struct.new(:routes).new(routes) }
      class Controller < ActionController::Base; end
      Controller.include(routes.url_helpers)
      Controller.define_method(:_routes) { routes }
      def Controller.new_request(routes, url)
        c = new
        req = ActionDispatch::Request.new(Rack::MockRequest.env_for(url, "action_dispatch.routes" => routes))
        c.set_request!(req)
        c.set_response!(make_response!(req))
        c
      end
      c = Controller.new_request(routes, "https://one.example.org:8443/widgets/7")
      checks = []
      check = ->(ctx) do
        want = ctx.widget_url("a b")
        2.times do
          have = Lowrail::Routes.url_for(ctx.url_options.merge(path: "/widgets/a%20b"), ctx)
          raise "encoding changed" unless have.encoding == want.encoding
          checks << [want, have.dup]
          have << "mutation"
        end
      end
      check.call(c)
      c.request.script_name = "/mount/"
      check.call(c.view_context)
      # Rails keeps its base snapshot even after defaults/host change, but
      # observes the script name each call. Do not create a second snapshot.
      c.request.set_header("HTTP_HOST", "ignored.example.net")
      c.default_url_options = { host: "also-ignored.example.net" }
      check.call(c)
      c.default_url_options = {}
      # A Current-style url_options override, including in-place mutations.
      options = c.url_options.transform_values { |v| v.instance_of?(String) ? v.dup : v }
      c.define_singleton_method(:url_options) { options }
      check.call(c)
      options[:host].replace("two.example.net")
      options[:script_name].replace("/changed/")
      options[:protocol] = "http://"
      options[:port] = 8080
      check.call(c)
      options[:host] = options[:host].encode(Encoding::US_ASCII)
      check.call(c)
      options[:protocol] = nil
      ActionDispatch::Http::URL.secure_protocol = false
      check.call(c)
      ActionDispatch::Http::URL.secure_protocol = true
      check.call(c)
      ActionDispatch::Http::URL.secure_protocol = false
      options[:host] = "https://embedded.example.com:9443"
      options.delete(:port)
      check.call(c)
      options[:port] = nil
      check.call(c)
      check.call(Controller.new_request(routes, "http://three.example.com/widgets/9"))
      puts JSON.generate(checks)
    RUBY
    out.each { |want, have| assert_equal want, have }
    assert_equal "https://one.example.org:8443/mount/widgets/a%20b", out[2][1]
    assert_equal "http://two.example.net:8080/changed/widgets/a%20b", out[8][1]
    assert_equal "http://three.example.com/widgets/a%20b", out.last[1]
  end

  def test_custom_helper_probes_reject_discarding_block_state_and_resolve_mapping
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "config/routes.rb" => <<~'RUBY')
        class RouteCurrent
          class << self; attr_accessor :version, :calls; end
        end
        RouteCurrent.version = "alpha"
        RouteCurrent.calls = 0
        Rails.application.routes.draw do
          resources :widgets
          direct :fresh_widget do |value, options|
            RouteCurrent.calls += 1
            route_for(:widget, value, options.merge(v: RouteCurrent.version))
          end
          resolve("Widget") do |widget, options|
            RouteCurrent.calls += 1
            route_for(:widget, widget.id, options.merge(v: RouteCurrent.version))
          end
        end
      RUBY
      out = ruby_json(<<~'RUBY', chdir: dir, env: { "RAILS_ENV" => "test" })
        require "./config/environment"
        require "lowrail/oracle_routes"
        Rails.application.eager_load!
        Rails.application.routes.default_url_options[:host] = "example.org"
        c = ApplicationController.new
        c.set_request!(ActionDispatch::TestRequest.create)
        c.set_response!(ApplicationController.make_response!(c.request))
        view = c.view_context
        info = Lowrail::OracleRoutes.info(view, :fresh_widget_path)
        untouched = RouteCurrent.calls
        probe = Lowrail::OracleRoutes.probe([["view", view]], ["a"], "widget_path(a)", "fresh_widget_path(a)")
        RouteCurrent.calls = 0
        widget = Widget.new(id: 31)
        first = [view.fresh_widget_path("7"), view.polymorphic_path(widget)]
        RouteCurrent.version = "beta"
        second = [view.fresh_widget_path("7"), view.polymorphic_path(widget)]
        puts JSON.generate(info: info, untouched: untouched, probe: probe, first: first, second: second, calls: RouteCurrent.calls)
      RUBY
      assert_equal "custom", out.dig("info", "kind")
      assert_includes out.dig("info", "reason"), "argument/option mapping are not guarded"
      assert_includes out.dig("info", "reason"), "route_for"
      assert_equal 0, out["untouched"], "diagnostics must not execute app blocks"
      assert_equal false, out.dig("probe", "ok"), "forwarding without the block loses its query/state"
      assert_equal ["/widgets/7?v=alpha", "/widgets/31?v=alpha"], out["first"]
      assert_equal ["/widgets/7?v=beta", "/widgets/31?v=beta"], out["second"]
      assert_equal 4, out["calls"], "each helper must execute its block exactly once"
    end
  end

  def test_generic_routes_preserve_defaults_recall_format_and_script_mutations
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "config/routes.rb" => <<~'RUBY')
        Rails.application.routes.draw do
          get "/users/:user_id/profile(.:format)", to: "profiles#show", as: :profile, defaults: { user_id: "me" }
          get "/users/:user_id/widgets/:id(.:format)", to: "widgets#show", as: :user_widget
          get "/default/users/:user_id/widgets/:id(.:format)", to: "widgets#show", as: :default_widget, defaults: { user_id: "me" }
        end
      RUBY
      out = ruby_json(<<~'RUBY', chdir: dir, env: { "RAILS_ENV" => "test" })
        require "./config/environment"
        require "lowrail/oracle_routes"
        Rails.application.eager_load!
        routes = Rails.application.routes
        req = ActionDispatch::Request.new(Rack::MockRequest.env_for("http://example.org/users/41/widgets/23",
          "action_dispatch.routes" => routes))
        req.path_parameters = { controller: "widgets", action: "show", user_id: "41", id: "23", format: "xml" }
        c = ApplicationController.new
        c.set_request!(req)
        c.set_response!(ApplicationController.make_response!(req))
        view = c.view_context
        info = Lowrail::OracleRoutes.info(view, :profile_path)
        paths = [view.profile_path, view.user_widget_path, view.user_widget_path("9"),
                 view.default_widget_path("9"), view.user_widget_path("9", "87", "json")]
        # A plausible default-expansion optimization: it preserves dynamic
        # completion, but loses generic generation's supplied format.
        fast = "Lowrail::Routes.finish(+'/users/me/profile', url_options.merge(Rails.application.routes.named_routes.get(:profile).defaults), self, false)"
        probe = Lowrail::OracleRoutes.probe([["view", view]], [], fast, "profile_path")
        view.define_singleton_method(:url_options) { c.url_options.merge(format: "json") }
        supplied_format = view.profile_path
        events = []
        routes.define_singleton_method(:find_script_name) do |options|
          events << "script"
          options[:user_id] = "mounted"
          "/engine"
        end
        param = Object.new
        param.define_singleton_method(:to_param) { events << "param"; "9" }
        mounted = view.default_widget_path(param)
        puts JSON.generate(info: info, paths: paths, probe: probe, supplied_format: supplied_format, mounted: mounted, events: events)
      RUBY
      assert_equal ["user_id"], out.dig("info", "default_parts")
      assert_equal ["user_id", "format"], out.dig("info", "segment_keys")
      assert_equal ["/users/me/profile", "/users/41/widgets/23", "/users/9/widgets/23",
                    "/default/users/me/widgets/9", "/users/9/widgets/87.json"], out["paths"]
      assert_equal false, out.dig("probe", "ok")
      assert_includes out.dig("probe", "reason"), "changing url_options [:format]"
      assert_equal "/users/me/profile.json", out["supplied_format"]
      assert_equal "/engine/default/users/mounted/widgets/9.json", out["mounted"]
      assert_equal ["script", "param"], out["events"]
    end
  end

  def test_seg_skips_gsub_only_for_safe_ascii
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/routes"
      module ActionDispatch; module Journey; module Router; module Utils
        class UriEncoder; SEGMENT = /[^a-z0-9]/; end
        def self.escape_segment(s) = "esc(#{s})"
      end; end; end; end
      safe = "abc123"
      broken = (+"\xFF").force_encoding("UTF-8")
      puts JSON.generate([Lowrail::Routes.seg(safe).equal?(safe), Lowrail::Routes.seg("a b"),
                          Lowrail::Routes.seg("café"), Lowrail::Routes.seg(broken).b == "esc(\xFF)".b])
    RUBY
    assert_equal [true, "esc(a b)", "esc(café)", true], out
  end

  # "@self" facts are checked against the class passed to Lowrail.ok? and
  # cached per class; route facts also require the helper to be the route
  # set's method for an unchanged route.
  def test_ok_checks_self_facts_per_class_and_route_facts
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/guard"
      require "lowrail/loader"
      Route = Struct.new(:spec_s, :required_parts, :defaults, :requirements) do
        def path = Struct.new(:spec, :requirements).new(spec_s, requirements)
      end
      Named = Struct.new(:path_helpers_module, :routes, :url_helpers_module) do
        def get(name) = routes[name.to_sym]
      end
      $helpers = Module.new { def article_path(a) = "/articles/#{a}" } # anonymous, like a route set's
      $urls = Module.new { def article_url(a) = "http://x/articles/#{a}" }
      NAMED = Named.new($helpers, { article: Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, {}) }, $urls)
      module Rails
        def self.application = Struct.new(:routes).new(Struct.new(:named_routes).new(NAMED))
      end
      class ViewA; include $helpers; include $urls; end
      class ViewB; include $helpers; end
      class ViewC; def article_path(a) = "own"; end
      loc = $helpers.instance_method(:article_path).source_location.join(":")
      fact = { "receiver" => "@self", "method" => "article_path", "owner" => nil, "source_location" => loc,
               "visibility" => "public",
               "route" => { "name" => "article", "spec" => "/articles/:id(.:format)", "parts" => ["id"],
                            "defaults" => { controller: "articles" }.inspect } }
      # A *_url helper lives in the route set's URL helper module.
      url_fact = fact.merge("method" => "article_url", "source_location" => $urls.instance_method(:article_url).source_location.join(":"))
      # Exercise the generic fact validator, not the quarantined source pass.
      # Old route/path artifacts are separately required to refuse at boot.
      units = [{ "id" => 0, "kind" => "file", "file" => "/x.rb", "pass" => "test/route_facts", "facts" => [fact] },
               { "id" => 1, "kind" => "file", "file" => "/x.rb", "pass" => "test/route_facts", "facts" => [fact, url_fact] }]
      manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
                                         "files" => {}, "units" => units }, "/tmp")
      Lowrail::Guard.install(manifest)
      res = {}
      res[:a] = Lowrail.ok?(0, ViewA)
      res[:url] = Lowrail.ok?(1, ViewA)
      res[:b] = Lowrail.ok?(0, ViewB)
      res[:c] = Lowrail.ok?(0, ViewC)             # own method, not the route set's
      res[:cached] = Lowrail::V[0].size
      NAMED.routes[:article] = Route.new("/posts/:id(.:format)", [:id], { controller: "articles" }, {})
      res[:stale_cache] = Lowrail.ok?(0, ViewA)    # no hook fired yet: still cached
      # A redraw redefines the helper (Rails defines it with the same
      # define_method line, so the source location still matches); the
      # method_added hook resets the unit, and revalidation sees the route.
      Lowrail::Guard.reset_method(:article_path)
      res[:spec_changed] = Lowrail.ok?(0, ViewA)
      NAMED.routes[:article] = Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, { id: /\d+/ })
      Lowrail::Guard.reset_method(:article_path)
      res[:requirements] = Lowrail.ok?(0, ViewA)
      NAMED.routes[:article] = Route.new("/articles/:id(.:format)", [:id], { controller: "articles" }, {})
      Lowrail::Guard.reset_method(:article_path)
      res[:restored] = Lowrail.ok?(0, ViewA)
      $helpers.define_method(:article_path) { |a| a }  # a different definition
      res[:redefined] = Lowrail.ok?(0, ViewA)
      puts JSON.generate(res)
    RUBY
    assert_equal({ "a" => true, "url" => true, "b" => true, "c" => false, "cached" => 3, "stale_cache" => true,
                   "spec_changed" => false, "requirements" => false, "restored" => true, "redefined" => false }, out)
  end
end
