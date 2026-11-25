# frozen_string_literal: true

# Control for docs/upstream/zjit-gap-census-2.md: an @ivar read whose receivers have more shapes than the profile
# sampled, though no more than YJIT's chain depth (8). Like Rack::Request::Env#get_header (@env[name]) on
# ActionDispatch::Request objects, which set other ivars lazily in an order that depends on the request. ZJIT takes
# getivar_fallback_shape_chain_miss here and is still cheaper per call than YJIT, so it is not a gap.
#   ruby --zjit --zjit-stats-quiet repro_getivar_shapes.rb [SHAPES] [N]
#   ruby --yjit --yjit-stats=quiet repro_getivar_shapes.rb [SHAPES] [N]
# Prints the counters that move. With LOWRAIL_CG=1 (and -I the bench/callgrind.c extension under Callgrind) only the
# measured loop is counted.
SHAPES = Integer(ARGV[0] || 6)
N = Integer(ARGV[1] || 200_000)

class Req
  IVARS = %i[@a @b @c @d @e @f @g @h].freeze

  def initialize(kind)
    # One ivar first, so that @env sits at another index in each shape.
    instance_variable_set(IVARS[kind], kind) if kind.positive?
    @env = { "k" => kind }
  end

  def get_header(name) = @env[name]
end

reqs = Array.new(SHAPES) { Req.new(_1) }
run = ->(n) { i = 0; s = 0; while i < n; s += reqs[i % SHAPES].get_header("k"); i += 1; end; s }
run.(10_000)
jit = (RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : RubyVM::YJIT) rescue nil
jit&.reset_stats! if jit&.stats_enabled?
if ENV["LOWRAIL_CG"] == "1"
  require "lowrail_callgrind"
  LowrailCallgrindBench.start(false)
  LowrailCallgrindBench.finish
  LowrailCallgrindBench.start(false)
  run.(N)
  LowrailCallgrindBench.finish
else
  run.(N)
end
if jit&.stats_enabled?
  stats = jit == RubyVM::YJIT ? jit.runtime_stats : jit.stats
  stats.each { |k, v| puts "#{k}: #{v}" if v.is_a?(Integer) && v.positive? && k.match?(/ivar|side_exit|exit_count|dynamic_send/) }
end
