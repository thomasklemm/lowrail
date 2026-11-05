# frozen_string_literal: true

require "json"
require "net/http"
require "socket"

out = ARGV.fetch(0)
info = JSON.parse(File.read("#{out}.info"))
peer = UNIXSocket.new("#{out}.control")
batch = Integer(ENV.fetch("STACK_MAP_BATCH", "500"))
count = 0
Net::HTTP.start("127.0.0.1", info.fetch("port").to_i, nil) do |http|
  while peer.gets == "go\n"
    batch.times do
      response = http.get(info.fetch("path"), info.fetch("headers"))
      raise "HTTP #{response.code}" unless response.code == "200"
      raise "empty body" if response.body.empty?
      count += 1
    end
    peer.puts("done")
  end
end
peer.close
puts JSON.generate(requests: count, batch: batch)
