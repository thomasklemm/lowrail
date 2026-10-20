# frozen_string_literal: true

# Paired, isolated endpoint shadow. This is NEVER loaded by the runtime gem.
# Raw responses/cookies remain in a new private output directory, not Git.
require "json"
require "digest"

if ARGV.first != "worker"
  require "fileutils"
  require "rbconfig"
  app, output = ARGV.first(2).map { File.expand_path(_1) }
  mutation = ARGV[2] || "none"
  build = ARGV[3] && File.expand_path(ARGV[3])
  abort "usage: blog_endpoint_check.rb APP NEW_OUTPUT_DIR [MUTATION [BUILD_DIR]]" unless app && output
  abort "output directory must be new" if File.exist?(output)
  FileUtils.mkdir_p(output, mode: 0o700)
  if build
    FileUtils.mkdir_p(File.join(output, "root"))
    FileUtils.ln_s(build, File.join(output, "root/.lowrail"))
  end
  lib = File.expand_path("../../gem/lib", __dir__)
  %w[off on].each do |arm|
    env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1",
      "LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_STATS" => "",
      "LOWRAIL_SHADOW" => "strict", "ENDPOINT_MUTATION" => mutation,
      "RUBYOPT" => "-I#{lib} -rlowrail/setup"}
    if ENV["SEALED_RENDERER_STAGE"]
      env.merge!("LOWRAIL" => "0", "RUBYOPT" => nil,
        "SEALED_RENDERER_ARM" => arm, "SEALED_RENDERER_STAGE" => ENV.fetch("SEALED_RENDERER_STAGE"))
    end
    env["LOWRAIL_ROOT"] = File.join(output, "root") if build
    ok = system(env, RbConfig.ruby, File.expand_path(__FILE__), "worker", File.join(output, "#{arm}.json"),
      chdir: app, out: File.join(output, "#{arm}.log"), err: [:child, :out])
    abort "#{arm} worker failed; inspect private log" unless ok
  end
  off, on = %w[off on].map { JSON.parse(File.read(File.join(output, "#{_1}.json"))) }
  count = ENV["SEALED_RENDERER_STAGE"] ? 192 : 144
  raise "specimen count" unless off.fetch("responses").size == count && on.fetch("responses").size == count
  off.fetch("responses").zip(on.fetch("responses")).each_with_index do |(left, right), index|
    next if left == right
    fields = (left.keys | right.keys).reject { left[_1] == right[_1] }
    abort "specimen #{index} differs: #{fields.join(', ')}; private raw responses retained"
  end
  if ENV["SEALED_RENDERER_STAGE"]
    raise "specimen coverage missing" unless on.fetch("specimen_hits").positive? && off.fetch("specimen_hits").zero?
  elsif build && on.fetch("endpoint_hits").empty?
    raise "default source coverage missing" if on.fetch("hits").empty?
  else
    counts = on.fetch(%w[none render_subscriber].include?(mutation) ? "endpoint_hits" : "endpoint_fallbacks")
    raise "endpoint coverage missing" unless counts.size == 2 && counts.values.all?(&:positive?)
  end
  puts "#{count} isolated pairs identical (#{mutation}): status, body, ALL headers, ordered SQL, controller/render event trace"
  puts "on hits=#{on.fetch('hits').inspect}; fallbacks=#{on.fetch('fallbacks').inspect}"
  exit
end

destination = ARGV.fetch(1)
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
raise "wrong app" unless Rails.version == "8.1.4" && Rails.application.class.name == "RealBlogR4::Application"

module EndpointEntropy
  def random_bytes(n = 16)
    rng = Thread.current[:endpoint_rng]
    rng ? rng.bytes(n) : super
  end
