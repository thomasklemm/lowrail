# frozen_string_literal: true

# Schema-context access in a census app (docs/upstream/schema-context.md).
# Run like census_prof.rb, inside a census copy with its variant bundle:
#   CENSUS_RAILS_SHA=... CENSUS_MODE=interpreter BUNDLE_GEMFILE=Gemfile.census-SHA12 \
#     bundle exec ruby census_probe.rb APP OUT.json
# After warming every workload, runs each once more with a TracePoint counting
# calls to ModelSchema::ClassMethods#schema_context and SchemaContext#attributes
# (by caller line, and whether #attributes took the fast path), then classifies
# every loaded model: fast path (@attributes set) or slow, and why.
require_relative "../census/harness"
require "json"

name, out = ARGV
RailsCensus.boot(name)
ops = RailsCensus.workloads(name)
warmup = Integer(ENV.fetch("CENSUS_WARMUP", "20"))
ops.each { |op| warmup.times { op.call.call; RailsCensus.reset_side_effects } }

SC = ActiveRecord::ModelSchema::SchemaContext
CM = ActiveRecord::ModelSchema::ClassMethods
ROOT = File.expand_path(".")
def site(loc)
  return "?" unless loc
  path = loc.path.sub(%r{.*/(activerecord|activemodel|activesupport|actionpack|actionview)/lib/}, "").sub(ROOT + "/", "APP/").sub(%r{.*/gems/}, "GEM/")
  "#{path}:#{loc.lineno} #{loc.label}"
end

workloads = ops.map do |op|
  call = op.call
  ctx = Hash.new(0)
  attrs = Hash.new(0)
  slow = 0
  tp = TracePoint.new(:call) do |t|
    if t.method_id == :schema_context && t.defined_class == CM
      ctx[caller_locations(2, 2).map { site(_1) }.join(" <- ")] += 1
    elsif t.method_id == :attributes && t.defined_class == SC
      attrs[caller_locations(2, 3).map { site(_1) }.join(" <- ")] += 1
      slow += 1 unless t.self.instance_variable_get(:@attributes)
    end
  end
  tp.enable { call.call }
  RailsCensus.reset_side_effects
  { workload: op.name, kind: op.kind, schema_context: ctx.values.sum, attributes: attrs.values.sum, attributes_slow: slow,
    schema_context_sites: ctx.sort_by { -_2 }.first(15).to_h, attributes_sites: attrs.sort_by { -_2 }.first(15).to_h }
end

def why_slow(model, ctx)
  defaults = ctx.attributes.defaults
  return nil if ctx.instance_variable_get(:@attributes)
  if defaults.read_only?
    types = defaults.cast_types.reject { |_, t| Ractor.shareable?(t) }
    { reason: "types not shareable", detail: types.map { |n, t| "#{n}: #{t.class}" }.first(5) }
  else
    attrs = defaults.instance_variable_get(:@attributes)
    attrs = attrs.respond_to?(:values) ? attrs : {}
    unfreezable = attrs.reject { |_, a| a.freezable? }
    { reason: "defaults not freezable",
      detail: unfreezable.map { |n, a| "#{n}: #{a.class.name.split("::").last}#{a.class.name.end_with?("UserProvidedDefault") ? (a.send(:user_provided_value).is_a?(Proc) ? " (Proc)" : " (#{a.send(:user_provided_value).class})") : ""}" }.first(8) }
  end
end

# Every reason a slow model misses the fast path, one entry per attribute:
# tzc (TimeZoneConverter whose subtype is shareable, so freezing the converter
# would suffice), unfrozen types by class, and unfreezable defaults by value.
def blockers(ctx)
  attrs = ctx.attributes.defaults.instance_variable_get(:@attributes)
  attrs = attrs.respond_to?(:values) ? attrs : {}
  attrs.filter_map do |_, a|
    if !a.freezable?
      v = a.send(:user_provided_value)
      "default #{v.is_a?(Proc) ? "Proc" : (v.frozen? && Ractor.shareable?(v) ? "shareable #{v.class}" : "unshareable #{v.class}")}"
    elsif !Ractor.shareable?(a.type)
      t = a.type
      if t.is_a?(ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter)
        Ractor.shareable?(t.subtype) ? "tzc" : "tzc over unshareable #{t.subtype.class}"
      else
        "type #{t.class}"
      end
    end
  end.tally
end

models = ActiveRecord::Base.descendants.filter_map do |m|
  next if m.abstract_class?
  ctx = m.current_schema_context
  next unless ctx&.schema_loaded?
  w = why_slow(m, ctx)
  { model: m.name || m.inspect, path: w ? "slow" : "fast", **(w || {}), **(w ? { blockers: blockers(ctx) } : {}) }
end

File.write(out, JSON.pretty_generate(app: name, workloads: workloads, models: models))
slow = models.count { _1[:path] == "slow" }
puts "#{name}: #{models.size} loaded models, #{slow} slow; #{workloads.size} workloads, " \
  "schema_context #{workloads.sum { _1[:schema_context] }}, attributes #{workloads.sum { _1[:attributes] }} (slow #{workloads.sum { _1[:attributes_slow] }})"
