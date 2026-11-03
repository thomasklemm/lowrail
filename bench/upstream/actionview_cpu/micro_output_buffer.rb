# frozen_string_literal: true

# Per-call cost of ActionView::OutputBuffer#<< (what `<%= %>` compiles to,
# through its append= alias), run once per Rails variant bundle:
#   BUNDLE_GEMFILE=.../Gemfile.main-a ruby [--yjit] micro_output_buffer.rb
# Best of 7 runs of N appends, in ns per call; a fresh buffer every 500
# appends keeps the buffer small. GC runs normally (the escaped and unchanged
# cases allocate nothing new per call except an escaped copy).
require "bundler/setup"
require "action_view"

N = Integer(ENV.fetch("N", "1000000"))

def measure(value)
  7.times.map do
    buf = ActionView::OutputBuffer.new
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    i = 0
    while i < N
      buf.append = value
      i += 1
      buf = ActionView::OutputBuffer.new if i % 500 == 0
    end
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  end.min * 1e9 / N
end

{ "unsafe String, nothing to escape" => "hello world", "unsafe String with <&" => "a < b & c",
  "SafeBuffer" => "<b>".html_safe, "Integer" => 42, "nil" => nil }.each do |name, value|
  puts format("%-34s %7.1f ns", name, measure(value))
end
