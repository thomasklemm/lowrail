# usage: ruby -I LIB tbench.rb  -> one line per case: best ns/call of ROUNDS rounds after warmup
require "uri"
KEY = "article%5Btitle%5D"
VALUE = "Hello+world+from+Rack"
COOKIE = "#{"A" * 200}--#{"b" * 40}%3D%3D"
USER = "user%40example.com"
PLAIN16K = "a" * 16384
DENSE16K = "%E3%81%82" * (16384 / 9)
CASES = {
  "hello" => -> { URI.decode_www_form_component("hello") },
  "form key" => -> { URI.decode_www_form_component(KEY) },
  "form value" => -> { URI.decode_www_form_component(VALUE) },
  "cookie" => -> { URI.decode_www_form_component(COOKIE) },
  "plain 16 KiB" => -> { URI.decode_www_form_component(PLAIN16K) },
  "dense 16 KiB" => -> { URI.decode_www_form_component(DENSE16K) },
  "uri hello" => -> { URI.decode_uri_component("hello") },
  "uri user" => -> { URI.decode_uri_component(USER) },
  "uri plain 16 KiB" => -> { URI.decode_uri_component(PLAIN16K) },
  "uri dense 16 KiB" => -> { URI.decode_uri_component(DENSE16K) },
}
$bytes = 0
warm = Float(ENV.fetch("WARM", "2")); rounds = Integer(ENV.fetch("ROUNDS", "7")); win = Float(ENV.fetch("WIN", "0.3"))
now = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
CASES.each do |name, fn|
  t = now.(); n = 0
  while now.() - t < warm; 100.times { $sink = fn.call }; n += 100; end
  per = n / warm
  iters = [(per * win).to_i, 10].max
  best = Float::INFINITY
  rounds.times do
    t0 = now.(); i = 0
    while i < iters; $sink = fn.call; $bytes += $sink.bytesize; i += 1; end
    d = (now.() - t0) / iters
    best = d if d < best
  end
  puts "#{name}\t#{(best * 1e9).round(1)}"
end
puts "checksum\t#{$bytes % 1000}"
