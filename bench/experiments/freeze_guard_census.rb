# frozen_string_literal: true

# Untimed, native operation census, never a measured worker or a pass.
# LOWRAIL=1 mise exec -- ruby bench/experiments/freeze_guard_census.rb
# Requires inertia_rails 3.22.0 and the explicitly compiled optional extension.
$LOAD_PATH.unshift(File.expand_path("../../gem/lib", __dir__))
require "active_support/all"
gem "inertia_rails", "3.22.0"
require "inertia_rails/configuration"
%w[prop_cacheable prop_onceable prop_mergeable base_prop ignore_on_first_load_prop always_prop lazy_prop optional_prop
  cached_prop defer_prop merge_prop once_prop scroll_metadata scroll_prop props_resolver].each { require "inertia_rails/#{_1}" }
require "lowrail"
require "lowrail/guard"
require "lowrail/manifest"
require "lowrail/inertia_props_build"
require "lowrail/freeze_audit"
require "lowrail/endpoint"

# Exercise the actual endpoint checks with positive cached method facts. This
# does not certify an endpoint or activate the quarantined endpoint pass.
class CensusView
  def link_to = "link"
  def _run = "run"
  def compiled = "template"
end
entry = Lowrail::Endpoint::Entry.allocate
entry.instance_variable_set(:@helper, CensusView.instance_method(:link_to))
entry.instance_variable_set(:@run, CensusView.instance_method(:_run))
entry.instance_variable_set(:@runners, [])
entry.instance_variable_set(:@compiled, {compiled: CensusView.instance_method(:compiled)})
entry.instance_variable_set(:@templates, {"path" => {"locals" => []}})
view = CensusView.new
template = Struct.new(:identifier).new("path")
built = Lowrail::InertiaPropsBuild.build
raise built[:ledger].inspect unless built[:units].size == 1
built[:units][0]["id"] = 0
manifest = Lowrail::Manifest.new({"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
  "certification_jit" => Lowrail.jit_mode, "compile_option" => Lowrail::Manifest.compile_option_fingerprint,
  "files" => {}, "units" => built[:units]}, Dir.pwd, root: Dir.pwd)
raise manifest.refusal_reason if manifest.refusal_reason
Lowrail::Guard.install(manifest)
runtime = Lowrail::Passes::InertiaProps
runtime.install(manifest.units)
runtime.activate
raise "not valid" unless runtime.valid?(0, {})
counts = Hash.new(0)
trace = TracePoint.new(:call, :c_call) do |event|
  if %i[class singleton_class public_method_defined? instance_method bind_call exact_class?].include?(event.method_id)
    counts["#{event.defined_class}##{event.method_id}"] += 1
  end
end
trace.enable { 10.times { raise "guard declined" unless runtime.valid?(0, {fresh: 7}) } }
before = counts.dup
counts.clear
trace.enable { 10.times { raise "helper declined" unless entry.helper_current?(view) } }
helper = counts.dup
counts.clear
trace.enable { 10.times { raise "template declined" unless entry.template_current?(view, :compiled, template, {}, "path") } }
compiled = counts.dup
counts.clear
ENV["LOWRAIL_FREEZE"] = "1"
session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Hash, Enumerable, CensusView]).start!
# Conditional residual only: deliberately NOT substituted into any real guard.
trace.enable { 10.times { raise "native declined" unless Lowrail::Native.exact_class?({fresh: 7}, Hash) } }
puts JSON.pretty_generate({operations: 10, existing_guard: before, residual_native: counts,
  endpoint_helper: helper, endpoint_template_cached: compiled,
  freeze_audit: session.finish!.slice("frozen_error_count", "status")})
