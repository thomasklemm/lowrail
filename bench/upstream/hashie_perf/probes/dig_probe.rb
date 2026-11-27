require 'hashie'
m = Hashie::Mash.new(owner: { login: 'x' }, list: [{ a: 1 }])
V = {
  cur: Class.new(Hashie::Mash) { def dig(*keys) = super(*keys.map { |key| convert_key(key) }) },
  bang: Class.new(Hashie::Mash) { def dig(*keys) = super(*keys.map! { |key| convert_key(key) }) },
}
def objs(n = 1000) = (b = GC.stat(:total_allocated_objects); n.times { yield }; (GC.stat(:total_allocated_objects) - b) / n.to_f)
V.each do |k, c|
  x = c.new(owner: { login: 'x' }, list: [{ a: 1 }])
  arr = [:owner, :login]
  x.dig(*arr); raise 'mutated' unless arr == [:owner, :login]
  objs { x.dig(:owner, :login) }
  puts "#{RUBY_VERSION} #{ARGV[0]} #{k} 2-key #{objs { x.dig(:owner, :login) }} 1-key #{objs { x.dig(:owner) }} splat #{objs { x.dig(*arr) }}"
end
