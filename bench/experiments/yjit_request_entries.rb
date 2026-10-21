# frozen_string_literal: true

# Untimed off-arm diagnostic with extra observers, never a priced worker.
# YJIT_PROBE_REPO points to a source-pinned 88506d9 snapshot containing bench/.
# Preload Fiddle (-rfiddle) before Bundler; this changes the diagnostic heap.
require "json"
require "digest"
ROOT = ENV.fetch("YJIT_PROBE_REPO")
worker = File.join(ROOT, "bench/heap_requests.rb")
raise "worker drift" unless Digest::SHA256.file(worker).hexdigest == "9b7c67a3d6ae5bf5663c48a62d8af4a8d0610a33d7ed421e5bdd63dfeb139678"
raise "off only" unless ENV["LOWRAIL"] == "0"
$native_request = 0
$native_phase = "boot"
$native_last = {}
$stderr.sync = true
def native_probe(event, force = false)
  keys = %i[compiled_iseq_count compiled_iseq_entry compiled_block_count compiled_blockid_count invalidation_count compile_time_ns]
  now = RubyVM::YJIT.runtime_stats.slice(*keys)
  now[:log_bytes] = File.size(ENV.fetch("BENCH_YJIT_LOG_FILE"))
  if force || now != $native_last
    warn JSON.generate(event: event, phase: $native_phase, request: $native_request,
      realtime: Process.clock_gettime(Process::CLOCK_REALTIME), counters: now)
  end
  $native_last = now
end
require File.join(ROOT, "bench/jit_stability")
module NativeSnapshot
  def snapshot
    value = super
    native_probe("snapshot")
    value
  end
end
JitStability.singleton_class.prepend(NativeSnapshot)
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
module NativeWindows
  def start(*args)
    $native_phase = args.first ? "no_gc" : "total"
    native_probe("window_start", true)
    super
  end
  def finish
    value = super
    native_probe("window_end", true)
    $native_phase = "between_windows"
    value
  end
end
LowrailCallgrindBench.singleton_class.prepend(NativeWindows)
source = File.read(worker)
anchor = "    response = session.request(verb, path, headers)"
raise "request anchor drift" unless source.scan(anchor).size == 1
source = source.sub(anchor, <<~RUBY.chomp)
    $native_request += 1
    response = session.request(verb, path, headers)
    native_probe("request_end")
RUBY
anchor = "    jit_warmup = JitStability.warm(rehearsal_requests: n, &workload)"
raise "warm anchor drift" unless source.scan(anchor).size == 1
source = source.sub(anchor, <<~RUBY.chomp)
    $native_phase = "warmup"
    native_probe("warm_start", true)
    jit_warmup = JitStability.warm(rehearsal_requests: n, &workload)
    $native_phase = "certified"
    native_probe("certified", true)
RUBY
warn JSON.generate(event: "diagnostic", engine: "native", arm: "off", additional_per_request_observers: true,
  source_sha256: Digest::SHA256.hexdigest(source))
eval(source, TOPLEVEL_BINDING, worker, 1)

require_relative "yjit_entry_reader"
targets = {
  asset_host: ActionView::Helpers::AssetUrlHelper.instance_method(:compute_asset_host),
  nonce: ActionView::Helpers::AssetTagHelper.instance_method(:auto_include_nonce_for_styles),
  media: ActionView::Helpers::AssetTagHelper.instance_method(:apply_stylesheet_media_default),
  preload: ActionView::Helpers::AssetTagHelper.instance_method(:send_preload_links_header),
  sending: ActionDispatch::Response.instance_method(:sending?)
}
states = targets.transform_values { YjitEntryReader.state(RubyVM::InstructionSequence.of(_1)) }
warn JSON.generate(event: "post_windows_method_entries", request: $native_request, states: states)

# An ordinary helper call may stay entirely JIT-to-JIT: repetition alone need
# not advance any pending interpreter-entry counter.
view = ObjectSpace.each_object(ActionView::Base).find { _1.controller.is_a?(ArticlesController) }
raise "no completed article view retained" unless view
before = RubyVM::YJIT.runtime_stats
log_before = File.size(ENV.fetch("BENCH_YJIT_LOG_FILE"))
output = view.method(:stylesheet_link_tag).call(:app, "data-turbo-track": "reload")
after = RubyVM::YJIT.runtime_stats
log_after = File.size(ENV.fetch("BENCH_YJIT_LOG_FILE"))
keys = %i[compiled_iseq_count compiled_iseq_entry compiled_block_count compiled_blockid_count invalidation_count]
warn JSON.generate(event: "ordinary_stylesheet_entry", delta: keys.to_h { [_1, after.fetch(_1) - before.fetch(_1)] },
  log_interval: [log_before, log_after], output_sha256: Digest::SHA256.hexdigest(output))
