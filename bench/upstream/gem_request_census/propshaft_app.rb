# frozen_string_literal: true

# Propshaft LoadPath#assets_by_path in a booted census app: assets, CPU,
# objects, and the allocating lines. ruby inapp.rb mastodon propshaft_app.rb
require_relative "../census/harness"
RailsCensus.boot(ARGV[0])
lp = Rails.application.assets.load_path
GC.start; GC.disable
counts = Hash.new(0)
a = GC.stat(:total_allocated_objects); t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
n = lp.send(:assets_by_path).size
cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t
objs = GC.stat(:total_allocated_objects) - a
warn "assets #{n}, paths #{lp.paths.size}, cpu #{(cpu*1000).round(1)} ms, objects #{objs}"
pn = 0; ObjectSpace.each_object(Pathname) { pn += 1 }
warn "live Pathnames #{pn}"
lp.paths.each { |p| warn "  #{p} #{Dir.glob("#{p}/**/*", File::FNM_DOTMATCH).size}" }
require "objspace"
lp.send(:clear_cache)
GC.start
ObjectSpace.trace_object_allocations_start
gen = GC.count
lp.send(:assets_by_path)
ObjectSpace.trace_object_allocations_stop
rows = Hash.new(0)
ObjectSpace.each_object { |o| next unless ObjectSpace.allocation_generation(o) == gen; rows["#{ObjectSpace.allocation_sourcefile(o)&.sub(/.*\/gems\//,'')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1 rescue nil }
rows.sort_by { -_2 }.first(15).each { warn "  #{_2} #{_1}" }
