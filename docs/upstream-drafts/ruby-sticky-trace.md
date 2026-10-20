# Unpublished note: disabled global return tracing still costs steady-state work

Local investigation only, 2026-10-20. **No upstream issue or post submitted.**
Observed on Ruby 4.0.7 (`229531a6cf`) and 4.1.0-preview1 (`2d08b5f42f`), Linux
x86-64. This is an intentional implementation tradeoff visible in source,
not a confirmed Ruby correctness bug or a violated documented API promise.

## Reproduction

Run each mode in a fresh process with `ruby --yjit --yjit-stats=quiet`:

```ruby
class Example
  def boot = self
  def hot(x) = x * 3 + 7
end
object = Example.new
mode = ENV.fetch("MODE", "off")
unless mode == "off"
  trace = TracePoint.new(:return) {}
  mode == "targeted" ? trace.enable(target: Example.instance_method(:boot)) : trace.enable
  object.boot
  trace.disable
end
2000.times { object.hot(19) }
before = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave)
1000.times { object.hot(19) }
puts RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave) - before
```

Off and targeted print **0**; global prints **1000**, on both pins. No
callback remains enabled. The separately gated
[Lowrail micro](../passes/yjit-regression.md) prices +157 YJIT and +72
interpreter Ir per hot call on 4.0.7 after global enable/disable. A targeted
boot-only cycle exactly matches off. This is not a throughput claim.

## Mechanism and source evidence

The historical mask only grows: [4.0 `vm_trace.c:107–173`](https://github.com/ruby/ruby/blob/229531a6cf/vm_trace.c#L107-L173),
[4.1:122–193](https://github.com/ruby/ruby/blob/2d08b5f42f/vm_trace.c#L122-L193).
The source says `ruby_vm_event_enabled_global_flags |= new_events; // NOTE:
this is only ever added to`. Existing ISeqs are rewritten when a new global
event bit appears; disabling removes the live hook, not that historical bit.
Future ISeqs inherit it too: [4.0 `iseq.c:776–808`](https://github.com/ruby/ruby/blob/229531a6cf/iseq.c#L776-L808),
[4.1:875–907](https://github.com/ruby/ruby/blob/2d08b5f42f/iseq.c#L875-L907).

`rb_iseq_trace_set` passes `remain_traced = true`:
[4.0:4174–4176](https://github.com/ruby/ruby/blob/229531a6cf/iseq.c#L4174-L4176),
[4.1:4317–4319](https://github.com/ruby/ruby/blob/2d08b5f42f/iseq.c#L4317-L4319).
The disabled rewrite is explicitly compiled out: “do not disable trace
because of performance problem (re-enable overhead)” in
[4.0 `vm_insnhelper.c:7317–7327`](https://github.com/ruby/ruby/blob/229531a6cf/vm_insnhelper.c#L7317-L7327),
[4.1:7566–7576](https://github.com/ruby/ruby/blob/2d08b5f42f/vm_insnhelper.c#L7566-L7576).
Thus the interpreter still enters tracing machinery even without a callback.

Targeted enable connects local hooks with `global_p == FALSE`, and targeted
disable rewrites local instructions with `remain_traced = false`:
[4.0 `vm_trace.c:1478–1518`](https://github.com/ruby/ruby/blob/229531a6cf/vm_trace.c#L1478-L1518),
[4.0 `iseq.c:4108–4114`](https://github.com/ruby/ruby/blob/229531a6cf/iseq.c#L4108-L4114),
[4.1:4251–4257](https://github.com/ruby/ruby/blob/2d08b5f42f/iseq.c#L4251-L4257).
That cannot undo a prior *global* return bit; targeted-only boot avoids it.

YJIT has normal `leave` codegen but no `trace_leave` arm, so the default
unimplemented-opcode path exits to the interpreter:
[4.0 `codegen.rs:10789–10802`](https://github.com/ruby/ruby/blob/229531a6cf/yjit/src/codegen.rs#L10789-L10802),
[side exit:1405–1415](https://github.com/ruby/ruby/blob/229531a6cf/yjit/src/codegen.rs#L1405-L1415),
[4.1 dispatch:11019–11032](https://github.com/ruby/ruby/blob/2d08b5f42f/yjit/src/codegen.rs#L11019-L11032).
`exit_trace_leave` is the generic instruction-indexed exit statistic, not a
hand-declared counter with that name in stats.rs.

Disasm/to_a are not executable-opcode inspections: the decoder deliberately
“returns bare instructions even if they're trace/zjit instructions”:
[4.0 `iseq.c:3904–3915`](https://github.com/ruby/ruby/blob/229531a6cf/iseq.c#L3904-L3915),
[4.1:4048–4059](https://github.com/ruby/ruby/blob/2d08b5f42f/iseq.c#L4048-L4059).
Both use `rb_iseq_original_iseq`; matching printed `leave` is expected.

## Design or bug?

`TracePoint#disable` promises callback deactivation, not restoration of
bytecodes/JIT shape: [both pins, `trace_point.rb:266–299`](https://github.com/ruby/ruby/blob/229531a6cf/trace_point.rb#L266-L299).
The sticky mask and disabled rewrite are explicit implementation decisions.
The **performance consequence** deserves an upstream question if authorized:
could YJIT compile a trace return guarded by the *live* event mask, or could
the VM restore instructions after the last global hook without unacceptable
re-enable overhead? Neither is implemented or validated here. Do not mutate
private VM fields or claim a supported public reset API.
