# frozen_string_literal: true

# Read-only request-shape observation while running the app's controller tests.
ENV["RAILS_ENV"] = "test"
ENV["PARALLEL_WORKERS"] = "1"
$LOAD_PATH.unshift(File.expand_path("test", Dir.pwd))
require File.expand_path("test/test_helper", Dir.pwd)
require "json"

module BlogTestName
  def run
    Thread.current[:blog_test_name] = "#{self.class.name}##{name}"
    super
  ensure
    Thread.current[:blog_test_name] = nil
  end
end
Minitest::Test.prepend(BlogTestName)

module BlogTestShape
  def process(...)
    result = super
    row = { test: Thread.current[:blog_test_name], method: request.request_method, path: request.path,
      accept: request.get_header("HTTP_ACCEPT"), user_agent: request.user_agent,
      format: request.format.to_s, query: request.query_string, xhr: request.xhr?,
      cookie: request.get_header("HTTP_COOKIE").present?, flash: request.flash.to_h.keys,
      csrf_header: request.get_header("HTTP_X_CSRF_TOKEN").present?,
      csrf_param: request.parameters.key?("authenticity_token"),
      forgery_protection: ActionController::Base.allow_forgery_protection,
      status: response.status, follows_redirect: false }
    File.open(ENV.fetch("BLOG_TEST_SHAPES_OUT"), "a", 0o600) { _1.puts(JSON.generate(row)) }
    result
  end
end
ActionDispatch::Integration::Session.prepend(BlogTestShape)
require File.expand_path("test/controllers/articles_controller_test", Dir.pwd)
require File.expand_path("test/controllers/comments_controller_test", Dir.pwd)
