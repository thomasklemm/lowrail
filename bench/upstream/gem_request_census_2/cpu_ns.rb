# frozen_string_literal: true

# Best-of-7 process CPU time in ns per evaluation of EXPR (docs/upstream/gem-request-census-2.md).
#   ruby -I LIB cpu_ns.rb SETUP_RB EXPR [N]
load ARGV[0]
f = eval("-> { #{ARGV[1]} }") # rubocop:disable Security/Eval
n = Integer(ARGV[2] || 100_000)
5_000.times { f.() }
best = 7.times.map do
  t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  n.times { f.() }
  Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t
end.min
puts format("%.0f", best * 1e9 / n)
