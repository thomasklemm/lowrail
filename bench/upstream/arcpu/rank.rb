# frozen_string_literal: true

# Rank Active Record / Active Model / Arel frames by self and inclusive time
# across stackprof raw dumps.
#   self  = samples whose nearest Ruby frame is this frame (C functions it calls
#           are charged to it; GC samples are charged to "(gc)")
#   incl  = samples with this frame anywhere on the stack
# Usage: ruby rank.rb [--top N] [--all] [--buckets] DUMP...
require "stackprof"

top = 40
all = false
buckets_only = false
args = ARGV.dup
while args.first&.start_with?("--")
  case args.shift
  when "--top" then top = Integer(args.shift)
  when "--all" then all = true
  when "--buckets" then buckets_only = true
  end
end

AR = %r{/(activerecord|activemodel)/lib/(active_record|active_model|arel)}
def short(file)
  file.sub(%r{.*/(activerecord|activemodel|activesupport|actionpack|actionview|railties|activejob)/lib/}, "").
    sub(%r{.*/gems/}, "GEM/").sub(%r{.*/lib/ruby/[\d.]+/}, "RUBY/")
end

# Coarse buckets for the AR/AM/Arel self time.
BUCKETS = [
  ["arel", %r{/arel/}],
  ["statement cache", %r{statement_cache\.rb}],
  ["predicate builder", %r{relation/predicate_builder}],
  ["where/merge/spawn", %r{relation/(where_clause|merger|spawn_methods|query_attribute|from_clause)|table_metadata}],
  ["query methods/build_arel", %r{relation/query_methods}],
  ["relation core/delegation", %r{active_record/(relation\.rb|relation/delegation|relation/finder_methods|relation/calculations|association_relation|null_relation)}],
  ["scoping/default scope", %r{active_record/scoping}],
  ["associations/reflection", %r{active_record/(associations|reflection|autosave)}],
  ["connection/query cache/instrumentation", %r{connection_adapters/(abstract/(connection_pool|query_cache|transaction)|pool_config|pool_manager)|connection_handling|runtime_registry|query_intent|connection_adapters/abstract_adapter|log_subscriber|railties|explain_registry|query_logs}],
  ["adapter execute", %r{connection_adapters/(abstract/database_statements|sqlite3|postgresql|mysql|trilogy|abstract/quoting)}],
  ["result/instantiate", %r{active_record/(result|querying|core|inheritance|persistence|model_schema|timestamp|readonly)}],
  ["attribute set/cast", %r{active_model/(attribute|attribute_set|indexed_row|type)|active_record/(type|attribute_methods|attributes|enum)}],
]
def bucket(file)
  BUCKETS.each { |name, re| return name if file.match?(re) }
  "other AR/AM"
end

rows = Hash.new { |h, k| h[k] = {} }
bucket_rows = Hash.new { |h, k| h[k] = Hash.new(0) }
totals = {}
GCNAMES = ["(marking)", "(sweeping)", "(garbage collection)"].freeze
args.each do |path|
  name = File.basename(path, ".dump")
  d = Marshal.load(File.binread(path))
  frames = d[:frames]
  raw = d[:raw]
  ar = Hash.new { |h, a| f = frames[a]; h[a] = f && f[:file]&.match?(AR) }
  cfunc = Hash.new { |h, a| f = frames[a]; h[a] = f.nil? || f[:file] == "<cfunc>" }
  total = 0
  self_s = Hash.new(0)
  incl = Hash.new(0)
  incl_ar = 0
  self_ar = 0
  gc = 0
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    w = raw[i + 1 + len]
    i += len + 2
    total += w
    leaf = stack.last
    if GCNAMES.include?(frames[leaf]&.[](:name))
      gc += w
    else
      j = stack.size - 1
      j -= 1 while j > 0 && cfunc[stack[j]]
      owner = stack[j]
      self_s[owner] += w
      if ar[owner]
        self_ar += w
        bucket_rows[bucket(frames[owner][:file])][name] += w
      end
    end
    seen = {}
    any = false
    stack.each do |f|
      next if seen[f]
      seen[f] = true
      incl[f] += w
      any ||= ar[f]
    end
    incl_ar += w if any
  end
  totals[name] = [total, incl_ar, self_ar, gc]
  frames.each do |addr, f|
    next unless all || ar[addr]
    key = "#{f[:name]} (#{short(f[:file].to_s)}:#{f[:line]})"
    r = rows[key][name] ||= [0, 0]
    r[0] += self_s[addr]
    r[1] += incl[addr]
  end
end

names = totals.keys
mean = ->(a) { a.sum / a.size }
puts "dump\tsamples\tAR-on-stack%\tAR-self%\tGC%"
totals.each { |n, (t, ia, sa, g)| puts format("%s\t%d\t%.1f\t%.1f\t%.1f", n, t, 100.0 * ia / t, 100.0 * sa / t, 100.0 * g / t) }

puts "\n## AR/AM/Arel self time by bucket (% of all samples)"
puts (["mean"] + names + ["bucket"]).join("\t")
bucket_rows.map { |k, h| [k, names.map { |n| 100.0 * h[n] / totals[n][0] }] }.sort_by { -mean.(_2) }.each do |k, v|
  puts ([format("%.2f", mean.(v))] + v.map { format("%.2f", _1) } + [k]).join("\t")
end
exit if buckets_only

pct = ->(key, idx) { names.map { |n| v = rows[key][n]; v ? 100.0 * v[idx] / totals[n][0] : 0.0 } }
[[0, "SELF (incl. C functions called)"], [1, "INCLUSIVE"]].each do |idx, label|
  puts "\n## #{label} (% of all samples; mean over dumps, dumps >= 0.1%, then per dump)"
  puts (["mean", "n"] + names + ["frame"]).join("\t")
  rows.keys.map { |k| [k, pct.(k, idx)] }.sort_by { |_, v| -mean.(v) }.first(top).each do |k, v|
    puts ([format("%.2f", mean.(v)), v.count { _1 >= 0.1 }] + v.map { format("%.2f", _1) } + [k]).join("\t")
  end
end
