# frozen_string_literal: true
$LOAD_PATH.unshift "#{ENV['RAILS']}/activesupport/lib", "#{ENV['RAILS']}/actionview/lib"
require "action_view"
Encoding.default_internal = Encoding::UTF_8
class OB2 < ActionView::OutputBuffer
  NOBUF = Object.new.freeze
  def initialize(buffer = NOBUF)
    @raw_buffer = NOBUF.equal?(buffer) ? +"" : String.new(buffer)
    @raw_buffer.encode!
  end
end
module FT2
  def self.sanitize(object_name)
    s = object_name.to_s
    s.match?(/\]\[|[^-a-zA-Z0-9:.]/) ? s.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").delete_suffix("_") : s
  end
end
V = ActionView::Base.empty
def m(label, n=1_000_000)
  best = 1e9; objs = 0
  5.times do
    a = GC.stat(:total_allocated_objects)
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    i = 0
    while i < n; yield; i += 1; end
    best = [best, Process.clock_gettime(Process::CLOCK_MONOTONIC) - t].min
    objs = (GC.stat(:total_allocated_objects) - a).to_f / n
  end
  printf "%-36s %7.1f ns %5.2f obj\n", label, best*1e9/n, objs
end
m("OutputBuffer.new (main)") { ActionView::OutputBuffer.new }
m("OutputBuffer.new (sentinel)") { OB2.new }
m("field_id(:post, :title) (main)") { V.field_id(:post, :title) }
m("sanitize 'post' gsub (main)") { "post".gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_").delete_suffix("_") }
m("sanitize 'post' match? first") { FT2.sanitize("post") }
m("safe_join([a,b]) (main)") { V.safe_join(["a".html_safe, "b"]) }
