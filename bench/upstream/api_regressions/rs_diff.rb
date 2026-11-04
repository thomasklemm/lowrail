require "action_dispatch"
require "action_dispatch/middleware/session/abstract_store"
ActionDispatch.deprecator.behavior = ->(msg, *) { $warned = (($warned || 0) + 1) }
req = ActionDispatch::Request.empty
store = Class.new { def load_session(env) = ["id", { "a" => 1 }]; def session_exists?(env) = true; def delete_session(*) = nil }.new
r = ->(l, &b) { $warned = 0; v = (b.call rescue $!); puts "#{l}: #{v.is_a?(Exception) ? v.class : v.inspect[0, 70]} warned=#{$warned > 0}" }
r.("create")      { ActionDispatch::Request::Session.create(store, req, {}).class.name }
r.("find")        { ActionDispatch::Request::Session.find(req).class.name }
r.("is_a?")       { req.session.is_a?(ActionDispatch::Request::Session) }
r.("ENV key")     { ActionDispatch::Request::Session::ENV_SESSION_KEY }
r.("Options")     { ActionDispatch::Request::Session::Options.find(req).class.name }
r.("deep_munge")  { ActionDispatch::Request::Utils.perform_deep_munge }
r.("set munge")   { ActionDispatch::Request::Utils.perform_deep_munge = true }
r.("defined?")    { defined?(ActionDispatch::Request::Session) }
r.("const_get")   { ActionDispatch::Request.const_get(:Session).name }
r.("TestRequest") { require "action_dispatch/testing/test_request"; ActionDispatch::TestRequest::Session.name rescue $!.class }
