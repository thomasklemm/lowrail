# frozen_string_literal: true

# DEF8: per-request cost of the pieces a freshly generated Rails app runs by
# default. Run from a generated app's directory (see README.md):
#   bundle exec ruby [--yjit] harness.rb check|profile OUT|ips NAME|ir N [WORKLOAD...]
# DEF8_OFF=piece,piece switches pieces off (PIECES below); DEF8_ON=csp adds the
# commented-out CSP initializer with its nonce generator. DEF8_INTERP=1 keeps
# Rails from enabling YJIT after boot (production's config.yjit default).
ENV["RAILS_ENV"] = "production"
# Production logs to STDOUT; the formatting cost stays, the terminal write goes.
$out = $stdout.dup
$stdout.reopen(File::NULL)
require "./config/application"

module Def8
  OFF = ENV.fetch("DEF8_OFF", "").split(",").map(&:strip).reject(&:empty?)
  ON = ENV.fetch("DEF8_ON", "").split(",")
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  MIDDLEWARE = {
    "static" => "ActionDispatch::Static", "executor" => "ActionDispatch::Executor",
    "local_cache" => "ActiveSupport::Cache::Strategy::LocalCache::Middleware", "runtime" => "Rack::Runtime",
    "method_override" => "Rack::MethodOverride", "request_id" => "ActionDispatch::RequestId",
    "remote_ip" => "ActionDispatch::RemoteIp", "silence_request" => "Rails::Rack::SilenceRequest",
    "rack_logger" => "Rails::Rack::Logger", "show_exceptions" => "ActionDispatch::ShowExceptions",
    "debug_exceptions" => "ActionDispatch::DebugExceptions", "callbacks" => "ActionDispatch::Callbacks",
    "flash" => "ActionDispatch::Flash", "csp_middleware" => "ActionDispatch::ContentSecurityPolicy::Middleware",
    "head" => "Rack::Head", "conditional_get" => "Rack::ConditionalGet", "etag" => "Rack::ETag",
    "tempfile_reaper" => "Rack::TempfileReaper"
  }.freeze
  HELPERS = {
    "csrf_meta_tags" => "ActionView::Helpers::CsrfHelper", "csp_meta_tag" => "ActionView::Helpers::CspHelper",
    "javascript_importmap_tags" => "Importmap::ImportmapTagsHelper", "stylesheet_link_tag" => "Propshaft::Helper"
  }.freeze
  CALLBACKS = {
    "csrf" => %i[verify_authenticity_token verify_request_for_forgery_protection verify_same_origin_request
      append_sec_fetch_site_to_vary_header],
    "turbo_request_id" => %i[turbo_tracking_request_id]
  }.freeze
  PIECES = MIDDLEWARE.keys + HELPERS.keys + CALLBACKS.keys +
    %w[allow_browser importmap_freshness log_level log_tags structured_events notifications]
  (OFF - PIECES).each { |piece| abort "unknown piece #{piece}" }

  module MiddlewareFilter
    def build(...)
      names = OFF.filter_map { MIDDLEWARE[_1] }
      middlewares.reject! { |m| names.include?(m.klass.is_a?(Module) ? m.klass.name : m.klass.class.name) }
      super
    end
  end
  ActionDispatch::MiddlewareStack.prepend(MiddlewareFilter)

  app = Rails.application
  app.config.yjit = false if ENV["DEF8_INTERP"]
  app.config.log_tags = [] if OFF.include?("log_tags")
  if ON.include?("csp")
    app.config.content_security_policy do |policy|
      policy.default_src :self, :https
      policy.font_src :self, :https, :data
      policy.img_src :self, :https, :data
      policy.object_src :none
      policy.script_src :self, :https
      policy.style_src :self, :https
    end
    app.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
    app.config.content_security_policy_nonce_directives = %w[script-src style-src]
  end
  if OFF.include?("allow_browser")
    ActionController::AllowBrowser::ClassMethods.prepend(Module.new { def allow_browser(**) = nil })
  end
  if OFF.include?("importmap_freshness")
    app.config.to_prepare { Importmap::Freshness.prepend(Module.new { def stale_when_importmap_changes = nil }) }
  end
  app.config.after_initialize do
    HELPERS.each do |helper, owner|
      next unless OFF.include?(helper)
      Object.const_get(owner).prepend(Module.new { define_method(helper) { |*| nil } })
    end
    callbacks = OFF.flat_map { CALLBACKS.fetch(_1, []) }
    ActionController::Base.descendants.each do |controller|
      callbacks.each do |name|
        %i[before after around].each { |kind| controller.skip_callback(:process_action, kind, name, raise: false) }
      end
    end
    Rails.logger.level = :fatal if OFF.include?("log_level")
    if OFF.include?("structured_events")
      Rails.event.instance_variable_get(:@subscribers).clear
    end
    if OFF.include?("notifications")
      notifier = ActiveSupport::Notifications.notifier
      registry = notifier.instance_variable_get(:@registry)
      registry.instance_variable_get(:@string_subscribers).keys.each { notifier.unsubscribe(_1) }
      registry.instance_variable_get(:@other_subscribers).each { notifier.unsubscribe(_1) }
    end
  end