end
SecureRandom.singleton_class.prepend(EndpointEntropy)
OpenSSL::Random.singleton_class.prepend(EndpointEntropy)
Time.singleton_class.prepend(Module.new do
  def now(...)
    Thread.current[:endpoint_rng] ? Time.at(1_792_454_400).utc : super
  end
end)
Rack::Utils.singleton_class.prepend(Module.new do
  def clock_time
    Thread.current[:endpoint_rng] ? 1000.0 : super
  end
end)
Process.singleton_class.prepend(Module.new do
  def clock_gettime(clock, unit = :float_second)
    return super unless Thread.current[:endpoint_rng]
    {float_second: 1000.0, second: 1000, float_millisecond: 1_000_000.0,
      millisecond: 1_000_000, float_microsecond: 1_000_000_000.0,
      microsecond: 1_000_000_000, nanosecond: 1_000_000_000_000}.fetch(unit)
  end
end)

class EndpointEvents
  attr_accessor :events
  def value(object)
    case object
    when Hash then object.to_h { |key, child| [key.to_s, value(child)] }
    when Array then object.map { value(_1) }
    when Symbol then object.to_s
    when String, Numeric, TrueClass, FalseClass, NilClass then object
    when ActionDispatch::Request then {"method" => object.request_method, "path" => object.path}
    when ActionDispatch::Response then {"status" => object.status, "headers" => object.headers.to_h}
    when ActionDispatch::Http::Headers then {"accept" => object["Accept"], "user_agent" => object["User-Agent"]}
    when Exception then {"class" => object.class.name, "message" => object.message}
    else object.class.name
    end
  end

  def record(boundary, name, payload)
    return unless events
    controller = ActiveSupport::ExecutionContext.to_h[:controller]
    state = controller && {"action" => controller.action_name,
      "articles_assigned" => controller.instance_variable_defined?(:@articles),
      "article_assigned" => controller.instance_variable_defined?(:@article)}
    if state && ENV["SEALED_RENDERER_STAGE"]
      article = controller.instance_variable_get(:@article)
      state["assign_keys"] = controller.view_assigns.keys.sort
      state["article"] = article && [article.class.name, article.attributes,
        article.persisted?, article.association(:comments).loaded?]
      state["transaction_open"] = ActiveRecord::Base.connection.transaction_open?
      state["query_cache"] = ActiveRecord::Base.connection.query_cache_enabled
    end
    events << [boundary, name, value(payload), state]
  end
  def start(name, id, payload) = record("start", name, payload)
  def finish(name, id, payload) = record("finish", name, payload)
end

events = EndpointEvents.new
ActiveSupport::Notifications.subscribe(/\.(action_controller|action_view)\z/, events)
sql = []
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  payload = args.last
  sql << [payload[:name], payload[:sql], payload[:binds].map { [_1.name, _1.value_for_database] }, !!payload[:cached]]
