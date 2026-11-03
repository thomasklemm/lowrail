# frozen_string_literal: true

# Where JSON serialization spends time, from stackprof raw dumps
# (docs/upstream/serialization-cpu.md).
#   ruby rank.rb [--top N] [--frames] [--within] DUMP...
# --within keeps only samples under a serialization root (ROOT below): as_json,
# to_json, serializable_hash, JSON encode/generate, jbuilder, serializer gems.
# Self: each non-GC sample is charged to its nearest Ruby frame, except that
# the C functions named in OWN_CFUNCS keep their own samples (the JSON
# generator, the escape's gsub!/tr!, Time#xmlschema, BigDecimal#to_s). The
# owner's file decides the area. Inclusive: share of samples with a frame of
# the area anywhere on the stack.
require "stackprof"

top = 30
show_frames = false
within = nil
args = ARGV.dup
while args.first&.start_with?("--")
  case args.shift
  when "--top" then top = Integer(args.shift)
  when "--frames" then show_frames = true
  when "--within" then within = true
  end
end

OWN_CFUNCS = /\A(JSON::Ext::Generator::State#generate|JSON::Coder#dump|JSON::Ext::Generator::GeneratorMethods::.*|JSON\.generate|JSON::Ext::Generator::State\.generate|String#(gsub!|tr!)|Time#(xmlschema|iso8601|strftime)|BigDecimal#to_s|Oj\.\w+|Oj::Rails.*)\z/
GCNAMES = ["(marking)", "(sweeping)", "(garbage collection)"].freeze
ROOT = lambda do |n, f|
  n.match?(/#(as_json|to_json|serializable_hash)\z|\AActiveSupport::JSON\.encode\z|\AJSON(::Coder#dump|\.generate|::Ext::Generator::State#generate)\z/) ||
    f.match?(%r{/(jbuilder|active_model_serializers|alba|blueprinter|panko_serializer|jsonapi-serializer|oj_serializers)-[\d.]+/})
end

AREAS = [
  ["JSON escape (gsub!/tr!)", ->(n, f) { n.match?(/\AString#(gsub!|tr!)\z/) || (f.include?("active_support/json/encoding.rb") && n.include?("escape!")) }],
  ["json gem generator (C)", ->(n, f) { n.start_with?("JSON::") && (f == "<cfunc>" || f.include?("/json-")) }],
  ["Oj", ->(n, f) { n.start_with?("Oj") || f.include?("/oj-") }],
  ["AS JSON encoder (encode, Coder proc)", ->(n, f) { f.include?("active_support/json/encoding.rb") }],
  ["Time/Date/BigDecimal as_json", ->(n, f) { n.match?(/\A(Time#(xmlschema|iso8601|strftime)|BigDecimal#to_s)\z/) || (n.include?("as_json") && f.match?(%r{time_with_zone|core_ext/object/json.rb}) && n.match?(/Time|Date|BigDecimal/)) || (f.include?("time_with_zone.rb") && n.match?(/xmlschema|iso8601|utc|time/)) }],
  ["AS as_json (Hash/Array/Object)", ->(n, f) { f.include?("core_ext/object/json.rb") }],
  ["Active Model serialization", ->(n, f) { f.match?(%r{active_model/(serialization|serializers/json)\.rb|active_record/serialization\.rb}) }],
  ["index_with", ->(n, f) { f.include?("core_ext/enumerable.rb") }],
  ["attribute reads", ->(n, f) { f.match?(%r{active_model/(attribute|attribute_set|attribute_set/|indexed_row|type/)|active_record/(attribute_methods|type/|enum)|active_model/attribute_methods}) }],
  ["jbuilder", ->(n, f) { f.include?("/jbuilder-") }],
  ["active_model_serializers", ->(n, f) { f.include?("/active_model_serializers-") }],
  ["alba / other serializer gems", ->(n, f) { f.match?(%r{/(alba|blueprinter|panko_serializer|jsonapi-serializer|fast_jsonapi|rabl|oj_serializers)-}) }],
  ["inertia_rails", ->(n, f) { f.include?("/inertia_rails-") }],
  ["Active Record (queries, associations, other)", ->(n, f) { f.include?("/activerecord/lib/") }],
  ["Active Model (other)", ->(n, f) { f.include?("/activemodel/lib/") }],
  ["Action View", ->(n, f) { f.include?("/actionview/lib/") }],
  ["Action Pack, Rack", ->(n, f) { f.match?(%r{/actionpack/lib/|/rack-[\d.]+/}) }],
  ["Active Support (other)", ->(n, f) { f.include?("/activesupport/lib/") }],
  ["database driver (pg, sqlite3)", ->(n, f) { f.match?(%r{/(pg|sqlite3)-[\d.]+}) || n.match?(/\A(PG::|SQLite3::)/) }],
  ["app code", ->(n, f) { f.start_with?(Dir.pwd) || f.match?(%r{/\.corpus/[^/]+/(app|lib)/}) }],
  ["other gems", ->(n, f) { f.include?("/gems/") }],
  ["Ruby stdlib", ->(n, f) { f.include?("/lib/ruby/4.") }],
].freeze
INCL = AREAS.first(13) + [
  ["inside to_json/AS::JSON.encode", ->(n, f) { n.match?(/to_json|ActiveSupport::JSON\.encode/) }],
  ["inside as_json/serializable_hash", ->(n, f) { n.match?(/#(as_json|serializable_hash)\z/) }],
  ["inside json renderer (render json:)", ->(n, f) { f.include?("action_controller/metal/renderers.rb") }],
]

def short(file)
  file.to_s.sub(%r{.*/(activerecord|activemodel|activesupport|actionpack|actionview|railties)/lib/}, "").
    sub(%r{.*/gems/}, "GEM/").sub(%r{.*/lib/ruby/[\d.]+/}, "RUBY/")
end

names = []
self_area = Hash.new { |h, k| h[k] = {} }
incl_area = Hash.new { |h, k| h[k] = {} }
frame_self = Hash.new { |h, k| h[k] = {} }
totals = {}
args.each do |path|
  name = File.basename(path, ".dump")
  names << name
  d = Marshal.load(File.binread(path))
  frames = d[:frames]
  raw = d[:raw]
  info = Hash.new { |h, a| f = frames[a] || {}; h[a] = [f[:name].to_s, f[:file].to_s] }
  cfunc = Hash.new { |h, a| n, f = info[a]; h[a] = f == "<cfunc>" && !n.match?(OWN_CFUNCS) }
  area_of = Hash.new { |h, a| n, f = info[a]; h[a] = AREAS.find { |_, m| m.(n, f) }&.first }
  root = Hash.new { |h, a| n, f = info[a]; h[a] = ROOT.(n, f) }
  incl_of = Hash.new { |h, a| n, f = info[a]; h[a] = INCL.select { |_, m| m.(n, f) }.map(&:first) }
  total = 0
  gc = 0
  sa = Hash.new(0)
  ia = Hash.new(0)
  fs = Hash.new(0)
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    w = raw[i + 1 + len]
    i += len + 2
    next if within && stack.none? { root[_1] }
    total += w
    if GCNAMES.include?(info[stack.last][0])
      gc += w
      next
    end
    j = stack.size - 1
    j -= 1 while j > 0 && cfunc[stack[j]]
    owner = stack[j]
    sa[area_of[owner] || "other"] += w
    fs[owner] += w
    stack.flat_map { incl_of[_1] }.uniq.each { ia[_1] += w }
  end
  totals[name] = [total, gc]
  sa.each { |k, v| self_area[k][name] = 100.0 * v / total }
  ia.each { |k, v| incl_area[k][name] = 100.0 * v / total }
  fs.each { |a, v| n, f = info[a]; frame_self["#{n} (#{short(f)})"][name] = 100.0 * v / total }
end

mean = ->(h) { names.sum { h[_1] || 0 } / names.size }
cells = ->(h) { names.map { format("%.1f", h[_1] || 0) } }
puts (["", "mean"] + names.map { _1.sub(/-interpreter\z/, "-i").sub(/-yjit\z/, "-y") }).join("\t")
puts (["samples", ""] + names.map { totals[_1][0].to_s }).join("\t")
puts (["GC %", ""] + names.map { format("%.1f", 100.0 * totals[_1][1] / totals[_1][0]) }).join("\t")
puts "\n## Self time by area (% of all samples)"
self_area.sort_by { -mean.(_2) }.each { |k, h| puts ([k, format("%.1f", mean.(h))] + cells.(h)).join("\t") }
puts "\n## Inclusive (% of all samples with a frame of the area on the stack)"
incl_area.sort_by { -mean.(_2) }.each { |k, h| puts ([k, format("%.1f", mean.(h))] + cells.(h)).join("\t") }
if show_frames
  puts "\n## Top frames by self time"
    frame_self.sort_by { -mean.(_2) }.first(top).each { |k, h| puts ([k[0, 90], format("%.2f", mean.(h))] + cells.(h)).join("\t") }
end
