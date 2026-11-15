# frozen_string_literal: true

# Splits the "VM dispatch + interpreter" bucket of a frame-pointer perf
# profile (native.sh with PERF_CG=-g on a Ruby built with
# -fno-omit-frame-pointer, YJIT with --yjit-perf) by how the VM was entered:
#   perf script -i APP.perf.data -F comm,ip,sym,dso | ruby vm_split.rb [--top N]
# Each Puma-thread sample whose leaf is a VM function is walked up its stack to
# the first JIT frame. The kind comes from the VM entry point below that frame
# (a dynamic send from JIT code, a C method calling back into Ruby, the
# interpreter, or another runtime helper), and the JIT frame names the Ruby
# method or block whose compiled code got there. Allocation and GC samples are
# split the same way by the nearest Ruby (JIT) frame.
top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 25
via = ARGV.include?("--via") ? ARGV[ARGV.index("--via") + 1] : nil
via_callers = Hash.new(0)

VM = /\A(vm_|rb_vm_|vm_exec|rb_call|call_cfunc|invoke|rb_funcall|rb_iterate|rb_yield|search_method|rb_managed_id_table|rb_id_table|rb_method|callable_method|method_entry|rb_callable|rb_block_call|rb_lambda_call|rb_ec_|jit_exec)/
ALLOC = /newobj|rb_ec_wb|alloc|rb_str_new|str_new|rb_ary_new|ary_new|rb_hash_new|hash_alloc|rb_class_new_instance/
GCRE = /\A(gc_|rb_gc|mark|sweep|obj_free|objspace|heap_page|rgengc|compact|finaliz|imemo_free|rb_free_)/
DYNAMIC = /\Arb_vm_(opt_send_without_block|send|invokeblock|invokesuper|sendforward|invokesuperforward)\z/
CALLBACK = /\A(rb_funcall|rb_call0|rb_yield|vm_yield|rb_iterate|invoke_block_from_c|rb_vm_invoke_proc|rb_block_call|rb_lambda_call|vm_call0|rb_check_funcall|rb_obj_call_init|rb_proc_call|rb_eval_cmd|rb_method_call)/

def jit?(sym, dso) = dso.start_with?("/tmp/perf-") || sym.start_with?("[JIT]")

samples = Hash.new(0)
kinds = Hash.new(0)
callers = Hash.new { |h, k| h[k] = Hash.new(0) }
entries = Hash.new { |h, k| h[k] = Hash.new(0) }
total = 0
stack = []
comm = nil
flush = lambda do
  if comm && (comm.start_with?("puma srv tp") || comm == "puma reactor") && !stack.empty?
    total += 1
    leaf_sym, leaf_dso = stack.first
    bucket = if jit?(leaf_sym, leaf_dso) then :jit
    elsif !leaf_dso.include?("/ruby") then :other
    elsif leaf_sym.match?(GCRE) && !leaf_sym.match?(/newobj/) then :gc
    elsif leaf_sym.match?(ALLOC) then :alloc
    elsif leaf_sym.match?(VM) then :vm
    else :core
    end
    samples[bucket] += 1
    if %i[vm alloc gc].include?(bucket)
      idx = stack.index { |s, d| jit?(s, d) }
      native = idx ? stack[0...idx] : stack
      ruby_frame = idx ? stack[idx][0].sub(/\A\[JIT\] /, "") : "(no JIT frame)"
      kind = if bucket != :vm then bucket
      elsif native.any? { |s, _| s == "vm_exec_core" } && native.none? { |s, _| s.match?(CALLBACK) } then :interpreter
      elsif native.any? { |s, _| s.match?(CALLBACK) } then :c_calls_ruby
      elsif native.any? { |s, _| s.match?(DYNAMIC) } then :dynamic_send
      else :helper
      end
      entry = native.reverse.find { |s, d| d.include?("/ruby") }&.first || "?"
      via_callers[ruby_frame] += 1 if via && native.any? { |s, _| s == via }
      kinds[kind] += 1
      callers[kind][ruby_frame] += 1
      entries[kind][entry] += 1
    end
  end
  stack = []
end
$stdin.each_line(chomp: true) do |line|
  if line.empty?
    flush.call
    comm = nil
  elsif line.start_with?("\t") || line.start_with?(" ")
    m = line.strip.match(/\A\h+ (.*) \((.*)\)\z/) or next
    stack << [m[1].sub(/\+0x\h+\z/, ""), m[2]]
  else
    flush.call
    comm = line.strip.sub(/\s+\d+\z/, "")
  end
end
flush.call

puts format("Puma samples %d: JIT %.1f%%, VM %.1f%%, allocation %.1f%%, GC %.1f%%, core C %.1f%%, other %.1f%%",
  total, *%i[jit vm alloc gc core other].map { 100.0 * samples[_1] / total })
if via
  puts "\nvia #{via}: #{format("%.2f%%", 100.0 * via_callers.values.sum / total)}"
  via_callers.sort_by { -_2 }.first(top).each { |f, c| puts format("  %6.2f%%  %s", 100.0 * c / total, f) }
  exit
end
kinds.sort_by { -_2 }.each do |kind, n|
  puts format("\n%s: %.2f%% of Puma samples", kind, 100.0 * n / total)
  puts "  entry points: " + entries[kind].sort_by { -_2 }.first(8).map { |e, c| format("%s %.2f%%", e, 100.0 * c / total) }.join(", ")
  callers[kind].sort_by { -_2 }.first(top).each { |f, c| puts format("  %6.2f%%  %s", 100.0 * c / total, f) }
end
