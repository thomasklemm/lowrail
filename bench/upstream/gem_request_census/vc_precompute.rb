# frozen_string_literal: true

# ViewComponent boot precompute!: CPU and objects of three runs, after boot.
#   ruby inapp.rb sure vc_precompute.rb   (GEMS=view_component=ViewComponent/view_component@SHA for main)
require_relative "../census/harness"
t0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
RailsCensus.boot(ARGV[0])
boot = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t0) * 1000
comps = ViewComponent::Base.descendants.reject(&:anonymous?).select(&:__vc_compiled?)
res = 3.times.map do
  ViewComponent::CacheDigest.send(:expire_digests)
  comps.each { _1.__vc_cache_digest_source = nil }
  GC.start
  t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID); o = GC.stat(:total_allocated_objects)
  ViewComponent::CacheDigest.retaining_compiled_sources { ViewComponent::CacheDigest.precompute!(comps) }
  [((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t) * 1000).round(1), GC.stat(:total_allocated_objects) - o]
end
spec = Gem.loaded_specs["view_component"]
warn "VC #{spec.version} #{spec.full_gem_path[-20..]} boot #{boot.round} ms, #{comps.size} components, precompute #{res.inspect}"
if ENV["PROF"]
