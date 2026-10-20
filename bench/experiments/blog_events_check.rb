# frozen_string_literal: true

# Observer-visible event boundaries are a separate check from HTML and SQL.
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
require_relative "blog_eventful"
Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil

class BlogEventTrace
  attr_accessor :rows

  def normalize(value, key = nil)
    return "numeric runtime" if %i[view_runtime db_runtime].include?(key) && value.is_a?(Numeric)
    case value
    when Hash then value.to_h { |k, v| [k.to_s, normalize(v, k)] }
    when Array then value.map { normalize(_1) }
    when String, Symbol, Numeric, NilClass, TrueClass, FalseClass then value
    when ActionDispatch::Response then { status: value.status }
    when ActionDispatch::Request then { method: value.request_method, path: value.path }
    when ActionDispatch::Http::Headers then "live request headers"
    else value.class.name
    end
  end

  def start(name, id, payload)
    rows&.push(["start", name, normalize(payload)])
  end

  def finish(name, id, payload)
    rows&.push(["finish", name, normalize(payload)])
  end
end

trace = BlogEventTrace.new
subscription = ActiveSupport::Notifications.subscribe(/\.(action_controller|action_view)\z/, trace)
paths = %w[/articles /articles/1 /articles/2 /articles/3]
original = Rails.application.app
request = ->(app, path) do
  trace.rows = []
  response = Rack::MockRequest.new(app).get(path, Rails.application.env_config.merge("HTTP_HOST" => "localhost", "HTTPS" => "on"))
  raise "HTTP #{response.status}" unless response.status == 200
  trace.rows
end
paths.each { request.call(original, _1) }
baseline = paths.to_h { [_1, request.call(original, _1)] }
BlogEventful.install
variant = Rails.application.app
paths.each { request.call(variant, _1) }
results = paths.map do |path|
  actual = request.call(variant, path)
  expected = baseline.fetch(path)
  unless expected == actual
    File.write("/tmp/blog-events-off.json", JSON.pretty_generate(expected))
    File.write("/tmp/blog-events-on.json", JSON.pretty_generate(actual))
    abort "event mismatch for #{path}; inspect /tmp/blog-events-{off,on}.json"
  end
  { path: path, identical: true, boundaries: actual.size, trace: actual }
end
ActiveSupport::Notifications.unsubscribe(subscription)
File.write(ARGV.fetch(0), JSON.pretty_generate(results))
puts "4 event traces identical: names, nesting, payload keys and stable values (timing values type-checked)"
