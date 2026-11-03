# ZJIT `Kernel#send` specialization (bet J1)

**Result: stopped before building.** A ZJIT maintainer already has an open draft for the same specialization:
[ruby/ruby#19583](https://github.com/ruby/ruby/pull/19583) "ZJIT: Support .send(:symbol)" (tekknolagi, draft,
opened 2026-10-28, head `9dd8e0f6f6`, no reviews). Its motivating site is TZInfo `Timestamp.new!`, the
census's second site. It rewrites `recv.send(:name, args...)` with a constant Symbol into an ordinary
`recv.name(args...)` send in `type_specialize`. It adds a `MethodRedefined` patch point on `send`, a frame
state without the name, `FCALL | OPT_SEND` call info so visibility is ignored, refuses missing methods
(`method_missing`), refuses nested `send(:send, …)`, and refuses keywords, splats and block args. That is the
prototype this bet would have built, so a second PR would duplicate it. No fork branch was pushed.

The census search had missed #19583 because its title says `.send(:symbol)` and not "Kernel#send" or
"optimized method type".

## What is at stake on ruby-bench

ruby/ruby master [`2bc6f9a60e`](https://github.com/ruby/ruby/commit/2bc6f9a60e) (2026-11-03), release build,
`--enable-zjit --enable-yjit`. ruby-bench [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2) with
the harness [`ruby_bench_zjit_send.rb`](../../bench/upstream/ruby_bench_zjit_send.rb): `--zjit --zjit-stats`,
15 warmup iterations, `reset_stats!`, then the mean over 10 iterations. `Kernel#send` fallbacks are
`unspecialized_send_def_type_optimized_send`.

| Benchmark | sends/itr | dynamic sends/itr | `Kernel#send` fallbacks/itr | share of sends | share of dynamic |
| --- | ---: | ---: | ---: | ---: | ---: |
| railsbench | 15,190,357 | 1,065,952 | 41,673 | 0.274% | 3.91% |
| lobsters | 7,113,631 | 745,817 | 25,616 | 0.360% | 3.43% |
| shipit | 14,623,050 | 1,714,254 | 70,004 | 0.479% | 4.08% |
| erubi-rails | 16,250,004 | 1,200,001 | 0 | 0 | 0 |

Top sites (Fuchsia fallback traces at 1/20 sampling, [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb)):

* railsbench: TZInfo `Timestamp.new!` (`send(:initialize!, …)`), `OptimizedUrlHelper#optimize_routes_generation?`,
  `Session::Options#id` and `Session#exists?` (`send(:extract_session_id, req)`), `ExecutionWrapper` run and complete
  hooks (`send(:hook_state)`). These are all constant names. Arel and Journey visitors are minor here.
* lobsters: TZInfo `Timestamp.new!`, Arel `Visitor#visit`, Psych visitor, `optimize_routes_generation?`, Journey.
* shipit: TZInfo, Arel `Visitor#visit`, active_model_serializers 0.9 (`Serializer#attributes`: `send(name)` per
  attribute, and `associate`'s generated readers: `object.send attr`), Journey.

### Per-call cost (micro)

[`zjit_send_micro.rb`](../../bench/upstream/zjit_send_micro.rb), best of 5 × 20 M calls, ns/call, at #19583's base
`637bd7cba1` (`prbase`) and head (`pr`):

| | direct call | `send(:visit_a, …)` | `send(m, …)`, one name | `send(m, …)`, four names |
| --- | ---: | ---: | ---: | ---: |
| prbase, ZJIT | 1.9 | 63.2 | 63.5 | 78.8 |
| #19583, ZJIT | 2.6 | 7.4 | 70.4 | 84.6 |
| prbase, YJIT | 2.2 | 72.3 | 71.6 | 101.2 |

The callee is trivial and gets inlined, so about 56 ns per call is an upper bound on the saving.

### Bar check

The upper bound is the fallbacks #19583 removes multiplied by 56 ns, divided by the ZJIT iteration time:

| Benchmark | removed by #19583/itr | upper bound | ZJIT itr | share |
| --- | ---: | ---: | ---: | ---: |
| railsbench | 39,553 (41,673 → 2,120 left) | 2.2 ms | ~1,570 ms | ≤ 0.14% |
| lobsters | 10,550 (25,616 → 15,066) | 0.59 ms | ~860 ms | ≤ 0.07% |
| shipit | 21,865 (70,004 → 48,139) | 1.22 ms | ~1,390 ms | ≤ 0.09% |
| erubi-rails | 0 | 0 | | 0 |

Only railsbench's upper bound clears 0.1%, and only narrowly. Real callees are not inlined, so the true saving is
smaller. Either way the work belongs to #19583.

### What #19583 leaves (non-constant names)

After #19583 the remaining `send` fallbacks per iteration are `send_name_not_constant_symbol` (its new counter):
railsbench 2,120, lobsters 15,066, shipit 48,139. These are the sites the census ranked first: Arel
`Visitor#visit` (`send dispatch[object.class], …`), Journey visitors, Psych, `Rails::Rack::Logger#compute_tags`
and AMS serializers. Specializing them needs a profiled Symbol guard on top of #19583's rewrite. Arel's dispatch
name changes with the node class, so a monomorphic name guard mostly misses there. The AMS `associate` readers are
monomorphic per method. The upper bound at 56 ns is lobsters 0.10%, shipit 0.19% and railsbench 0.01%. That is a
follow-up to #19583 once it lands, not a separate PR now.

## ruby-bench timing, interleaved, A/A

ZJIT, `WARMUP_ITRS=15 MIN_BENCH_ITRS=20`, builds interleaved per benchmark within each round: master, prbase,
#19583, prbase again (A/A).

Two rounds, mean ms per iteration. The base is the mean of prbase and prbase2.

| Benchmark | master | prbase | prbase2 (A/A) | #19583 | #19583 vs base |
| --- | ---: | ---: | ---: | ---: | ---: |
| railsbench | 1,594 | 1,626 | 1,583 (−2.6%) | 1,546 | −3.6% |
| lobsters | 880 | 945 | 916 (−3.1%) | 915 | −1.7% |
| shipit | 1,417 | 1,479 | 1,375 (−7.0%) | 1,356 | −5.0% |
| erubi-rails | 843 | 828 | 849 (+2.5%) | 825 | −1.6% |

Individual runs of one build vary by up to 15% (lobsters prbase 984 / 906 ms). The A/A gaps of 2.5–7% are
20–70× the computed upper bound, and erubi-rails, which has no `send` fallbacks, moves as much as the
others. These rounds show no measurable effect and cannot resolve one of ≤ 0.14%. The fallback counts and the
upper bound are the evidence; the timing is not. Logs: `~/logs/rounds1` on the orb, not kept.

## Not done

* No ZJIT branch, tests, zjit-test or btest: the stop rule fired on an existing PR, not on the bar.
* Nothing posted on GitHub. #19583 is a draft without reviews. These numbers can go in only if its author asks.
