# frozen_string_literal: true

# profile.rb CASE ROWS: one Callgrind profile of N calls of a load_micro.rb case after warmup, for
# callgrind_annotate (run with --collect-atstart=no; Collect from collect.c toggles the window).
c, rows = ARGV.shift(2)
ENV["CASES"] = c
ENV["ROWS"] = rows
ENV["N"] = "0"
micro = File.join(__dir__, "load_micro.rb")
module IrCount; def self.running? = false; def self.now = 0; end
$LOADED_FEATURES << File.expand_path("~/l7/ext/ir_count.so")
eval(File.read(micro).sub(/^yjit = .*\z/m, "L7_CASES = cases\n"), TOPLEVEL_BINDING, micro)
require File.expand_path("~/l7/ext/collect.so")
fn = L7_CASES.first.last
n = Integer(ENV.fetch("PN", "40"))
(n * 2).times { fn.() }
GC.start
GC.disable
Collect.toggle
n.times { fn.() }
Collect.toggle
