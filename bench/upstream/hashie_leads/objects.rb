# Objects per call for a few Mash workloads: ruby -I TREE/lib objects.rb
require 'hashie'; require 'json'; require 'logger'
Hashie.logger = Logger.new(nil)
P = JSON.parse(File.read('/home/user/workspace/repos/hashie/duel/fixtures/repository.json')).freeze
m = Hashie::Mash.new(P)
up = { 'stargazers_count' => 81, 'topics' => %w[ruby api hashie], 'owner' => { 'site_admin' => true } }
W = {
  'Mash.new(api)' => -> { Hashie::Mash.new(P) },
  'new.name = v' => -> { Hashie::Mash.new.name = 'v' },
  'deep_merge' => -> { m.deep_merge(up) },
  'overwrite' => -> { m.description = 'x' },
  'suffix reads' => -> { m.private?; m.owner!.login; m.homepage_ },
  'Mash.new(flat 3)' => -> { Hashie::Mash.new('a' => 1, 'b' => 2, 'c' => 3) },
}
W.each do |name, f|
  2000.times { f.call }
  GC.disable
  a = GC.stat(:total_allocated_objects); 1000.times { f.call }; b = GC.stat(:total_allocated_objects)
  GC.enable
  printf("%-18s %8.2f\n", name, (b - a) / 1000.0)
end
