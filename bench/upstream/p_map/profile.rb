# frozen_string_literal: true

# P-MAP: whole-request profiles through a real Puma server, run inside a census
# copy (bench/upstream/p_map/hx CORPUS APP bundle exec ruby --yjit THIS ...):
#   seed APP           heavier data for index pages and JSON lists (once per copy)
#   profile APP OUT    Vernier wall-mode profile of every request workload
# The census harness boots the app in production (RailsCensus.boot). Requests go
# over TCP to Puma 8 in this process (one worker thread, keep-alive) from a
# raw-socket client thread, so Puma, Rack and every middleware run. Only Puma's
# threads are mapped; the client's own samples are left out.
require_relative "../census/harness"

module PMap
  VERNIER = ENV.fetch("PMAP_VERNIER") { File.expand_path("../../../.lowrail/private/pmap/gems/gems/vernier-1.12.0/lib", __dir__) }
  INTERVAL_US = Integer(ENV.fetch("PMAP_INTERVAL_US", "500"))
  WARMUP = Integer(ENV.fetch("PMAP_WARMUP", "60"))
  REQUESTS = Integer(ENV.fetch("PMAP_REQUESTS", "200"))
  REQUEST_KINDS = %i[html json form turbo].freeze

  # Minimal HTTP/1.1 client over one keep-alive socket, with the census
  # client's interface (get/post/..., cookie, csrf). It takes Rack env-style
  # headers like RailsMainCensus4::Client and encodes params as Rack::Test does.
  class Client
    Response = Struct.new(:status, :headers, :body)
    attr_reader :last

    def initialize(headers = {})
      @headers = { "HTTP_USER_AGENT" => RailsMainCensus4::UA, "HTTP_ACCEPT" => "text/html",
        "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://localhost",
        "HTTP_X_FORWARDED_PROTO" => "https", "HTTP_X_FORWARDED_SSL" => "on" }.merge(headers)
      @cookies = {}
    end

    class << self
      attr_accessor :port
    end

    def cookie(name, value) = @cookies[name.to_s] = value

    def request(verb, path, params: {}, headers: {}, expect: [200], body: nil)
      env = @headers.merge(headers)
      env.delete("HTTPS")
      body = env.delete(:input) || body
      if body.nil? && !params.empty?
        query = Rack::Utils.build_nested_query(params)
        if verb == :get
          path = "#{path}#{path.include?("?") ? "&" : "?"}#{query}"
        else
          body = query
          env["CONTENT_TYPE"] ||= "application/x-www-form-urlencoded"
        end
      end
      body = body.to_s
      lines = ["#{verb.to_s.upcase} #{path} HTTP/1.1", "Host: localhost"]
      env.each do |key, value|
        name = key == "CONTENT_TYPE" ? "Content-Type" : key.start_with?("HTTP_") ? key.delete_prefix("HTTP_").split("_").map(&:capitalize).join("-") : next
        lines << "#{name}: #{value}"
      end
      lines << "Cookie: #{@cookies.map { "#{_1}=#{_2}" }.join("; ")}" unless @cookies.empty?
      lines << "Content-Length: #{body.bytesize}" unless verb == :get && body.empty?
      payload = lines.join("\r\n") << "\r\n\r\n" << body
      @last = exchange(payload) || exchange(payload, reconnect: true) || raise("#{verb} #{path}: connection closed")
      unless Array(expect).include?(@last.status)
        raise "#{verb} #{path}: HTTP #{@last.status} (expected #{expect.inspect}): #{@last.body.to_s[0, 300]}"
      end
      raise "#{verb} #{path}: empty body" if @last.status == 200 && @last.body.empty? && verb == :get
      @last
    end

    %i[get post patch put delete].each do |verb|
      define_method(verb) { |path, **kw| request(verb, path, **kw) }
    end

    def csrf(path, required: true)
      body = get(path).body
      body[/<meta name="csrf-token" content="([^"]+)"/, 1] || (required ? raise("no csrf-token on #{path}") : nil)
    end

    private

    def exchange(payload, reconnect: false)
      @socket = nil if reconnect
      @socket ||= TCPSocket.new("127.0.0.1", self.class.port).tap { _1.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) }
      @socket.write(payload)
      status_line = @socket.gets("\r\n") or return (@socket = nil)
      status = Integer(status_line.split(" ", 3)[1])
      headers = {}
      while (line = @socket.gets("\r\n")) && line != "\r\n"
        name, value = line.chomp("\r\n").split(": ", 2)
        name = name.downcase
        if name == "set-cookie"
          pair = value.split(";", 2).first
          key, val = pair.split("=", 2)
          if val.to_s.empty? || value.match?(/max-age=0|expires=Thu, 01 Jan 1970/i) then @cookies.delete(key) else @cookies[key] = val end
        end
        headers[name] = headers.key?(name) ? "#{headers[name]}\n#{value}" : value
      end
      body = if headers["transfer-encoding"]&.include?("chunked")
        out = +""
        while (size = Integer(@socket.gets("\r\n"), 16)) > 0
          out << @socket.read(size)
          @socket.read(2)
        end
        @socket.gets("\r\n")
        out
      elsif (length = headers["content-length"])
        @socket.read(Integer(length))
      else
        ""
      end
      @socket = nil if headers["connection"]&.casecmp?("close")
      Response.new(status, headers, body)
    end
  end

  module_function

  def seed(name)
    marker = "tmp/pmap-seed.json"
    raise "already seeded" if File.exist?(marker)
    counts = case name
    when "blog"
      # The census copy has 3 articles; /articles and /articles.json list all.
      (Article.count...100).each do |i|
        article = Article.create!(title: "Census article #{i}", body: "Census article body #{i}. " * 6)
        2.times { |j| article.comments.create!(commenter: "Reader #{j}", body: "Census comment #{j} on article #{i}.") }
      end
      { articles: Article.count, comments: Comment.count }
    when "campfire"
      # GET room shows the last page (40 messages).
      room = Room.find_by!(name: "All Talk")
      users = room.users.order(:id).to_a
      120.times { |i| room.messages.create!(creator: users[i % users.size], body: "Census room message #{i} about coffee and code") }
      { messages: room.messages.count }
    when "fizzy"
      # Geared pagination serves 15, 30, 50, then 100 cards per page;
      # page 4 of the card index holds 100 cards.
      identity = Identity.find_by!(email_address: "kevin@37signals.com")
      user = identity.users.find_by!(name: "Kevin")
      board = user.account.boards.find_by!(name: "Writebook")
      Current.set(account: user.account, user: user) do
        200.times { |i| board.cards.create!(title: "Census card #{i}", creator: user, status: "published") }
      end
      { cards: board.cards.count }
    else
      {}
    end
    File.write(marker, JSON.generate(counts))
    puts JSON.generate(counts)
  end

  # Heavier pages than the census set: list pages and JSON lists near 100 records.
  def extra_ops(name, c, ops)
    w = Census4Workloads
    case name
    when "fizzy"
      scope = ops.find { _1.name == "GET cards.json" }.call.binding
      client, prefix = scope.local_variable_get(:client), scope.local_variable_get(:prefix)
      [w.html(c, client, "GET cards page 4 (100)", "#{prefix}/cards?page=4"),
        w.op(c, "GET cards.json page 4 (100)", :json) { client.get("#{prefix}/cards.json?page=4", headers: w.json_headers) }]
    when "mastodon"
      scope = ops.find { _1.name == "GET home timeline" }.call.binding
      client, api = scope.local_variable_get(:client), scope.local_variable_get(:api)
      [w.op(c, "GET home timeline (40)", :json) { client.get("/api/v1/timelines/home?limit=40", headers: api) },
        w.op(c, "GET public timeline (40)", :json) { client.get("/api/v1/timelines/public?local=true&limit=40", headers: api) }]
    else
      []
    end
  end

  def mono_ns = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)

  def yjit_counters
    return {} unless RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats.slice(:compile_time_ns, :compiled_block_count, :compiled_iseq_count, :invalidation_count)
  end

  def start_puma
    require "puma"
    require "puma/server"
    app, = Rack::Builder.parse_file("config.ru")
    server = Puma::Server.new(app, nil, min_threads: 1, max_threads: 1, log_writer: Puma::LogWriter.null)
    listener = server.add_tcp_listener("127.0.0.1", 0)
    Client.port = listener.addr[1]
    server.run
    server
  end

  def profile(name, output)
    raise "fresh output required" if File.exist?(output)
    $LOAD_PATH.unshift(VERNIER)
    require "vernier"
    RailsCensus.const_set(:Client, Client)
    # PMAP_LOG_LEVEL=info: production's default log level instead of the
    # census's fatal; the log goes to /dev/null (the app logs to STDOUT).
    if (level = ENV["PMAP_LOG_LEVEL"])
      $stdout.reopen(File::NULL)
      Rails.logger.level = level
    end
    server = start_puma
    ops = RailsCensus.workloads(name)
    ops += extra_ops(name, RailsCensus, ops)
    ops = ops.select { REQUEST_KINDS.include?(_1.kind) }
    only = ENV["PMAP_ONLY"]&.split(",")
    ops = ops.select { only.include?(_1.name) } if only
    reset = -> { RailsCensus.reset_side_effects }
    ops.each { |op| WARMUP.times { op.call.call; reset.call } }
    GC.start
    windows = []
    jit_before = yjit_counters
    gc_before = GC.stat.slice(:count, :minor_gc_count, :major_gc_count, :total_allocated_objects)
    gc_time_before = GC.total_time
    started = mono_ns
    result = Vernier.profile(mode: :wall, interval: INTERVAL_US) do
      ops.each do |op|
        w = { name: op.name, kind: op.kind, requests: REQUESTS, start_ns: mono_ns, gc_ns: GC.total_time,
          gc_count: GC.count, allocated: GC.stat(:total_allocated_objects), jit: yjit_counters }
        REQUESTS.times { op.call.call; reset.call }
        w[:stop_ns] = mono_ns
        w[:gc_ns] = GC.total_time - w[:gc_ns]
        w[:gc_count] = GC.count - w[:gc_count]
        w[:allocated] = GC.stat(:total_allocated_objects) - w[:allocated]
        jit = yjit_counters
        w[:jit] = jit.to_h { |k, v| [k, v - w[:jit].fetch(k, 0)] }
        windows << w
      end
    end
    stopped = mono_ns
    server.stop(true)
    gc_after = GC.stat.slice(*gc_before.keys)
    jit_after = yjit_counters
    threads = result.threads.values.map do |t|
      stacks = Hash.new(0)
      t[:samples].each_with_index do |stack_idx, i|
        stacks[[stack_idx, t[:sample_categories][i], window_index(windows, t[:timestamps][i])]] += t[:weights][i]
      end
      { name: t[:name], samples: stacks.map { |(s, cat, w), n| [s, cat, w, n] } }
    end
    used = threads.flat_map { _1[:samples].map(&:first) }.uniq
    frame_ids = {}
    stacks = used.to_h do |s|
      [s, result.stack(s).frames.map { |f| frame_ids[[f.label, f.filename, (f.lineno rescue 0)]] ||= frame_ids.size }]
    end
    gc_pauses = (result.gc_markers || []).filter_map { |m| [m[2], m[3]] if m[0] == Vernier::Marker::Type::GC_PAUSE && m[3] }
    File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, rails: RailsCensus.rails_sha,
      adapter: ActiveRecord::Base.connection_db_config.adapter, puma: Puma::Const::PUMA_VERSION, rack: Rack.release,
      interval_us: INTERVAL_US, warmup: WARMUP, requests_per_workload: REQUESTS, elapsed_ns: stopped - started,
      gc_ns: GC.total_time - gc_time_before, gc: gc_after.to_h { |k, v| [k, v - gc_before[k]] },
      jit: jit_after.to_h { |k, v| [k, v - jit_before.fetch(k, 0)] }, windows: windows, threads: threads,
      stacks: stacks, frames: frame_ids.keys, gc_pauses: gc_pauses, pid: Process.pid))
    puts JSON.generate(app: name, workloads: windows.size, samples: threads.sum { |t| t[:samples].sum(&:last) })
  end

  def window_index(windows, ts)
    windows.index { ts >= _1[:start_ns] && ts < _1[:stop_ns] }
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsCensus.boot(name)
  case command
  when "seed" then PMap.seed(name)
  when "profile" then PMap.profile(name, output)
  else abort "usage: profile.rb seed|profile APP [OUT_JSON]"
  end
end
