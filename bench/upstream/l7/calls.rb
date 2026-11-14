# frozen_string_literal: true

# calls.rb CASE ROWS: Ruby and C method calls per loaded row of a load_micro.rb case
# (TracePoint, 20 calls after warmup), for the tree in BUNDLE_GEMFILE. Diff two trees.
c, rows = ARGV.shift(2)
ENV["CASES"] = c
ENV["ROWS"] = rows
ENV["N"] = "0"
micro = File.join(__dir__, "load_micro.rb")
module IrCount; def self.running? = false; def self.now = 0; end
$LOADED_FEATURES << File.expand_path("~/l7/ext/ir_count.so")
src = File.read(micro).sub(/^yjit = .*\z/m, "L7_CASES = cases\n")
eval(src, TOPLEVEL_BINDING, micro)
fn = L7_CASES.first.last
50.times { fn.() }
counts = Hash.new(0)
tp = TracePoint.new(:call, :c_call, :b_call) { |t| counts["#{t.event == :b_call ? 'block in ' : ''}#{t.defined_class}##{t.method_id} #{t.path&.sub(/.*\/(active\w+)\//, '\1/')}:#{t.event == :c_call ? '' : t.lineno}"] += 1 }
tp.enable { 20.times { fn.() } }
counts.sort_by { [-_2, _1] }.each { |k, v| puts format("%8.2f %s", v / 20.0 / Integer(rows), k) }
