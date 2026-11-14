# frozen_string_literal: true

# k6_micro.rb: Ir and objects per button_to call for K6's size sweep, for a
# Rails checkout in RAILS (lib directories). Same measurement as census 9's
# req_micro.rb: IrCount under census 8's patched Callgrind with
# --instr-atstart=no, N calls after WARM warmup calls, fixed heap from the
# caller, GC off in the window. Under YJIT, warmup continues until three
# windows in a row compile nothing (at most 30); jit is the blocks compiled in
# the measured window (0 = JIT-flat). Prints: case Ir/call objects/call jit calls.
rails = ENV.fetch("RAILS")
%w[activesupport actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "action_view"
require "action_controller"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/k6/ext/ir_count.so"))

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) }
class View < ActionView::Base
  include ROUTES.url_helpers
end
class CsrfView < View
  def protect_against_forgery? = true
  def form_authenticity_token(form_options: {}) = "tok"
  def request_forgery_protection_token = :authenticity_token
end
VIEW = View.empty
VIEW.output_buffer = ActionView::OutputBuffer.new
CSRF = CsrfView.empty
CSRF.output_buffer = ActionView::OutputBuffer.new

flat = ->(n, v = nil) { (1..n).to_h { ["k#{_1}", v || "v#{_1}"] }.freeze }
MB = 1 << 20
big = ->(size, pos) {
  s = "a" * size
  s[0] = "<" if pos == :early
  s[-1] = "<" if pos == :late
  s.freeze
}
NESTED = (1..20).to_h { |i| ["g#{i}", (1..10).to_h { ["k#{_1}", "v#{_1}"] }] }.freeze
ARRAYS = (1..20).to_h { |i| ["a#{i}", (1..10).map { "v#{_1}" }] }.freeze

CASES = {
  "no_params" => -> { VIEW.button_to("Go", "/posts") },
  "params1" => (p1 = flat.(1)) && -> { VIEW.button_to("Go", "/posts", params: p1) },
  "params2" => (p2 = flat.(2)) && -> { VIEW.button_to("Go", "/posts", params: p2) },
  "params5" => (p5 = flat.(5)) && -> { VIEW.button_to("Go", "/posts", params: p5) },
  "params20" => (p20 = flat.(20)) && -> { VIEW.button_to("Go", "/posts", params: p20) },
  "params200" => (p200 = flat.(200)) && -> { VIEW.button_to("Go", "/posts", params: p200) },
  "params2000" => (p2000 = flat.(2000)) && -> { VIEW.button_to("Go", "/posts", params: p2000) },
  "params5000" => (p5000 = flat.(5000)) && -> { VIEW.button_to("Go", "/posts", params: p5000) },
  "nested_20x10" => -> { VIEW.button_to("Go", "/posts", params: NESTED) },
  "arrays_20x10" => -> { VIEW.button_to("Go", "/posts", params: ARRAYS) },
  "csrf_delete_params20" => -> { CSRF.button_to("Go", "/posts/1", method: :delete, params: p20) },
  "params2000_1kb" => (pk = flat.(2000, big.(1024, :late))) && -> { VIEW.button_to("Go", "/posts", params: pk) },
  "value_1mb_absent" => (va = { "k" => big.(MB, :absent) }) && -> { VIEW.button_to("Go", "/posts", params: va) },
  "value_1mb_early" => (ve = { "k" => big.(MB, :early) }) && -> { VIEW.button_to("Go", "/posts", params: ve) },
  "value_1mb_late" => (vl = { "k" => big.(MB, :late) }) && -> { VIEW.button_to("Go", "/posts", params: vl) },
  "value_1mb_all" => (vx = { "k" => ("a<b " * (MB / 4)).freeze }) && -> { VIEW.button_to("Go", "/posts", params: vx) },
  "value_4mb_late" => (v4 = { "k" => big.(4 * MB, :late) }) && -> { VIEW.button_to("Go", "/posts", params: v4) },
  "name_1mb_absent" => (na = { big.(MB, :absent) => "v" }) && -> { VIEW.button_to("Go", "/posts", params: na) },
  "name_1mb_late" => (nl = { big.(MB, :late) => "v" }) && -> { VIEW.button_to("Go", "/posts", params: nl) },
  "name_1mb_nested" => (nn = { "o" => { big.(MB, :absent) => "v" } }) && -> { VIEW.button_to("Go", "/posts", params: nn) },
  "csrf_form_tag" => -> { CSRF.form_tag("/posts") { "x" } },
  "hidden_field_tag" => -> { VIEW.hidden_field_tag("k", "v") },
  "link_to" => -> { VIEW.link_to("x", "/posts/1", class: "a") },
}.freeze

LARGE = /2000|5000|mb/
n = Integer(ENV.fetch("N", "100"))
warm = Integer(ENV.fetch("WARM", "100"))
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
IrCount.start if IrCount.running?
(ARGV.empty? ? CASES.keys : ARGV).each do |name|
  fn = CASES.fetch(name)
  calls = name.match?(LARGE) ? [n / 20, 5].max : n
  [warm, calls].min.times { fn.() }
  if yjit
    streak = 0
    30.times do
      b = blocks.()
      calls.times { fn.() }
      streak = blocks.() == b ? streak + 1 : 0
      break if streak == 3
    end
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  calls.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  jit = blocks.() - b0
  GC.enable
  puts format("%-22s %14.1f %10.2f %d %d", name, (i1 - i0).fdiv(calls), (o1 - o0).fdiv(calls), jit, calls)
  $stdout.flush
end
