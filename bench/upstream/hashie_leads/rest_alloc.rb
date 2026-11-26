def splat(*a) = a.size
def lead_rest(x = nil, *r) = r.size
def lead_rest_empty_check(x = nil, *r) = (r.empty? ? 1 : 2)
def anon(*) = 1
[[:splat, ->{ splat(1) }], [:lead_rest, ->{ lead_rest(1) }], [:lead_rest_empty_check, ->{ lead_rest_empty_check(1) }], [:anon, ->{ anon(1) }]].each do |n, f|
  1000.times { f.call }
  a = GC.stat(:total_allocated_objects); 1000.times { f.call }; b = GC.stat(:total_allocated_objects)
  puts "#{n} #{(b - a) / 1000.0} #{RUBY_VERSION}"
end
