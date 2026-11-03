# frozen_string_literal: true

# Reads one Callgrind window dump written with --dump-instr=yes --compress-strings=no
# --compress-pos=no and attributes its Ir (docs/upstream/zjit-yjit-gap.md):
#   * self Ir per C/Rust function;
#   * self Ir of JIT code per perf-map symbol (--zjit-perf=iseq|hir, --yjit-perf=iseq|codegen);
#   * calls and inclusive Ir per call edge, with JIT callers named by their perf-map symbol.
# The empty window (.1) is subtracted key by key and every number is divided by K.
#   ruby SCRIPT WINDOW_K.callgrind WINDOW_0.callgrind PERF_MAP K OUT.json
require "json"

window, empty, perf_map, k, out = ARGV
k = Float(k)

ranges = File.foreach(perf_map).filter_map do |line|
  start, size, name = line.chomp.split(" ", 3)
  [Integer(start, 16), Integer(size, 16), name.sub(/\AZJIT: /, "")]
end.sort_by!(&:first)
starts = ranges.map(&:first)

symbol_at = lambda do |addr|
  i = starts.bsearch_index { |s| s > addr }
  i = (i || starts.size) - 1
  next "<unmapped JIT>" if i.negative?
  start, size, name = ranges[i]
  addr < start + size ? name : "<unmapped JIT>"
end

def clean(name) = name.sub(/'\d+\z/, "")

parse = lambda do |path|
  self_ir = Hash.new(0)
  jit_self = Hash.new(0)
  edges = Hash.new { |h, key| h[key] = [0, 0] }
  ob = fn = cob = cfn = nil
  pending_calls = nil
  jit_cache = {}
  File.foreach(path) do |line|
    case line
    when /\Aob=(.*)/ then ob = $1
    when /\Afn=(.*)/ then fn = clean($1)
    when /\Acob=(.*)/ then cob = $1
    when /\Acfn=(.*)/ then cfn = clean($1)
    when /\Acalls=(\d+) /
      pending_calls = Integer($1)
    when /\A0x([0-9a-f]+) \d+ (\d+)/
      addr = $1.to_i(16)
      cost = Integer($2)
      caller = ob == "???" ? "JIT:" + (jit_cache[addr] ||= symbol_at.(addr)) : fn
      if pending_calls
        callee = cob == "???" || cfn.start_with?("0x") ? "<JIT code>" : cfn
        e = edges[[caller, callee]]
        e[0] += pending_calls
        e[1] += cost
        pending_calls = nil
        cob = nil
      elsif ob == "???"
        jit_self[caller.delete_prefix("JIT:")] += cost
        self_ir["<JIT code>"] += cost
      else
        self_ir[fn] += cost
      end
    end
  end
  [self_ir, jit_self, edges]
end

a = parse.(window)
b = parse.(empty)
sub = ->(x, y) { (x.keys | y.keys).to_h { |key| [key, (x[key] - y[key]) / k] }.reject { |_, v| v.abs < 1 } }
self_ir = sub.(a[0], b[0])
jit_self = sub.(a[1], b[1])
edges = (a[2].keys | b[2].keys).filter_map do |key|
  ca, ia = a[2].fetch(key, [0, 0])
  cb, ib = b[2].fetch(key, [0, 0])
  calls = (ca - cb) / k
  incl = (ia - ib) / k
  [key[0], key[1], calls.round(2), incl.round] if calls.abs >= 0.5 || incl.abs >= 1000
end
File.write(out, JSON.generate(total: self_ir.values.sum, self: self_ir, jit: jit_self, edges:))
