# Lead 15a on master and ruby/ruby#18616 (docs/upstream/zjit-iseq-leads.md, Taken):
# ruby --zjit --zjit-call-threshold=2 --zjit-max-versions=2 --zjit-stats-quiet l15a_probe.rb
class Point
  attr_reader :x
  def initialize(x, y = nil)
    @y = y if y
    @x = x
  end
end

OFFSET = 10
def shifted(point) = point.x + OFFSET

point = Point.new(1)
shifted(point); shifted(point)       # ZJIT compiles shifted
Object.send(:remove_const, :OFFSET)
OFFSET = 20                          # ...and throws that code away
shifted(point); shifted(point)       # last allowed compile of shifted
RubyVM::ZJIT.reset_stats!
i = 0; while i < 1000; shifted(point); i += 1; end
other = Point.new(2, :y)             # same class, other shape
r = [shifted(point), shifted(other)]
s = RubyVM::ZJIT.stats
keys = %i[getivar_fallback_no_side_exits ccall_rb_ivar_get send_fallback_send_polymorphic_fallback dynamic_send_count side_exit_count]
p r
keys.each { |k| puts "#{k}: #{s[k].inspect}" }
