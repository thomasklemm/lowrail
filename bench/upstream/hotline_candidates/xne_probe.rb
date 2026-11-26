# frozen_string_literal: true
# Usage: ruby probe.rb RAILS_TREE  -> objects per call, and from xml_name_escape's first line
$LOAD_PATH.unshift File.join(ARGV[0], "activesupport/lib"), File.join(ARGV[0], "actionview/lib")
require "active_support"
require "active_support/core_ext"
require "action_view"
include ActionView::Helpers::TagHelper
include ActionView::Helpers::UrlHelper
include ActionView::Helpers::OutputSafetyHelper
include ActionView::Helpers::CaptureHelper
def output_buffer; @output_buffer; end; def output_buffer=(v); @output_buffer = v; end
def count
  3.times { yield }
  GC.disable
  a = GC.stat(:total_allocated_objects); 100.times { yield }; b = GC.stat(:total_allocated_objects)
  GC.enable
  (b - a) / 100.0
end
cases = {
  'tag.div("x", class: "card")' => -> { tag.div("x", class: "card") },
  'tag.input(type: "text", name: "q", value: "v")' => -> { tag.input(type: "text", name: "q", value: "v") },
  'content_tag(:a, "x", href: "/a", class: "b", id: "c")' => -> { content_tag(:a, "x", href: "/a", class: "b", id: "c") },
  'xml_name_escape(:class)' => -> { ERB::Util.xml_name_escape(:class) },
  'xml_name_escape("class")' => -> { ERB::Util.xml_name_escape("class") },
}
cases.each { |name, blk| printf "%-55s %5.1f\n", name, count(&blk) }
# Allocation sites inside util.rb during tag rendering
require "objspace"
ObjectSpace.trace_object_allocations_start
objs = []; 10.times { objs << tag.div("x", class: "card", id: "a", title: "t") }
sites = Hash.new(0)
ObjectSpace.each_object(String) { |s| f = ObjectSpace.allocation_sourcefile(s); sites["#{File.basename(f)}:#{ObjectSpace.allocation_sourceline(s)}"] += 1 if f&.end_with?("erb/util.rb") }
puts "util.rb String sites over 10 tag.div with 3 Symbol keys: #{sites.inspect}"