end

require "./config/environment"

module Def8
  API = !ActionController::Base.descendants.any? { _1.name == "PostsController" }
  POST_FIELDS = {
    title: "Post 1: notes on building small apps", body: "A paragraph of body text for post 1. " * 12,
    summary: "Summary of post 1.", author_name: "Author 0", author_email: "author0@example.com", slug: "post-1",
    category: "news", tags: "rails,ruby,web", status: "published", published: "1", featured: "1",
    published_at: "2026-10-01T00:00", views_count: "0", rating: "4.5", word_count: "1200", reading_time: "6",
    cover_url: "https://example.com/covers/1.jpg", language: "en", location: "Berlin", notes: "Internal notes for post 1."
  }.freeze

  # One cookie jar for every workload, so a session cookie set by the update
  # is sent with the pages that follow, as for a returning visitor.
  class Client
    def initialize(transport)
      @transport = transport
      @cookies = {}
    end

    def request(verb, path, body: nil, headers: {})
      env = { "HTTP_USER_AGENT" => UA, "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ACCEPT_ENCODING" => "gzip",
        "HTTP_ACCEPT" => API ? "application/json" : "text/html,application/xhtml+xml" }.merge(headers)
      env["HTTP_COOKIE"] = @cookies.map { "#{_1}=#{_2}" }.join("; ") unless @cookies.empty?
      status, set_cookie, out = @transport.call(verb, path, env, body)
      Array(set_cookie).flat_map { _1.split("\n") }.each do |line|
        key, value = line.split(";", 2).first.split("=", 2)
        @cookies[key] = value
      end
      [status, out]
    end
  end

  module InProcess
    module_function

    def call(verb, path, env, body)
      env = Rack::MockRequest.env_for("https://localhost#{path}", env.merge(method: verb.to_s.upcase, input: body.to_s, "REMOTE_ADDR" => "127.0.0.1"))
      env["CONTENT_TYPE"] ||= "application/x-www-form-urlencoded" if body
      status, headers, rack_body = Rails.application.call(env)
      out = +""
      rack_body.each { out << _1 }
      rack_body.close if rack_body.respond_to?(:close)
      [status, headers["set-cookie"], out]
    end
  end

  class Socket
    def initialize(port) = @port = port

    def call(verb, path, env, body)
      body = body.to_s
      lines = ["#{verb.to_s.upcase} #{path} HTTP/1.1", "Host: localhost", "X-Forwarded-Proto: https"]
      env.each do |key, value|
        name = key == "CONTENT_TYPE" ? "Content-Type" : key.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-")
        lines << "#{name}: #{value}"
      end
      lines << "Content-Type: application/x-www-form-urlencoded" if body != "" && !env.key?("CONTENT_TYPE")
      lines << "Content-Length: #{body.bytesize}" unless body.empty?
      payload = lines.join("\r\n") << "\r\n\r\n" << body
      status_line = begin
        connect.write(payload)
        @socket.gets("\r\n") or raise EOFError
      rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
        @socket = nil
        connect.write(payload)
        @socket.gets("\r\n")
      end
      status = Integer(status_line.split(" ", 3)[1])
      headers = {}
      cookies = []
      while (line = @socket.gets("\r\n")) != "\r\n"
        name, value = line.chomp("\r\n").split(": ", 2)
        name = name.downcase
        cookies << value if name == "set-cookie"
        headers[name] = value
      end
      out = if headers["transfer-encoding"]&.include?("chunked")
        +"".tap do |buffer|
          while (size = Integer(@socket.gets("\r\n"), 16)) > 0
            buffer << @socket.read(size)
            @socket.read(2)
          end
          @socket.gets("\r\n")
        end
      else
        @socket.read(Integer(headers.fetch("content-length", "0")))
      end
      @socket = nil if headers["connection"]&.casecmp?("close")
      [status, cookies, out]
    end

    def connect
      @socket ||= TCPSocket.new("127.0.0.1", @port).tap { _1.setsockopt(::Socket::IPPROTO_TCP, ::Socket::TCP_NODELAY, 1) }
    end
  end

  def self.workloads(client)
    form = Rack::Utils.build_nested_query(post: POST_FIELDS)
    json = { "CONTENT_TYPE" => "application/json" }
    w = {
      "home" => -> { client.request(:get, "/home") },
      "up" => -> { client.request(:get, "/up") },
      "index" => -> { client.request(:get, "/posts") },
      "show" => -> { client.request(:get, "/posts/1") }
    }
    if API
      w["update"] = -> { client.request(:patch, "/posts/1", body: JSON.generate(post: POST_FIELDS), headers: json) }
    else
      w["new"] = -> { client.request(:get, "/posts/new") }
      w["update"] = -> { client.request(:patch, "/posts/1", body: form) }
    end
    expect = Hash.new(200).merge("update" => API ? 200 : 303)
    w.to_h do |name, op|
      [name, -> { op.call.tap { |status, _| raise "#{name}: HTTP #{status}" unless status == expect[name] } }]
    end
  end

  def self.select(ops, names) = names.empty? ? ops : ops.slice(*names).tap { raise "unknown workload" if _1.size != names.size }

  def self.start_puma
    require "puma"
    require "puma/server"
    server = Puma::Server.new(Rails.application, nil, min_threads: 1, max_threads: 1, log_writer: Puma::LogWriter.null)
    port = server.add_tcp_listener("127.0.0.1", 0).addr[1]
    server.run
    [server, port]
  end
