# Callgrind instructions per Object#try(:deferred?) call (PI3 in app-suites.md).
# Each run warms 200,000 calls, then makes N more. Instructions per call are
# (Ir at N=200,000 - Ir at N=0) / 200,000, so boot and warm-up cancel; GC is
# included. Ruby 4.0.9, interpreter (--disable-yjit) and YJIT
# (--yjit --yjit-call-threshold=1), two runs per tree:
#   valgrind --tool=cachegrind --cache-sim=no --branch-sim=no \
#     --cachegrind-out-file=/dev/null ruby --disable-yjit try_micro.rb 200000
# with RAILS=/path/to/rails set; read "I refs" from Valgrind's summary.
$LOAD_PATH.unshift(File.join(ENV.fetch("RAILS"), "activesupport/lib"))
require "active_support"
require "active_support/core_ext/object/try"

class Prop
  def deferred? = false
end
prop = Prop.new

200_000.times { prop.try(:deferred?) }
Integer(ARGV.fetch(0)).times { prop.try(:deferred?) }
