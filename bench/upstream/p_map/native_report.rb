# frozen_string_literal: true

# Native leaf buckets from native.sh's perf report (comm, dso, symbol, no
# children): share of the Puma threads' CPU samples (worker and reactor; the
# in-process client thread is left out).
#   ruby native_report.rb APP.perf.txt...
BUCKETS = [
  ["Kernel (syscalls, scheduling)", ->(dso, sym) { dso.include?("kernel") }],
  ["JIT code (YJIT)", ->(dso, sym) { dso.start_with?("perf-") || dso.include?("[JIT]") || sym.match?(/\A\[\.\] (\[unknown\]|0x)/) && dso == "[unknown]" }],
  ["SQLite engine + driver", ->(dso, sym) { dso.match?(/sqlite3/) }],
  ["libpq + pg driver", ->(dso, sym) { dso.match?(/libpq|pg_ext/) }],
  ["JSON (C)", ->(dso, sym) { dso.match?(/generator\.so|parser\.so|json/) }],
  ["OpenSSL", ->(dso, sym) { dso.match?(/libcrypto|libssl|openssl/) }],
  ["Other C extensions", ->(dso, sym) { dso.end_with?(".so") && !dso.match?(/\Alib(c|m|ruby|z|gmp|crypt|yaml|ffi)[.-]/) && !dso.start_with?("ld-") }],
  ["malloc/free (libc)", ->(dso, sym) { dso.start_with?("libc") && sym.match?(/malloc|free|realloc|calloc|tcache|_int_|arena|sysmalloc|consolidate/) }],
  ["libc other (memcpy, …)", ->(dso, sym) { dso.start_with?("libc") || dso.start_with?("libm") }],
  ["GC (mark/sweep/compact)", ->(dso, sym) { sym.match?(/gc_|rb_gc|mark|sweep|obj_free|objspace|heap_page|rgengc|compact|finaliz|imemo_free|rb_free_/) && !sym.match?(/newobj/) }],
  ["Object allocation", ->(dso, sym) { sym.match?(/newobj|rb_ec_|alloc|rb_str_new|str_new|rb_ary_new|ary_new|rb_hash_new|hash_alloc|rb_class_new_instance/) }],
  ["VM dispatch + interpreter", ->(dso, sym) { sym.match?(/vm_|rb_vm_|vm_exec|rb_call|call_cfunc|invoke|rb_funcall|method_entry|callable_method|rb_iterate|rb_yield|search_method|rb_managed_id_table|id_table|rb_method/) }],
  ["Ruby core C (String/Hash/Array/Regexp…)", ->(dso, sym) { true }],
].freeze

ARGV.each do |path|
  totals = Hash.new(0.0)
  total = 0.0
  File.foreach(path, chomp: true) do |line|
    next unless (m = line.match(/\A\s*([\d.]+)%\s+(.+?)\s{2,}(.+?)\s{2,}(\[.\] .*)\z/))
    pct, comm, dso, sym = m[1].to_f, m[2].strip, m[3], m[4].strip
    next unless comm.start_with?("puma srv tp") || comm == "puma reactor"
    bucket = BUCKETS.find { |_, test| test.call(dso, sym) }.first
    totals[bucket] += pct
    total += pct
  end
  puts "#{File.basename(path, ".perf.txt")}: #{total.round(1)}% of all samples on Puma threads"
  BUCKETS.each { |name, _| puts format("  %-42s %5.1f", name, 100 * totals[name] / total) if totals[name] > 0 }
end
