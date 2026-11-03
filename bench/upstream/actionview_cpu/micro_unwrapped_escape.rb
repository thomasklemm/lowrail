# frozen_string_literal: true

# Per-call cost of ERB::Util.unwrapped_html_escape (tag attributes,
# content_tag, safe_join and SafeBuffer all escape through it), run once per
# Rails variant bundle:
#   BUNDLE_GEMFILE=.../Gemfile.main-a ruby [--yjit] micro_unwrapped_escape.rb
# Best of 7 runs of N calls, in ns per call.
require "bundler/setup"
require "active_support"
require "active_support/core_ext/string/output_safety"

N = Integer(ENV.fetch("N", "2000000"))

def measure(value)
  7.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    i = 0
    while i < N
      ERB::Util.unwrapped_html_escape(value)
      i += 1
    end
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
  end.min * 1e9 / N
end

{ "unsafe String, nothing to escape" => "hello world", "unsafe String with <&" => "a < b & c",
  "Symbol" => :abc, "SafeBuffer" => "<b>".html_safe }.each do |name, value|
  puts format("%-34s %7.1f ns", name, measure(value))
end
