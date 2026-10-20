# frozen_string_literal: true

# Separate correctness worker. Entropy and clock controls apply equally to
# both arms, NEVER to heap_requests.rb / the instruction measurements.
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
require "digest"
require_relative "blog_layers"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
module ControlledEntropy
  def random_bytes(n = 16)
    rng = Thread.current[:blog_check_rng]
    rng ? rng.bytes(n) : super
  end
end
SecureRandom.singleton_class.prepend(ControlledEntropy)
OpenSSL::Random.singleton_class.prepend(ControlledEntropy)
Rack::Utils.singleton_class.prepend(Module.new do
  def clock_time
    Thread.current[:blog_check_rng] ? 1000.0 : super
  end
end)
original = Rails.application.app
layer = ARGV.fetch(0)
paths = ["/articles", "/articles/1", "/articles/2", "/articles/3"]
request = ->(app, path, cookie = nil) do
  rows = []
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    payload = args.last
    next if %w[SCHEMA TRANSACTION].include?(payload[:name])
    rows << { sql: payload[:sql], binds: payload[:binds].map { [_1.name, _1.value_for_database] }, cached: !!payload[:cached] }
  end
  Thread.current[:blog_check_rng] = Random.new(41231)
  response = Rack::MockRequest.new(app).get(path, Rails.application.env_config.merge(
    "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "ceiling-study", "HTTP_COOKIE" => cookie))
  [response, rows]
ensure
  Thread.current[:blog_check_rng] = nil
  ActiveSupport::Notifications.unsubscribe(subscriber)
end
# Key generation, template compilation and schema reads outside comparisons.
paths.each { |path| request.call(original, path) }
baselines = paths.flat_map do |path|
  first, = request.call(original, path)
  cookie = first["set-cookie"].split(";").first
  [nil, cookie].map { |input_cookie| [path, input_cookie, *request.call(original, path, input_cookie)] }
end
# Capture off BEFORE a component can modify any global class.
BlogLayers.install(layer)
variant = Rails.application.app
paths.each { |path| request.call(variant, path) }
results = baselines.map do |path, input_cookie, off, sql_off|
    on, sql_on = request.call(variant, path, input_cookie)
    result = { layer: layer, path: path, cookie: !!input_cookie, status: [off.status, on.status],
      bytes: [off.body.bytesize, on.body.bytesize], body_identical: off.body == on.body,
      headers_identical: off.headers == on.headers, sql_identical: sql_off == sql_on,
      sql: sql_off, body_sha256: Digest::SHA256.hexdigest(off.body) }
    unless result.values_at(:body_identical, :headers_identical, :sql_identical).all? && off.status == 200 && on.status == 200
      File.write("/tmp/blog-check-off.html", off.body)
      File.write("/tmp/blog-check-on.html", on.body)
      warn JSON.pretty_generate(result.merge(header_differences: (off.headers.keys | on.headers.keys).select { off[_1] != on[_1] }.reject { _1 == "set-cookie" }))
      warn "body mismatch at byte #{(0...[off.body.bytesize, on.body.bytesize].min).find { off.body.getbyte(_1) != on.body.getbyte(_1) }}"
      exit 1
    end
    result
end
File.write(ARGV.fetch(1), JSON.pretty_generate(results))
puts "#{layer}: #{results.size} paired body/header/ordered-SQL checks passed"
