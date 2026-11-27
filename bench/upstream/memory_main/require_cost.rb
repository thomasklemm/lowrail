# frozen_string_literal: true

# Retained cost of requiring one gem version in a bare Ruby process, twice per version (the A/A pair):
#   GEM_HOME=DIR GEM_PATH=DIR ruby require_cost.rb GEM VERSION... > out.jsonl
# Heap is count_objects_size TOTAL after three full GCs; RssAnon from /proc.
require "json"
require "rbconfig"

name, *versions = ARGV
probe = <<~'RUBY'
  require "objspace"
  rss = -> { File.read("/proc/self/status")[/RssAnon:\s+(\d+)/, 1].to_i * 1024 }
  full = -> { 3.times { GC.start(full_mark: true, immediate_sweep: true) } }
  name, version = ARGV
  gem name, version
  full.()
  heap0, rss0 = ObjectSpace.count_objects_size[:TOTAL], rss.()
  require name
  full.()
  puts JSON.generate(gem: name, version: Gem.loaded_specs.fetch(name).version.to_s, ruby: RUBY_DESCRIPTION,
    heap_bytes: ObjectSpace.count_objects_size[:TOTAL] - heap0, rss_anon_bytes: rss.() - rss0,
    iseqs: ObjectSpace.count_imemo_objects[:imemo_iseq], loaded_features: $LOADED_FEATURES.grep(%r{/#{name}-#{version}/}).size)
RUBY
versions.product([1, 2]).each do |version, run|
  out = IO.popen([RbConfig.ruby, "-rjson", "-e", probe, name, version], &:read)
  puts JSON.generate(JSON.parse(out).merge(run: run))
end
