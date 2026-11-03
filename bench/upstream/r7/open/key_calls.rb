V, N = ARGV[0], Integer(ARGV[1])
k = :created_at
f = case V
when "to_s" then -> { k.to_s; k.to_s; k.to_s; k.to_s }
when "name" then -> { k.name; k.name; k.name; k.name }
when "eqq" then -> { Symbol === k; Symbol === k; Symbol === k; Symbol === k }
when "nil" then -> { k; k; k; k }
end
3000.times { f.() }
GC.start; GC.disable
[0].cycle(1) { N.times { f.() } }
