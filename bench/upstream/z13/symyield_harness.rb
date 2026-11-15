require_relative "../lib/harness"
# Counts `&:sym` calls to the JIT-only Ruby Array#each/map/select/find and Kernel#then/tap per caller line, and the
# yields they make (elements), over one iteration after 5 warmup iterations (Z13 Symbol bucket).
def run_benchmark(_n, **, &block)
  5.times { block.call }
  calls = Hash.new { |h, k| h[k] = [0, 0] }
  on = false
  sym = ->(b) { b && b.lambda? && b.inspect.include?("(&:") }
  site = -> { caller_locations(2, 1)[0].to_s.sub(%r{.*/gems/}, "").sub(%r{/home/user/w/(rails-vb1|vendor)/}, "").sub(/:in .*/, "") }
  Array.prepend(Module.new do
    %i[each map select find].each do |m|
      define_method(m) do |*a, &b|
        if on && sym.(b)
          c = calls[[site.(), "#{m}(#{b.inspect[/&:[^)]+/]})"]]; c[0] += 1; c[1] += size
        end
        super(*a, &b)
      end
    end
  end)
  Kernel.prepend(Module.new do
    %i[then tap].each do |m|
      define_method(m) do |*a, &b|
        if on && sym.(b)
          c = calls[[site.(), "#{m}(#{b.inspect[/&:[^)]+/]})"]]; c[0] += 1; c[1] += 1
        end
        super(*a, &b)
      end
    end
  end)
  on = true
  block.call
  on = false
  total = calls.values.sum { |_c, y| y }
  puts "SYMBOL-YIELDS calls=#{calls.values.sum { |c, _y| c }} yields=#{total}"
  calls.sort_by { -_2[1] }.first(Integer(ENV.fetch("TOP", 15))).each { |(s, m), (c, y)| puts "#{y.to_s.rjust(7)} #{c.to_s.rjust(6)} #{m} #{s}" }
end
