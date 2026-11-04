# ruby fmt_build.rb MODE   (RAILS=<worktree>; MODE: mem | ir | obj)
%w[activesupport actionpack].each { |c| $LOAD_PATH.unshift File.join(ENV.fetch("RAILS"), c, "lib") }
require "active_support"; require "active_support/all"; require "action_dispatch"; require "objspace"
J = ActionDispatch::Journey
specs = (0...1500).map do |i|
  r = "res#{i}"
  ["/#{r}(.:format)", "/#{r}/new(.:format)", "/#{r}/:id(.:format)", "/#{r}/:id/edit(.:format)",
   "/admin/#{r}/:#{r}_id/items/:id(.:format)"][i % 5]
end
patterns = specs.map { |s| J::Path::Pattern.new(J::Ast.new(J::Parser.new.parse(s), true), {}, "/.?", true) }
patterns.each(&:spec)
GC.start
case ARGV[0]
when "mem"
  GC.disable
  before = ObjectSpace.memsize_of_all
  fmts = patterns.map(&:build_formatter)
  GC.enable; GC.start
  # bytes of the arrays, formats and strings reachable from the formats; shared objects count once
  bytes = 0
  seen = {}
  stack = fmts.dup
  until stack.empty?
    o = stack.pop
    next if seen[o.__id__]; seen[o.__id__] = true
    bytes += ObjectSpace.memsize_of(o)
    kids = Array === o ? o : o.instance_variables.map { o.instance_variable_get(_1) }
    kids.each { |c| stack << c if Array === c || J::Format === c || String === c }
  end
  puts "routes=#{fmts.size} bytes_reachable=#{bytes} per_route=#{(bytes.fdiv(fmts.size)).round(1)}"
when "obj"
  b = GC.stat(:total_allocated_objects); patterns.each(&:build_formatter)
  puts (GC.stat(:total_allocated_objects) - b).fdiv(patterns.size)
when "ir"
  [0].cycle(1) { patterns.each(&:build_formatter) }
when "ns"
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond); 5.times { patterns.each(&:build_formatter) }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(5 * patterns.size).round(1)
end
