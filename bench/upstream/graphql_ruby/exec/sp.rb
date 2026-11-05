# usage: sp.rb SCENARIO N ; prints stackprof self/total top
ARGV.replace([ARGV[0], "0"]) .tap { $sp_args = [ARGV[0]] } if false
s, n = ARGV[0], Integer(ARGV[1])
ARGV.replace([s, "0"])
load "/tmp/gqscripts/ex.rb"
require "stackprof"
blk = S.fetch(s)
prof = StackProf.run(mode: :wall, interval: 100, raw: false) { n.times { blk.() } }
r = StackProf::Report.new(prof)
r.print_text(false, 35)
