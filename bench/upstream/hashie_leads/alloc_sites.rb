# Allocation sites per benchmark scenario: ruby -I HASHIE/lib alloc_sites.rb
require 'hashie'
require 'json'
require 'logger'
require 'objspace'
Hashie.logger = Logger.new(nil)
REPO = JSON.parse(File.read('/home/user/workspace/repos/hashie/duel/fixtures/repository.json')).freeze
class RD < Hashie::Dash; property :id, required: true; property :name, required: true; property :full_name; property :description; property :stargazers_count, default: 0; property :topics, default: []; property :archived, default: false; end
class RT < Hashie::Trash; property :id; property :title, from: :full_name; property :stars, from: :stargazers_count; property :topics, with: ->(t) { t.join(', ') }; end
class RC < Hashie::Dash; include Hashie::Extensions::Dash::Coercion; property :id, coerce: Integer; property :name, coerce: String; property :stargazers_count, coerce: Integer; property :topics, coerce: [String]; end
m = Hashie::Mash.new(REPO)
attrs = REPO.slice('id','name','full_name','description').transform_keys(&:to_sym)
tattrs = REPO.slice('id','full_name','stargazers_count','topics').transform_keys(&:to_sym)
cattrs = { id: '1296269', name: :'Hello-World', stargazers_count: '80', topics: %i[octocat api] }
up = { 'stargazers_count' => 81, 'topics' => %w[ruby api hashie], 'owner' => { 'site_admin' => true } }
S = {
  'mash_new' => -> { Hashie::Mash.new(REPO) },
  'read' => -> { m.name; m.owner.login; m.licenses.last.spdx_id },
  'suffix' => -> { m.private?; m.owner!.login; m.homepage_ },
  'brackets' => -> { m['name']; m[:full_name]; m.dig(:owner, :login) },
  'overwrite' => -> { m.description = 'x' },
  'respond_to' => -> { m.respond_to?(:name); m.respond_to?(:archived?); m.respond_to?(:missing) },
  'deep_merge' => -> { m.deep_merge(up) },
  'to_hash' => -> { m.to_hash },
  'dash_new' => -> { RD.new(attrs) },
  'trash_new' => -> { RT.new(tattrs) },
  'coerced' => -> { RC.new(cattrs) },
}
only = ARGV[0]
S.each do |name, f|
  next if only && name != only
  3.times { f.call }
  ObjectSpace.trace_object_allocations_start
  GC.disable
  before = ObjectSpace.each_object.to_a.size rescue nil
  gen = GC.count
  objs = []
  ObjectSpace.trace_object_allocations_clear
  f.call
  sites = Hash.new(0)
  ObjectSpace.each_object do |o|
    file = ObjectSpace.allocation_sourcefile(o) or next
    next unless file.include?('/lib/hashie')
    sites["#{file.sub(/.*\/lib\//, '')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
  end
  ObjectSpace.trace_object_allocations_stop
  GC.enable
  puts "== #{name}: #{sites.values.sum} objects from lib"
  sites.sort_by { -_2 }.first(8).each { |k, v| puts format('  %4d %s', v, k) }
end