end

command, *args = ARGV
case command
when "check"
  $stdout = $out
  ops = Def8.workloads(Def8::Client.new(Def8::InProcess))
  ops.each { |name, op| op.call; status, body = op.call; puts "#{name} #{status} #{body.bytesize}B" }
  puts "off=#{Def8::OFF.join(",")} api=#{Def8::API} yjit=#{RubyVM::YJIT.enabled?} log=#{Rails.logger.level}"
  puts Rails.application.middleware.map { _1.klass.is_a?(Module) ? _1.klass.name : _1.klass.class.name }.join(" ")
  ctrl = Def8::API ? PostsController : ApplicationController
  puts ctrl.__callbacks[:process_action].map { "#{_1.kind}:#{_1.filter.is_a?(Proc) ? _1.filter.source_location.join(":") : _1.filter}" }.join(" ")
  notifier = ActiveSupport::Notifications.notifier
  registry = notifier.instance_variable_get(:@registry)
  subs = registry.instance_variable_get(:@string_subscribers).transform_values(&:size)
  puts subs.sort_by { -_2 }.map { "#{_1}=#{_2}" }.join(" ")
  puts "subscribers: #{subs.values.sum} on #{subs.size} names; event subscribers: #{Rails.event.instance_variable_get(:@subscribers).size}"
when "dump"
  ops = Def8.workloads(Def8::Client.new(Def8::InProcess))
  ops.each { |name, op| op.call; File.write("tmp/def8-#{name}.html", op.call.last) }
when "ir"
  # Callgrind windows: run under valgrind with --toggle-collect=rb_ary_cycle and
  # --dump-after=rb_ary_cycle, so each workload's N requests are one dump.
  n = Integer(args.shift)
  ops = Def8.select(Def8.workloads(Def8::Client.new(Def8::InProcess)), args)
  Integer(ENV.fetch("DEF8_WARMUP", "100")).times { ops.each_value(&:call) }
  jit = -> { RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
  ops.each do |name, op|
    op.call
    GC.start
    GC.disable
    before = [jit.call, GC.stat(:total_allocated_objects)]
    [op].cycle(n, &:call)
    after = [jit.call, GC.stat(:total_allocated_objects)]
    GC.enable
    warn "DEF8 #{name} compiled_blocks=#{after[0] - before[0]} objects=#{after[1] - before[1]}"
  end
when "ips"
  require "benchmark/ips"
  ops = Def8.select(Def8.workloads(Def8::Client.new(Def8::InProcess)), args.drop(1))
  label = args.first
  $stdout = $out
  Benchmark.ips do |x|
    x.config(warmup: Float(ENV.fetch("DEF8_IPS_WARMUP", "3")), time: Float(ENV.fetch("DEF8_IPS_TIME", "5")))
    ops.each { |name, op| x.report("#{label} #{name}", &op) }
  end
when "profile"
  require "vernier"
  output = args.shift
  server, port = Def8.start_puma
  ops = Def8.select(Def8.workloads(Def8::Client.new(Def8::Socket.new(port))), args)
  warmup = Integer(ENV.fetch("DEF8_WARMUP", "200"))
  requests = Integer(ENV.fetch("DEF8_REQUESTS", "1000"))
  warmup.times { ops.each_value(&:call) }
  GC.start
  windows = []
  result = Vernier.profile(mode: :wall, interval: 200) do
    ops.each do |name, op|
      w = { name: name, start: Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond), gc_ns: GC.total_time,
        objects: GC.stat(:total_allocated_objects) }
      requests.times { op.call }
      w[:stop] = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
      w[:gc_ns] = GC.total_time - w[:gc_ns]
      w[:objects] = (GC.stat(:total_allocated_objects) - w[:objects]) / requests
      windows << w
    end
  end
  server.stop(true)
  threads = result.threads.values.select { _1[:name].to_s.include?("puma srv tp") }
  stacks = {}
  samples = threads.flat_map do |t|
    t[:samples].each_with_index.filter_map do |stack_idx, i|
      ts = t[:timestamps][i]
      w = windows.index { ts >= _1[:start] && ts < _1[:stop] } or next
      stacks[stack_idx] ||= result.stack(stack_idx).frames.map { |f| f.label.to_s }
      [stack_idx, w, t[:weights][i]]
    end
  end
  File.write(output, JSON.generate(ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, off: Def8::OFF, api: Def8::API,
    requests: requests, interval_us: 200, windows: windows, samples: samples, stacks: stacks,
    middleware: Rails.application.middleware.map { _1.klass.is_a?(Module) ? _1.klass.name : _1.klass.class.name }))
  $out.puts "#{output}: #{samples.sum(&:last)} samples"
else
  abort "usage: harness.rb check|dump|ir N|ips LABEL|profile OUT [WORKLOAD...]"
end
