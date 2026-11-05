s, n, meth = ARGV[0], Integer(ARGV[1]), ARGV[2]
ARGV.replace([s, "0"])
load "/tmp/gqscripts/ex.rb"
require "stackprof"
blk = S.fetch(s)
prof = StackProf.run(mode: :wall, interval: 100) { n.times { blk.() } }
r = StackProf::Report.new(prof)
r.print_method(meth)
