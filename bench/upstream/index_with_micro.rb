# frozen_string_literal: true

# Per-call allocations of Enumerable#index_with variants (docs/upstream/index-with-capacity.md).
#   [RECV=set] ruby [--yjit] SCRIPT
# iw_main is Rails main (to_h), iw_each the #59108 loop over {}, iw_capa
# Hash.new(capacity: size) plus each, iw_capa2 the same with {} for
# up to two elements. Counts are objects, slot bytes and malloc
# bytes per call with GC disabled, then the memsize of one result and whether
# its table lives off the slot (spilled).
require "objspace"
require "set"

module Enumerable
  def iw_main(default = (no_default = true))
    if block_given?
      to_h { |elem| [elem, yield(elem)] }
    else
      to_h { |elem| [elem, default] }
    end
  end

  def iw_each(default = (no_default = true))
    result = {}
    if block_given?
      each { |elem| result[elem] = yield(elem) }
    else
      each { |elem| result[elem] = default }
    end
    result
  end

  def iw_capa(default = (no_default = true))
    result = Hash.new(capacity: size)
    if block_given?
      each { |elem| result[elem] = yield(elem) }
    else
      each { |elem| result[elem] = default }
    end
    result
  end

  def iw_capa2(default = (no_default = true))
    result = size > 2 ? Hash.new(capacity: size) : {}
    if block_given?
      each { |elem| result[elem] = yield(elem) }
    else
      each { |elem| result[elem] = default }
    end
    result
  end
end

VARIANTS = %i[iw_main iw_each iw_capa iw_capa2]
SIZES = [0, 1, 2, 3, 6, 8, 9, 12, 50]
N = 20_000

def heap_bytes
  GC.stat_heap.sum { |_, s| s[:total_allocated_objects] * s[:slot_size] }
end

def measure(recv, m, form)
  call = form == :block ? -> { recv.public_send(m) { |e| 1 } } : -> { recv.public_send(m, 1) }
  50.times { call.() }
  GC.start
  GC.disable
  o0 = GC.stat(:total_allocated_objects); b0 = heap_bytes; m0 = GC.stat(:malloc_increase_bytes)
  N.times { call.() }
  o1 = GC.stat(:total_allocated_objects); b1 = heap_bytes; m1 = GC.stat(:malloc_increase_bytes)
  GC.enable
  h = call.()
  d = JSON.parse(ObjectSpace.dump(h))
  { objs: (o1 - o0).fdiv(N).round(2), slot_bytes: (b1 - b0).fdiv(N).round(1), malloc_bytes: (m1 - m0).fdiv(N).round(1),
    memsize: d["memsize"], slot: d["slot_size"], spilled: d["memsize"] > d["slot_size"] }
end

require "json"
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
puts "# #{RUBY_DESCRIPTION} #{yjit ? 'YJIT' : 'interp'}"
kind = ENV.fetch("RECV", "array")
puts "| recv | form | n | variant | objs/call | slot B/call | malloc B/call | result memsize | slot | spilled |"
puts "|---|---|---|---|---|---|---|---|---|---|"
%i[block default].each do |form|
  SIZES.each do |n|
    arr = Array.new(n) { |i| "column_#{i}".freeze }
    recv = kind == "set" ? arr.to_set : arr
    VARIANTS.each do |v|
      r = measure(recv, v, form)
      puts "| #{kind} | #{form} | #{n} | #{v} | #{r[:objs]} | #{r[:slot_bytes]} | #{r[:malloc_bytes]} | #{r[:memsize]} | #{r[:slot]} | #{r[:spilled]} |"
    end
  end
end
