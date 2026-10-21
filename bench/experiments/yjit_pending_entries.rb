# frozen_string_literal: true

# Native companion only. Never loaded by a measured worker or production.
# Run the pinned v3 worker once, census immediately after certification, and
# retain all four native diagnostic windows. No acceptance predicate changes.
# Requires YJIT_PROBE_REPO=historical source root, -rfiddle before Bundler,
# and the ordinary heap_requests environment. LOWRAIL setup, when requested,
# must use a matching historical runtime and a freshly certified native copy.
require "json"
require "objspace"
require_relative "yjit_entry_reader"
root = ENV.fetch("YJIT_PROBE_REPO")
worker = File.join(root, "bench/heap_requests.rb")
raise "worker drift" unless Digest::SHA256.file(worker).hexdigest == "9b7c67a3d6ae5bf5663c48a62d8af4a8d0610a33d7ed421e5bdd63dfeb139678"

def pending_entry_census
  named = {
    asset_host: ActionView::Helpers::AssetUrlHelper.instance_method(:compute_asset_host),
    nonce: ActionView::Helpers::AssetTagHelper.instance_method(:auto_include_nonce_for_styles),
    media: ActionView::Helpers::AssetTagHelper.instance_method(:apply_stylesheet_media_default),
    preload: ActionView::Helpers::AssetTagHelper.instance_method(:send_preload_links_header),
    sending: ActionDispatch::Response.instance_method(:sending?)
  }.transform_values { YjitEntryReader.state(RubyVM::InstructionSequence.of(_1)) }
  # Public each_object sees wrappers, not all internal ISeqs. The dump includes
  # IMEMO/iseq objects. Disable GC only in this untimed companion while retaining
  # their addresses; no raw heap dump or pointer is part of the public report.
  was_disabled = GC.disable
  wrappers = ObjectSpace.each_object(RubyVM::InstructionSequence).count
  counts = Hash.new(0)
  ObjectSpace.dump_all(output: :string).each_line do |line|
    next unless line.include?('"imemo_type":"iseq"')
    counts[:internal_iseqs] += 1
    row = JSON.parse(line)
    state = YjitEntryReader.state_at(Integer(row.fetch("address")))
    unless state
      counts[:unmaterialized_body] += 1
      next
    end
    counts[:payloads] += 1 if state.fetch(:payload)
    counts[:normal_entries] += 1 if state.fetch(:entry)
    counts[:exception_entries] += 1 if state.fetch(:exception_entry)
    %i[normal exception].each do |kind|
      entry, calls = kind == :normal ? state.values_at(:entry, :calls) : state.values_at(:exception_entry, :exception_calls)
      next if entry
      prefix = state.fetch(:payload) ? "payload" : "no_payload"
      bucket = calls.zero? ? "zero" : calls < state.fetch(:threshold) ? "pending" : "at_or_above_threshold"
      counts["#{prefix}_#{kind}_#{bucket}"] += 1
    end
  end
  { named: named, counts: counts, public_wrappers: wrappers,
    scope: "all dumped live IMEMO/iseq bodies; not a request reachability proof; companion allocations and GC pause alter timing" }
ensure
  GC.enable unless was_disabled
end

source = File.read(worker)
anchor = "    jit_warmup = JitStability.warm(rehearsal_requests: n, &workload)"
raise "certification anchor drift" unless source.scan(anchor).size == 1
source = source.sub(anchor, anchor + <<~'RUBY')

    warn "PENDING_ENTRY_CENSUS #{JSON.generate(pending_entry_census)}"
RUBY
eval(source, TOPLEVEL_BINDING, worker, 1)
warn "PENDING_ENTRY_FINAL #{JSON.generate(pending_entry_census)}"
