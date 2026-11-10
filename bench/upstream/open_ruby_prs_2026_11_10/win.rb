# Preloaded with -r into a ruby-bench benchmark. Replaces run_benchmark:
# WIN_WARM warmup iterations, then WIN_N windows of WIN_LEN iterations, each
# after GC.start. Per window: deltas of the JIT counters named in WIN_KEYS and
# whether the flat-gate counters stayed equal. Writes JSON to WIN_OUT and exits.

module Win
  JIT = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then :zjit
        elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then :yjit
        else :interp end
  FLAT = { yjit: %i[compiled_iseq_count compiled_block_count invalidation_count],
           zjit: %i[compiled_iseq_count compiled_side_exit_count invalidation_time_ns compile_error_out_of_memory],
           interp: [] }[JIT]
  def self.stats
    case JIT
    when :yjit then RubyVM::YJIT.runtime_stats
    when :zjit then RubyVM::ZJIT.stats
    else {} end
  end

  def self.run(blk)
    keys = ENV.fetch("WIN_KEYS", "").split(",").map(&:to_sym)
    warm = Integer(ENV.fetch("WIN_WARM", "10"))
    n = Integer(ENV.fetch("WIN_N", "3"))
    len = Integer(ENV.fetch("WIN_LEN", "5"))
    warm.times { blk.call }
    wins = n.times.map do
      GC.start
      a = stats
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      len.times { blk.call }
      t = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
      b = stats
      { flat: FLAT.all? { |k| a[k] == b[k] }, flat_delta: FLAT.to_h { |k| [k, b[k].to_i - a[k].to_i] },
        ms_per_itr: t * 1000 / len,
        per_itr: keys.to_h { |k| [k, (b[k].to_i - a[k].to_i).fdiv(len)] } }
    end
    require "json"
    File.write(ENV.fetch("WIN_OUT"), JSON.pretty_generate(jit: JIT, warm: warm, len: len, windows: wins))
    exit!(0)
  end
end

def Object.method_added(name)
  return super unless equal?(Object) && name == :run_benchmark && !@win_wrapped
  @win_wrapped = true
  define_method(:run_benchmark) { |*_, **_, &blk| Win.run(blk) }
  private :run_benchmark
end
