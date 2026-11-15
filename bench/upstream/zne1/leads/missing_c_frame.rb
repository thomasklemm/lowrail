# The C frame of Integer#== is missing below BasicObject#!= under --zjit, also when nothing is compiled.
class E; def ==(other) = raise("boom"); end
def neq(x, y) = x != y
def eq(x, y) = x == y
[[:neq, method(:neq)], [:eq, method(:eq)]].each do |name, m|
  m.call(1, E.new)
rescue => e
  puts "#{name}: #{e.backtrace_locations.map(&:label).first(4).join(' < ')}"
end
