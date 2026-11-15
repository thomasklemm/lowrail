# Callgrind instructions for OutputBuffer#<< of an unsafe String in the Rails tree given as the argument:
# each iteration appends 8 times to a fresh buffer. Optional third argument: a file to load after Rails
# (Discourse's lib/freedom_patches/erb_util.rb).
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle ruby [--yjit] ir_append.rb TREE N [PATCH]
tree, n, patch = ARGV
%w[activesupport actionview].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"
load patch if patch
s = "Hello & World"
op = lambda do
  b = ActionView::OutputBuffer.new
  b << s; b << s; b << s; b << s; b << s; b << s; b << s; b << s
end
3000.times { op.call }
GC.start
GC.disable
[op].cycle(Integer(n)) { |o| o.call }
