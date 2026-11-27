# frozen_string_literal: true

# Usage: ruby -I HASHIE/lib alloc_sites.rb HASHIE CASE...
# Allocation sites (file:line, class) per call for the named cases.
require 'hashie'
require 'json'
require 'logger'
require 'objspace'
Hashie.logger = Logger.new(nil)

dir = ARGV.shift
json = File.read(File.join(dir, 'benchmarks/fixtures/repository.json'))
mash = Hashie::Mash.new(JSON.parse(json))
src = JSON.parse(json)
update = { 'stargazers_count' => 81, 'topics' => %w[ruby api hashie], 'owner' => { 'site_admin' => true } }.freeze
cases = {
  'new' => -> { Hashie::Mash.new(src) },
  'suffixes' => -> { mash.private?; mash.owner!.login; mash.homepage_ },
  'dig' => -> { mash.dig(:owner, :login) },
  'read' => -> { mash.name },
  'write' => -> { m = Hashie::Mash.new; m.name = 'x' },
  'deep_merge' => -> { mash.deep_merge(update) }
}
n = 100
ARGV.each do |name|
  c = cases.fetch(name)
  20.times { c.() }
  GC.start
  GC.disable
  sites = Hash.new(0)
  ObjectSpace.trace_object_allocations do
    before = ObjectSpace.each_object.to_a.map(&:__id__).to_h { [_1, true] } rescue nil
    gen = GC.count
    objs = []
    ObjectSpace.trace_object_allocations_clear
    n.times { c.() }
    ObjectSpace.each_object do |o|
      f = ObjectSpace.allocation_sourcefile(o) or next
      next unless ObjectSpace.allocation_generation(o) == gen
      sites["#{f.sub(%r{.*/(lib|orb-backup)/}, '')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class rescue '?'}"] += 1
    end
  end
  GC.enable
  puts "== #{name}"
  sites.sort_by { -_2 }.each { |s, k| printf("  %6.2f %s\n", k.to_f / n, s) unless s.include?('alloc_sites.rb:3') }
end
