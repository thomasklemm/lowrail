# frozen_string_literal: true

# Where a realistic API workload spends objects and samples in hashie.
# Usage: ruby -I HASHIE/lib profile.rb [alloc|prof] ; workloads: 30 GitHub repositories or issues per call.
require 'hashie'
require 'json'
require 'logger'
require 'objspace'

Hashie.logger = Logger.new(nil)
FIX = File.expand_path('../fixtures', __dir__)
REPOS = JSON.parse(File.read("#{FIX}/github-org-repos.json"))
ISSUES = JSON.parse(File.read("#{FIX}/github-issues.json"))
MASHES = REPOS.map { |r| Hashie::Mash.new(r) }

WORK = {
  'Mash.new x30 repos' => -> { REPOS.map { |r| Hashie::Mash.new(r) } },
  'Mash.new x30 issues' => -> { ISSUES.map { |r| Hashie::Mash.new(r) } },
  'read 6 methods x30' => -> { MASHES.each { |m| m.name; m.full_name; m.owner.login; m.license; m.private; m.html_url } },
  'to_hash x30' => -> { MASHES.each(&:to_hash) },
  'dup x30' => -> { MASHES.each(&:dup) },
  'merge x30' => -> { MASHES.each { |m| m.merge('stargazers_count' => 1, 'owner' => { 'site_admin' => true }) } }
}.freeze

case ARGV[0]
when 'alloc'
  WORK.each do |name, work|
    3.times { work.call }
    GC.start
    GC.disable
    before = GC.stat(:total_allocated_objects)
    work.call
    total = GC.stat(:total_allocated_objects) - before
    sites = Hash.new(0)
    ObjectSpace.trace_object_allocations do
      gen = GC.count
      work.call
      ObjectSpace.each_object do |o|
        file = ObjectSpace.allocation_sourcefile(o) or next
        next unless ObjectSpace.allocation_generation(o) == gen

        sites[[file.sub(%r{.*/lib/}, ''), ObjectSpace.allocation_sourceline(o), o.class.name || o.class.superclass.name]] += 1
      end
    end
    GC.enable
    puts "== #{name}: #{total} objects"
    sites.sort_by { |_, n| -n }.first(14).each { |(f, l, c), n| puts format('%6d  %s:%d %s', n, f, l, c) }
  end
when 'prof'
  require 'stackprof'
  WORK.each do |name, work|
    100.times { work.call }
    profile = StackProf.run(mode: :cpu, interval: 200, raw: false) { 300.times { work.call } }
    puts "== #{name}"
    total = profile[:samples].to_f
    profile[:frames].values.sort_by { |f| -f[:samples] }.first(14).each do |f|
      puts format('%5.1f%% self %5.1f%% total  %s', 100 * f[:samples] / total, 100 * f[:total_samples] / total, f[:name])
    end
  end
end
