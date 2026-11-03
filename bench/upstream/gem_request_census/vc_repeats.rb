# frozen_string_literal: true

# ViewComponent's boot precompute! (cache digests), with Prism.parse, Dir.[],
# IO.binread and File.read counted by call site. ruby inapp.rb sure vc_repeats.rb
require_relative "../census/harness"
RailsCensus.boot(ARGV[0])
comps = ViewComponent::Base.descendants.reject(&:anonymous?).select(&:__vc_compiled?)
ViewComponent::CacheDigest.send(:expire_digests); comps.each { _1.__vc_cache_digest_source = nil }
$on = false
$calls = Hash.new { |h, k| h[k] = Hash.new(0) }
Prism.singleton_class.prepend(Module.new { def parse(src, *a, **k) = ($on && $calls[:prism_parse][src.hash] += 1; super) })
Dir.singleton_class.prepend(Module.new { def [](*a, **k) = ($on && $calls[:glob_from][caller_locations(1, 8).find { _1.path.include?("view_component") }.then { "#{_1.path.split("/lib/").last}:#{_1.lineno} #{_1.label}" }] += 1; super) })
IO.singleton_class.prepend(Module.new { def binread(f, *a) = ($on && $calls[:binread_from][caller_locations(1, 8).find { _1.path.include?("view_component") }.then { "#{_1.path.split("/lib/").last}:#{_1.lineno} #{_1.label}" }] += 1; super) })
File.singleton_class.prepend(Module.new { def read(f, *a, **k) = ($on && $calls[:read][f.to_s] += 1; super) })
$on = true
ViewComponent::CacheDigest.retaining_compiled_sources { ViewComponent::CacheDigest.precompute!(comps) }
$on = false
$calls.each { |k, h| h.sort_by { -_2 }.first(4).each { |site, n| warn "  #{k} #{n} #{site}" } }
$calls.each { |k, h| warn "#{k}: #{h.values.sum} calls, #{h.size} distinct, max #{h.values.max} #{h.max_by { _2 }&.first.to_s[0, 140]}" }
