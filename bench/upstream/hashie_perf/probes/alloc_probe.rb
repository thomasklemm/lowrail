# frozen_string_literal: true

# Usage: ruby -I HASHIE/lib alloc_probe.rb HASHIE
# Objects and Strings per call for each Duel Mash scenario plus the dig/method_missing cases.
require 'hashie'
require 'json'
require 'logger'
Hashie.logger = Logger.new(nil)

dir = ARGV.fetch(0)
json = File.read(File.join(dir, 'benchmarks/fixtures/repository.json'))
repo = -> { JSON.parse(json) }
update = { 'stargazers_count' => 81, 'topics' => %w[ruby api hashie], 'owner' => { 'site_admin' => true } }.freeze

mash = Hashie::Mash.new(repo.())
src = repo.()
cases = {
  'Mash.new' => -> { Hashie::Mash.new(src) },
  'read methods' => -> { mash.name; mash.owner.login; mash.licenses.last.spdx_id },
  'read suffixes' => -> { mash.private?; mash.owner!.login; mash.homepage_ },
  'private?' => -> { mash.private? },
  'owner!' => -> { mash.owner! },
  'homepage_' => -> { mash.homepage_ },
  '[] and dig' => -> { mash['name']; mash[:full_name]; mash.dig(:owner, :login) },
  'dig(:owner, :login)' => -> { mash.dig(:owner, :login) },
  'name (method read)' => -> { mash.name },
  'write new key' => -> { m = Hashie::Mash.new; m.name = 'x' },
  'Mash.new empty' => -> { Hashie::Mash.new },
  'overwrite' => -> { mash.description = 'x' },
  'respond_to?' => -> { mash.respond_to?(:name); mash.respond_to?(:archived?); mash.respond_to?(:missing) },
  'deep_merge' => -> { mash.deep_merge(update) },
  'dup' => -> { mash.dup },
  'to_hash' => -> { mash.to_hash }
}

def count(call)
  50.times { call.() }
  GC.start
  GC.disable
  r = [100, 200].map do
    o = GC.stat(:total_allocated_objects)
    s = ObjectSpace.count_objects[:T_STRING]
    _1.times { call.() }
    [GC.stat(:total_allocated_objects) - o, ObjectSpace.count_objects[:T_STRING] - s]
  end
  GC.enable
  [(r[1][0] - r[0][0]) / 100.0, (r[1][1] - r[0][1]) / 100.0]
end

puts RUBY_DESCRIPTION
cases.each { |name, c| printf("%-22s objects %7.2f strings %7.2f\n", name, *count(c)) }