end
request = ->(path, headers, cookie = nil, capture = true) do
  Thread.current[:endpoint_rng] = Random.new(41231)
  sql.clear
  events.events = capture ? [] : nil
  response = Rack::MockRequest.new(Rails.application).get(path, Rails.application.env_config.merge(
    "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "endpoint-shadow", "HTTP_COOKIE" => cookie).merge(headers))
  {"status" => response.status, "body" => response.body, "headers" => response.headers,
    "sql" => sql.dup, "events" => events.events&.dup}
ensure
  Thread.current[:endpoint_rng] = nil
  events.events = nil
end

mutation = ENV.fetch("ENDPOINT_MUTATION", "none")
mod = ActionView::Helpers::UrlHelper
armed = false
patch = -> {
  original = mod.instance_method(:link_to)
  mod.define_method(:link_to) do |*args, **kwargs, &block|
    original.bind_call(self, *args, **kwargs, &block) + "<!-- endpoint live helper -->".html_safe
  end
}
case mutation
when "none"
when "helper", "suppressed", "invokesuper"
  mod.define_singleton_method(:method_added) { |_| } if mutation == "suppressed"
  if mutation == "invokesuper"
    def mod.method_added(name)
      return if name == :link_to
      super
    end
  end
  patch.call
when "private"
  mod.send(:private, :link_to)
when "template"
  path = Rails.root.join("app/views/articles/index.html.erb")
  original = File.binread(path)
  at_exit { File.binwrite(path, original) }
  File.binwrite(path, original + "<!-- endpoint changed template -->")
  ArticlesController.view_paths.each(&:clear_cache)
  ActionView::LookupContext::DetailsKey.clear
when "filter"
  ArticlesController.before_action { response.set_header("x-added-filter", "once") }
when "locale"
  I18n.available_locales = (I18n.available_locales + [:fr]).uniq
  I18n.locale = :fr
when "subscriber", "warm_suppressed"
  applied = false
  subscriber = Object.new
  subscriber.define_singleton_method(:start) do |*|
    next if mutation == "warm_suppressed" && !armed
    unless applied
      applied = true
      mod.define_singleton_method(:method_added) { |_| } if mutation == "warm_suppressed"
      patch.call
    end
  end
  subscriber.define_singleton_method(:finish) { |*| }
  ActiveSupport::Notifications.subscribe("process_action.action_controller", subscriber)
when "render_subscriber"
  subscriber = Object.new
  subscriber.define_singleton_method(:start) do |*|
    ActiveSupport::ExecutionContext.to_h.fetch(:controller).response.set_header("x-render-observer", "live")
  end
  subscriber.define_singleton_method(:finish) { |*| }
  ActiveSupport::Notifications.subscribe("render_template.action_view", subscriber)
else
  raise "unknown mutation #{mutation}"
end

paths = %w[/articles /articles/1 /articles/2 /articles/3]
accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"
shapes = [{}, {"HTTP_ACCEPT" => accept}, {"HTTP_ACCEPT" => "text/html"},
  {"HTTP_ACCEPT" => "application/json"},
  {"HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36"}, {"QUERY_STRING" => "extra=1"}]
# Materialize all formats outside every comparison, symmetrically.
paths.product(shapes).each { |path, headers| request.call(path, headers, nil, false) }
if ENV["SEALED_RENDERER_STAGE"]
  require_relative "sealed_renderer"
  SealedRenderer.install(ENV.fetch("SEALED_RENDERER_STAGE")) if ENV.fetch("SEALED_RENDERER_ARM") == "on"
  paths.product(shapes).each { |path, headers| request.call(path, headers, nil, false) }
end
armed = true
responses = []
fixtures = %w[stock escaped empty]
fixtures << "empty_comments" if ENV["SEALED_RENDERER_STAGE"]
fixtures.each do |fixture|
  Article.transaction(requires_new: true) do
    if fixture == "escaped"
      Article.update_all(title: "literal <&\"' Ω", body: "line <&\"' Ω\n" * 30)
      Comment.update_all(commenter: "name <&\"' Ω", body: "comment <&\"' Ω")
    elsif fixture == "empty"
      Comment.delete_all
      Article.delete_all
    elsif fixture == "empty_comments"
      Comment.delete_all
    end
    first = request.call("/articles", {}, nil, false)
    cookie = first.fetch("headers").fetch("set-cookie").split(";").first
    paths.product(shapes, [nil, cookie]).each do |path, headers, input_cookie|
      responses << {"fixture" => fixture, "path" => path, "shape" => headers,
        "existing_session" => !!input_cookie, **request.call(path, headers, input_cookie)}
    end
    raise ActiveRecord::Rollback
  end
end
units = ENV["LOWRAIL"] == "1" ? Lowrail.manifest.units.select { _1["pass"] == "endpoint/action" } : []
endpoint_hits = units.to_h do |unit|
  [unit.fetch("target"), Lowrail::Stats.unit_hits.fetch(unit.fetch("id").to_s, 0)]
end
endpoint_fallbacks = units.to_h do |unit|
  [unit.fetch("target"), Lowrail::Stats.unit_fallbacks.fetch(unit.fetch("id").to_s, 0)]
end
File.write(destination, JSON.generate({responses: responses, endpoint_hits: endpoint_hits, endpoint_fallbacks: endpoint_fallbacks,
  specimen_hits: defined?(SealedRenderer) ? SealedRenderer.hits : 0,
  hits: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {},
  fallbacks: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_fallbacks : {}}))
