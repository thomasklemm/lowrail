require 'hashie'; require 'json'; require 'logger'; require 'objspace'
Hashie.logger = Logger.new(nil)
src = JSON.parse(File.read('benchmarks/fixtures/repository.json'))
m = Hashie::Mash.new(src)
upd = { 'stargazers_count' => 81, 'topics' => %w[ruby api hashie], 'owner' => { 'site_admin' => true } }.freeze
cases = { 'Mash.new' => -> { Hashie::Mash.new(src) }, 'deep_merge' => -> { m.deep_merge(upd) }, 'dup' => -> { m.dup } }
cases.each do |name, c|
  200.times { c.() }
  GC.start; GC.disable
  n = 200
  ObjectSpace.trace_object_allocations_start
  gen = GC.count
  n.times { c.() }
  ObjectSpace.trace_object_allocations_stop
  by = Hash.new(0)
  ObjectSpace.each_object { |o| next unless ObjectSpace.allocation_generation(o) == gen && ObjectSpace.allocation_sourcefile(o)&.include?('hashie/') ; by[[o.class, ObjectSpace.allocation_sourcefile(o).split('lib/').last + ':' + ObjectSpace.allocation_sourceline(o).to_s]] += 1 }
  GC.enable
  tot = by.values.sum / n.to_f
  strs = by.select { |(k, _), _| k == String }.values.sum / n.to_f
  puts "#{RUBY_DESCRIPTION[0,40]} #{ARGV[0]} #{name}: #{tot} objects from hashie lib, #{strs} Strings"
  by.sort_by { -_2 }.first(8).each { |(k, s), v| puts "   #{(v / n.to_f).round(2)} #{k} #{s}" } if ARGV[0] == 'interp'
end
