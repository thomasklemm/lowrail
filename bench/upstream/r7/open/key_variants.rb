# ruby v.rb VARIANT N : Ir window of N Hash#as_json-shaped loops over 4 Symbol keys
V, N = ARGV[0], Integer(ARGV[1])
h = { id: 1, name: "David", email: "d@example.com", created_at: nil }
f = case V
when "to_s" then -> { r = {}; h.each { |k, v| r[k.to_s] = v }; r }
when "eqq" then -> { r = {}; h.each { |k, v| r[Symbol === k ? k.name : k.to_s] = v }; r }
when "isa" then -> { r = {}; h.each { |k, v| r[k.is_a?(Symbol) ? k.name : k.to_s] = v }; r }
when "case" then -> { r = {}; h.each { |k, v| r[case k when Symbol then k.name else k.to_s end] = v }; r }
end
3000.times { f.() }
GC.start; GC.disable
[0].cycle(1) { N.times { f.() } }
