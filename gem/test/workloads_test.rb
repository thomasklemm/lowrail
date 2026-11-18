# frozen_string_literal: true

# The workloads file DSL (gem/lib/lowrail/workloads.rb) that script/census app
# (A) and lowrail-profile --workloads (B) both read.
#   ruby -Igem/lib -Igem/test gem/test/workloads_test.rb

require "test_helper"
require "digest"
require "lowrail/workloads"

class WorkloadsTest < Minitest::Test
  include LowrailTest

  def definition(&) = Lowrail::Workloads::Definition.new("(test)").tap { _1.instance_eval(&) }

  # An override of the path alone keeps the declared JSON body.
  def test_path_only_overrides_keep_a_json_body
    d = definition do
      post "/api/a", as: :json, params: { x: 1 }, alternate: [{ path: "/api/b" }], name: "alternate"
      post("/api/a", as: :json, params: { x: 1 }, name: "block") { |n| { path: "/api/#{n}" } }
    end
    alternate, block = d.requests
    assert_equal [["/api/b", '{"x":1}']], [alternate.at(1)].map { [_1.path, _1.body] }
    assert_equal ["/api/1", '{"x":1}'], [block.at(1).path, block.at(1).body]
    assert_equal({}, block.at(1).params)
  end

  # Requests keep frozen copies of what the file passed, so the manifest
  # describes what is sent; header values are part of it, as digests.
  def test_requests_are_frozen_copies_and_the_manifest_covers_header_values
    params = { "item" => { "name" => +"before" } }
    accept = +"text/html"
    d = definition { get "/a", params: params, headers: { "Accept" => accept } }
    before = JSON.generate(d.manifest)
    params["item"]["name"] << " after"
    accept.replace("application/json")
    request = d.requests.first
    assert_equal({ "item" => { "name" => "before" } }, request.params)
    assert_equal "text/html", request.headers["HTTP_ACCEPT"]
    assert_equal before, JSON.generate(d.manifest)
    refute params.frozen?, "the file's own objects are not frozen"
    other = definition { get "/a", params: { "item" => { "name" => "before" } }, headers: { "Accept" => "application/json" } }
    refute_equal d.manifest["requests"][0]["headers_sha256"], other.manifest["requests"][0]["headers_sha256"]
  end

  # A and B send the same requests: census 4's Rack::Test client (A) and
  # lowrail-profile's client (B), through the shared policy, recorded by a
  # middleware in front of the app. The file has a sign-in, CSRF from a page,
  # a header, an XHR and a JSON write with an alternate, a write with
  # csrf: false, a signed-out request, and a cookie scoped to a path.
  def test_census_and_profile_send_the_same_requests
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "config/routes.rb" => <<~'RUBY',
          Rails.application.routes.draw do
            get "/form" => "pages#form"
            post "/session" => "pages#sign_in"
            get "/me" => "pages#me"
            post "/items" => "pages#ok"
            post "/api" => "pages#ok"
            post "/nocsrf" => "pages#nocsrf"
            get "/private/login" => "pages#scoped"
            get "/private/me" => "pages#ok"
            get "/public" => "pages#ok"
          end
        RUBY
        "app/controllers/pages_controller.rb" => <<~'RUBY',
          class PagesController < ApplicationController
            skip_forgery_protection only: :nocsrf
            def form = render(html: %(<meta name="csrf-token" content="#{form_authenticity_token}">).html_safe)
            def sign_in = (session[:user] = 1; redirect_to("/me"))
            def me = render(plain: "user #{session[:user].inspect}")
            def ok = render(plain: "ok")
            def nocsrf = render(plain: "ok")
            def scoped = (cookies[:auth] = { value: "yes", path: "/private" }; render(plain: "ok"))
          end
        RUBY
        "config/initializers/recorder.rb" => <<~'RUBY',
          SENT = []
          Rails.application.config.middleware.insert_before 0, Class.new {
            def initialize(app) = @app = app
            def call(env)
              request = ActionDispatch::Request.new(env)
              params = request.request_parameters.merge(request.query_parameters)
              params["authenticity_token"] = "T" if params["authenticity_token"]
              headers = %w[HTTPS rack.url_scheme HTTP_HOST HTTP_USER_AGENT HTTP_ACCEPT HTTP_SEC_FETCH_SITE HTTP_ORIGIN
                HTTP_X_REQUESTED_WITH HTTP_X_HTTP_METHOD_OVERRIDE HTTP_X_PROBE].to_h { [_1, env[_1]] }
              SENT << { "method" => env["REQUEST_METHOD"], "path" => env["PATH_INFO"], "query" => env["QUERY_STRING"],
                "type" => request.media_type, "params" => params, "headers" => headers, "token_header" => !env["HTTP_X_CSRF_TOKEN"].nil?,
                "cookies" => env["HTTP_COOKIE"].to_s.scan(/(?:\A|; )([^=;]+)=/).flatten.sort }
              @app.call(env)
            end
          }
        RUBY
        "lowrail/workloads.rb" => <<~'RUBY',
          sign_in "/session", params: { email: "a@example.com", password: "pw" }, form: "/form", expect: 302
          csrf_from "/form"
          get "/me", name: "me", headers: { "X-Probe" => "a" }
          post "/nocsrf", name: "no CSRF", csrf: false
          post "/items", name: "item", params: { item: { name: "x" } }
          post "/items", name: "item (XHR)", xhr: true, params: { item: { name: "y" } }
          post "/api", name: "api", as: :json, params: { n: 1 }, alternate: [{ path: "/api?v=2" }, { params: { n: 2 } }]
          get "/me", name: "me (signed out)", signed_in: false
          get "/private/login", name: "scoped cookie"
          get "/public", name: "outside its path"
          get "/private/me", name: "inside its path"
        RUBY
        "contract.rb" => <<~RUBY)
          require "./config/environment"
          require "json"
          require "rack/mock"
          require "lowrail/workloads"
          require #{File.join(GEM_ROOT, "../bench/upstream/rails_main_census_4").inspect}
          require #{File.join(GEM_ROOT, "../bench/upstream/census/app_workloads").inspect}
          ops = CensusAppWorkloads.load(RailsMainCensus4, "lowrail/workloads.rb")
          2.times { ops.each { _1.call.call } }
          a = SENT.dup
          SENT.clear
          d = Lowrail::Workloads.load("lowrail/workloads.rb")
          replay = Lowrail::Workloads::Replayer.new(d, *Array.new(2) { Lowrail::Workloads::MockClient.new(Rails.application, "localhost") })
          replay.sign_in
          2.times { d.requests.each { replay.perform(_1) } }
          puts JSON.generate(a: a, b: SENT)
        RUBY
      sent = ruby_json(File.read(File.join(dir, "contract.rb")), chdir: dir, setup: false,
        env: { "RAILS_ENV" => "test", "RUBYOPT" => "-I#{GEM_LIB}" })
      assert_equal sent["a"], sent["b"]
      sent = sent["b"]
      # The write with csrf: false comes first and fetches no token page.
      assert_equal [%w[GET /form], %w[POST /session], %w[GET /me], %w[POST /nocsrf], %w[GET /form], %w[POST /items],
        %w[POST /items], %w[POST /api], %w[GET /me]], sent.first(9).map { _1.values_at("method", "path") }
      me, nocsrf, item, xhr, api = sent.values_at(2, 3, 5, 6, 7)
      assert_equal %w[localhost https://localhost a], me["headers"].values_at("HTTP_HOST", "HTTP_ORIGIN", "HTTP_X_PROBE")
      assert_equal [{}, false, "application/x-www-form-urlencoded"], nocsrf.values_at("params", "token_header", "type")
      assert_equal [{ "item" => { "name" => "x" }, "authenticity_token" => "T" }, false], item.values_at("params", "token_header")
      assert_equal [{ "item" => { "name" => "y" } }, true, "XMLHttpRequest"], [*xhr.values_at("params", "token_header"), xhr["headers"]["HTTP_X_REQUESTED_WITH"]]
      assert_equal ["v=2", { "n" => 1, "v" => "2" }, true, "application/json"], api.values_at("query", "params", "token_header", "type")
      assert_equal({ "n" => 2 }, sent[16]["params"])
      assert_equal [["_fixture_app_session"], []], sent.values_at(2, 8).map { _1["cookies"] }
      assert_equal [%w[_fixture_app_session], %w[_fixture_app_session auth]], sent.values_at(10, 11).map { _1["cookies"] }
    end
  end
end
