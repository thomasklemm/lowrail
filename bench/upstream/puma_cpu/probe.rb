# frozen_string_literal: true

require "socket"
require "timeout"
require "json"
require "digest"
require "rack/headers"
require "objspace"
source = File.expand_path(ARGV.fetch(0))
$LOAD_PATH.unshift File.join(source, "lib")
require "puma"
require "puma/server"
raise "mixed Puma sources" unless $LOADED_FEATURES.grep(%r{/puma(?:/.*)?\.(?:rb|so)\z/}).all? { _1.start_with?(source + "/") }

results = {}
observed = Queue.new
body_closed = Queue.new
fibers = Queue.new
backpressure_finished = Queue.new
application = ->(env) do
  observed << { size: env.size, bytes: ObjectSpace.memsize_of(env), keys_frozen: env.keys.all?(&:frozen?),
    method_frozen: env["REQUEST_METHOD"].frozen?, protocol_frozen: env["SERVER_PROTOCOL"].frozen? }
  case env["PATH_INFO"]
  when "/headers"
    [200, Rack::Headers["X-Mixed" => "left\nright", "set-cookie" => ["a=1", "b=2"],
      "x-empty" => "", "x-invalid\r" => "omit", "x-bad-value" => "bad\rvalue"], ["Ab7"]]
  when "/stream"
    stream = Object.new
    stream.define_singleton_method(:each) { |&block| ["Ab", "", "7!"].each(&block) }
    stream.define_singleton_method(:close) { body_closed << true }
    [200, { "content-type" => "text/plain" }, stream]
  when "/partial"
    [200, { "rack.hijack" => ->(io) { io.write("hijacked"); io.close } }, []]
  when "/full"
    io = env["rack.hijack"].call
    io.write("HTTP/1.1 200 OK\r\ncontent-length: 4\r\nconnection: close\r\n\r\nFULL")
    io.close
    [-1, {}, []]
  when "/raise"
    raise "probe error"
  when "/echo"
    [200, {}, [env["rack.input"].read]]
  when "/backpressure"
    env.fetch("puma.socket").setsockopt(Socket::SOL_SOCKET, Socket::SO_SNDBUF, 4096)
    env.fetch("rack.after_reply") << -> { backpressure_finished << true }
    [200, { "content-length" => "1048576" }, ["Ab7!" * 262_144]]
  when "/fiber"
    fibers << Fiber.current
    Fiber[:probe] = env.fetch("QUERY_STRING")
    sleep 0.01
    [200, {}, [Fiber[:probe]]]
  else
    [200, { "X-Asymmetric" => "A7b" }, ["fixed-body"]]
  end
end
server = Puma::Server.new(application, nil, min_threads: 4, max_threads: 4,
  first_data_timeout: 0.2, persistent_timeout: 0.2, fiber_per_request: true,
  lowlevel_error_handler: ->(_error, _env, status) { [status, {}, ["failed"]] })
server.add_tcp_listener("127.0.0.1", 0)
port = server.connected_ports.first
server.run
request = ->(path = "/", version = "1.1", connection = "close") do
  "GET #{path} HTTP/#{version}\r\nHost: local.test:5432\r\nConnection: #{connection}\r\n\r\n"
end
exchange = ->(parts, pause = 0) do
  Timeout.timeout(5) do
    socket = TCPSocket.new("127.0.0.1", port)
    parts.each { |part| socket.write(part); sleep(pause) if pause.positive? }
    bytes = socket.read
    socket.close
    bytes
  end
