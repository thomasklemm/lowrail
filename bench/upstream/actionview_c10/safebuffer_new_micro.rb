# frozen_string_literal: true

# What `new` on a String subclass costs because String has its own singleton
# `new` (so opt_new's fast path does not apply), measured on SafeBuffer.
#   ruby [--yjit|--zjit] -I RAILS/activesupport/lib safebuffer_new_micro.rb ns
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle \
#     ruby -I ... safebuffer_new_micro.rb ir CASE N
# CASE: html_safe | new | fast (a SafeBuffer subclass whose singleton `new` is
# Class#new, which keeps the opt_new fast path) | plain (String.new, control).
require "active_support/core_ext/string/output_safety"

class FastSafeBuffer < ActiveSupport::SafeBuffer
  define_singleton_method(:new, Class.instance_method(:new))
end

STR = "x"
CASES = {
  "html_safe" => -> { STR.html_safe },
  "new" => -> { ActiveSupport::SafeBuffer.new(STR) },
  "fast" => -> { FastSafeBuffer.new(STR) },
  "plain" => -> { String.new(STR) },
}.freeze

# Each case is its own method so that the call site is a plain opt_new.
def run_html_safe(n) = n.times { STR.html_safe }
def run_new(n) = n.times { ActiveSupport::SafeBuffer.new(STR) }
def run_fast(n) = n.times { FastSafeBuffer.new(STR) }
def run_plain(n) = n.times { String.new(STR) }

case ARGV[0]
when "ns"
  n = Integer(ARGV[1] || 1_000_000)
  CASES.each_key { |c| send("run_#{c}", 50_000) }
  rounds = Integer(ARGV[2] || 7)
  best = CASES.keys.to_h { [_1, Float::INFINITY] }
  rounds.times do |r|
    CASES.keys.rotate(r).each do |c|
      GC.start
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
      send("run_#{c}", n)
      best[c] = [best[c], (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(n)].min
    end
  end
  best.each { |c, ns| puts format("%-10s %7.1f ns", c, ns) }
when "ir"
  c = ARGV.fetch(1)
  n = Integer(ARGV.fetch(2))
  send("run_#{c}", 3_000)
  GC.start
  GC.disable
  [0].cycle(1) { send("run_#{c}", n) }
  GC.enable
when "check"
  CASES.each { |c, f| v = f.call; puts "#{c}: #{v.class} #{v.encoding} #{v.html_safe?} #{v.inspect}" }
  p ActiveSupport::SafeBuffer.method(:new).owner
  p FastSafeBuffer.method(:new).owner
end
