# What YJIT does with the two cases the RUBY19659 body says stay on invokeblock, and with surplus args.
#   ruby --yjit --yjit-call-threshold=2 --yjit-stats=quiet yjit-block-args.rb
def y0 = yield
def y1(x) = yield(x)
def y2(x, z) = yield(x, z)
cases = {
  "auto-splat [1, 2] into |a, b|" => -> { y1([1, 2]) { |a, b| a + b } },
  "auto-splat [3] into |a,|" => -> { y1([3]) { |a,| a } },
  "auto-splat [3, 4] into |a,|" => -> { y1([3, 4]) { |a,| a } },
  "non-Array 3 into |a,|" => -> { y1(3) { |a,| a } },
  "too few: no arg into |a|" => -> { y0 { |a| a } },
  "surplus: 2 args into |a|" => -> { y2(1, 2) { |a| a } },
}
cases.each do |name, body|
  before = RubyVM::YJIT.runtime_stats
  5000.times { body.call }
  after = RubyVM::YJIT.runtime_stats
  moved = after.keys.select { |k| after[k].is_a?(Integer) && k.to_s.match?(/invokeblock|arity|send_iseq_arg|exit|fallback|dynamic/) }
               .to_h { |k| [k, after[k] - before[k].to_i] }.reject { |_, v| v == 0 }
  puts "#{name}: #{moved.inspect}"
end
