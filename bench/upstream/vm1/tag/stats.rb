# JIT counters per call of ips.rb's two reports, after warmup, for the Rails tree given as the
# argument. Prints the counters that are non-zero on any tree.
#   ruby --yjit --yjit-stats=quiet stats.rb TREE  |  ruby --zjit --zjit-stats=quiet stats.rb TREE
tree = ARGV.fetch(0)
%w[activesupport actionview activemodel actionpack].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"

view = ActionView::Base.empty
reports = {
  "tag.a" => -> { view.tag.a("Jane Doe", href: "/users/42", class: "author-link", title: "Jane Doe") },
  "content_tag" => -> { view.content_tag(:span, "Jane & John", class: "byline") },
}
stats = -> { defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats : RubyVM::YJIT.runtime_stats }
n = 1000
reports.each do |name, op|
  5000.times { op.call }
  before = stats.call
  n.times { op.call }
  after = stats.call
  diff = after.filter_map { |k, v| [k, (v - before[k].to_i) / n.to_f] if v.is_a?(Integer) && before[k].is_a?(Integer) && v != before[k] }
  keep = diff.select { |k, _| k.to_s.match?(/dynamic|fallback|super|not_equal|neq|singleton|exit_count|send_count|ccall_rb_vm|polymorphic|megamorphic/) }
  puts "#{name}: " + keep.sort_by { -_2 }.map { |k, v| "#{k}=#{v.round(2)}" }.join(" ")
end
