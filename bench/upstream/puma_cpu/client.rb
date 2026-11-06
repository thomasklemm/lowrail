# frozen_string_literal: true

require "socket"
require "json"
require "digest"

out = ARGV.fetch(0)
info = JSON.parse(File.read("#{out}.info"))
peer = UNIXSocket.new(info.fetch("control"))
clients = Integer(ENV.fetch("PUMA_THREADS"))
rate = Float(ENV.fetch("PUMA_RATE"))
fresh = ENV.fetch("PUMA_CONNECTION") == "fresh"
fingerprints = []
windows = []
while (line = peer.gets)
  if line.start_with?("detach ")
    raise "strace detach failed" unless system("sudo", "kill", "-INT", Integer(line.split.fetch(1)).to_s)
    peer.puts("detached")
    next
  end
  break unless line.start_with?("go ")
  count = Integer(line.split.fetch(1))
  measured = line.split.last == "true"
  lagged = 0
  threads = clients.times.map do |index|
    Thread.new do
      socket = nil
      buffer = +"".b
      request = "GET #{info.fetch('path')} HTTP/1.1\r\nHost: localhost\r\nX-Forwarded-Proto: https\r\nAccept: text/html\r\nConnection: #{fresh ? 'close' : 'keep-alive'}\r\n\r\n"
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      index.step(count - 1, clients) do |i|
        if measured
          delay = start + i / rate - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          delay > 0 ? sleep(delay) : lagged += 1
        end
        socket ||= TCPSocket.new("127.0.0.1", Integer(info.fetch("port")))
        socket.write(request)
        buffer << socket.readpartial(65_536) until buffer.include?("\r\n\r\n")
        header, buffer = buffer.split("\r\n\r\n", 2)
        raise "bad status: #{header}" unless header.start_with?("HTTP/1.1 200 ")
        length = header[/^content-length: (\d+)\r?$/i, 1]
        raise "missing length" unless length
        length = Integer(length)
        buffer << socket.readpartial(65_536) while buffer.bytesize < length
        body, buffer = buffer.byteslice(0, length), buffer.byteslice(length..)
        raise "empty body" if body.empty?
        fingerprints[index] = Digest::SHA256.hexdigest(body)
        if fresh || header.match?(/^connection: close\r?$/i)
          socket.close
          socket = nil
        end
      end
      socket&.close
    end
  end
  threads.each(&:value)
  windows << { count: count, measured: measured, lagged: lagged } if measured
  peer.puts("done")
end
peer.close
File.write("#{out}.client", JSON.pretty_generate(rate: rate, connections: fresh ? "fresh" : "keep-alive",
  clients: clients, body_sha256: fingerprints, windows: windows))
