# Preload (RUBYOPT=-r): adds SLOW_N iterations of a busy loop to every
# ActiveRecord::Transactions#save, #save! and #destroy (the write path's entry
# points, around validations, callbacks and the transaction). SLOW_COUNT=1 prints
# how many calls each iteration made instead of measuring.
N = Integer(ENV.fetch("SLOW_N", "0"))
$slow_calls = 0
SLOW = Module.new do
  %i[save save! destroy].each do |m|
    define_method(m) do |*args, **kw, &blk|
      $slow_calls += 1
      i = 0
      while i < N
        i += 1
      end
      super(*args, **kw, &blk)
    end
  end
end
done = false
TracePoint.new(:class) do |tp|
  if !done && tp.self.name == "ActiveRecord::Transactions"
    tp.self.prepend(SLOW)
    done = true
  end
end.enable
if ENV["SLOW_COUNT"]
  at_exit { $stderr.puts "SLOW_CALLS total #{$slow_calls} prepended=#{done}" }
end