end
check = ->(name, condition) { raise name unless condition; results[name] = true }
begin
  normal = exchange.call([request.call])
  check.call("fixed bytes and close", normal == "HTTP/1.1 200 OK\r\nx-asymmetric: A7b\r\nconnection: close\r\ncontent-length: 10\r\n\r\nfixed-body")
  check.call("HTTP/1.0 close", exchange.call([request.call("/", "1.0")]).start_with?("HTTP/1.0 200 OK\r\n"))
  pipeline = exchange.call([request.call("/", "1.1", "keep-alive") + request.call])
  check.call("pipelined requests", pipeline.scan("HTTP/1.1 200 OK").size == 2 && pipeline.scan("fixed-body").size == 2)
  pipeline10 = exchange.call([request.call("/", "1.0", "keep-alive") + request.call("/", "1.0")])
  check.call("HTTP/1.0 keep-alive", pipeline10.scan("HTTP/1.0 200 OK").size == 2 && pipeline10.include?("connection: keep-alive\r\n"))
  tokens = request.call.sub("Connection: close", "Connection: Keep-Alive, ClOsE")
  results["connection-list requests served"] = exchange.call([tokens + request.call]).scan("HTTP/1.1 200 OK").size
  slow = request.call
  check.call("slow header fragments", exchange.call([slow[0, 13], slow[13..]], 0.01) == normal)
  timed_out = exchange.call(["GET / HTTP/1.1\r\nHost: local.test\r\n"])
  check.call("incomplete header timeout closes silently", timed_out.empty?)
  timed_out_body = exchange.call(["POST /echo HTTP/1.1\r\nHost: local.test\r\nContent-Length: 3\r\n\r\na"])
  check.call("incomplete body timeout sends 408", timed_out_body.start_with?("HTTP/1.1 408"))
  Timeout.timeout(Puma::Const::WRITE_TIMEOUT + 5) do
    socket = Socket.new(:INET, :STREAM)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 4096)
    socket.connect(Socket.sockaddr_in(port, "127.0.0.1"))
    socket.write(request.call("/backpressure"))
    backpressure_finished.pop
    bytes = socket.read
    socket.close
    check.call("slow reader write timeout closes partial response", bytes.start_with?("HTTP/1.1 200 OK\r\n") &&
      bytes.split("\r\n\r\n", 2).last.bytesize < 1_048_576)
  end
  huge = request.call.sub("\r\n\r\n", "\r\nX-Large:#{'h' * 81_920}\r\n\r\n")
  check.call("80 KiB value boundary", exchange.call([huge]).include?("fixed-body"))
  check.call("oversize header rejected", exchange.call([huge.sub("h\r\n\r\n", "hh\r\n\r\n")]).start_with?("HTTP/1.1 400"))
  head = exchange.call([request.call.sub("GET", "HEAD")])
  check.call("HEAD has length but no body", head.end_with?("content-length: 10\r\n\r\n"))
  headers = exchange.call([request.call("/headers")])
  check.call("Rack::Headers and newline values", headers.include?("x-mixed: left\r\nx-mixed: right\r\nset-cookie: a=1\r\nset-cookie: b=2\r\nx-empty: \r\n"))
  check.call("invalid response headers omitted", !headers.include?("x-invalid") && !headers.include?("x-bad-value"))
  stream = exchange.call([request.call("/stream")])
  check.call("chunk bytes", stream.end_with?("\r\n\r\n2\r\nAb\r\n2\r\n7!\r\n0\r\n\r\n"))
  check.call("stream close", body_closed.pop)
  stream10 = exchange.call([request.call("/stream", "1.0")])
  check.call("HTTP/1.0 unframed stream closes", stream10.end_with?("\r\n\r\nAb7!") && !stream10.include?("transfer-encoding"))
  check.call("full hijack", exchange.call([request.call("/full")]).end_with?("\r\n\r\nFULL"))
  check.call("partial hijack", exchange.call([request.call("/partial")]).end_with?("\r\n\r\nhijacked"))
  check.call("app error", exchange.call([request.call("/raise")]).end_with?("\r\n\r\nfailed"))
  payload = "POST /echo HTTP/1.1\r\nHost: local.test\r\nConnection: close\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nAb7\r\n0\r\n\r\n"
  check.call("chunked request", exchange.call([payload]).end_with?("\r\n\r\nAb7"))
  fiber_results = 8.times.map do |index|
    Thread.new do
      value = "v=#{index}A"
      exchange.call([request.call("/fiber?#{value}")]).end_with?("\r\n\r\n#{value}")
    end
  end.map(&:value)
  check.call("fiber requests on multiple threads", fiber_results.all? && 8.times.map { fibers.pop }.uniq.size == 8)
  results["normal wire sha256"] = Digest::SHA256.hexdigest(normal)
  results["headers wire sha256"] = Digest::SHA256.hexdigest(headers)
  results["env"] = observed.pop
  puts JSON.pretty_generate(puma: Puma::Const::PUMA_VERSION,
    source: IO.popen(["git", "-C", source, "rev-parse", "HEAD"], &:read).strip, checks: results)
ensure
  server.stop(true)
end
