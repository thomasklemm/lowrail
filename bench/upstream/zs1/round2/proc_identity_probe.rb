SYMS = 200.times.map { |i| "evict_#{i}".to_sym }
$expected = :succ.to_proc

def materialize(&b)
  SYMS.each { |sym| sym.to_proc }
  b.equal?($expected)
end

def entry = materialize(&:succ)

i = 0
while i < 100
  entry
  i += 1
end

Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))
$expected = :succ.to_proc
p entry
