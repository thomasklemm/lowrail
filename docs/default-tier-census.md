# Bet D: no useful guard-free default tier demonstrated

**Decision, 2026-10-22: stop before implementation.** The four-route census
does not identify an exact, guard-free transformation reaching 2–3% of objects
or interpreter instructions on two apps. Keep default selection, quarantine
and runtime unchanged. This rejects the investigated candidates, **not every
possible future local compiler optimization**.

The [machine census](default-tier-census.json) retains all 3,586 allocation
sites and 6,015 sampled method entries, source/lock/tool hashes, counterexample
programs, compiler disassemblies and raw heap/window controls. A site is
`path:line:class` for allocations and `path:first_line:method` for instructions.
`APP/`, `GEM/`, `RUBY/` and `LOWRAIL/` normalize installation roots only.
Every allocation site has a disposition and **gross pool ceiling**, not a
claim that the pool is removable. Every method retains self/inclusive shares
and estimated self Ir. Zero credited saving means **no exact rewrite
established**; an unresolved site is not proof of zero opportunity.

## Request totals and the local-template ceiling

All runs use Ruby **4.0.7**, revision `229531a6cf`, Rails **8.1.4**, production,
**interpreter**, `LOWRAIL=0`, with no Lowrail build, loader or setup. Ir counts
executed machine instructions, including native callees, not Ruby bytecodes
or elapsed time. The two Ir columns are finite within-process replicates.

| App / GET | Objects/request, median | Untraced Ir/request, replicate 1 / 2 | All template-source objects | Template-source Strings | Template self Ir |
|---|---:|---:|---:|---:|---:|
| Retained blog `/articles/1` | 2,387.42 | 8,991,978 / 8,994,736 | 54 (2.262%) | 28 (1.173%) | 0.365% |
| Fizzy `/buckets`, authenticated | 4,104.90 | 17,944,859 / 17,950,457 | 86 (2.095%) | 36 (0.877%) | 0.293% |
| Lobsters `/`, anonymous | 13,975.17 | 67,558,979 / 67,554,469 | 466 (3.334%) | 373 (2.669%) | 0.959% |
| Campfire `/session/new` | 5,899.72 | 23,219,230 / 23,218,189 | 80 (1.356%) | 42 (0.712%) | 0.233% |

These are **gross discovery bounds**, not achieved savings. In particular,
all-template objects include option Hashes and block/local storage that pass
through live calls; deleting those is not by-construction exact. Strings
passed to helpers are fresh arguments, not disposable output fragments.
Template self Ir excludes descendant helpers, but includes their callsites'
dispatch overhead; moving work across those calls is a different proposition.
Method shares are sampled estimates, not exact instruction counts per line.

The String pool is below 1.2% on three apps even if every such String could be
removed. Only Lobsters exceeds 2%, and its helper arguments/output still have
to remain observable. Whole-template self work is below 1% everywhere. These
are not upper bounds on all Rails work: the larger pools below exist, but
need assumptions outside the local expression to specialize them.

## Large sites, and why their gross ceilings are not guard-free savings

Allocation counts below are objects/request from one GC-disabled 20-request
trace. File basenames refer to the exact versions in the machine census.
Rows overlap the method-level instruction pools; do not add them to those
shares or to the template totals.

| Allocation site / class | Blog | Fizzy | Lobsters | Campfire | Guard-free disposition |
|---|---:|---:|---:|---:|---|
| `tag_helper.rb:309`, String | 95 | 240 | 370 | 381 | Final `tag_option` interpolation escapes to a live caller; bypassing the helper or changing append arguments changes dispatch/identity. |
| `erb/util.rb:143`, String | 55 | 121 | 229 | 263 | `name.to_s` stays live even for Symbol literals; `blank?`, regexp policy and escaping also stay live. |
| `output_safety.rb:242`, SafeBuffer | 54 | 125 | 148 | 238 | `html_safe` calls the live SafeBuffer constructor; object identity, safety and construction remain observable. |
| `output_safety.rb:71`, String | 52 | 119 | 144 | 227 | Native String storage initialized through `super`; replacing it assumes constructor/safety behavior. |
| `tag_helper.rb:237`, String | 36 | 97 | 114 | 170 | Fresh options output; its live `<<` calls and returned String cannot be replaced by different sends. |
| `journey/visitors.rb:40`, Array | 12 | 21 | 220 | 10 | Live route part evaluation/conversion; iteration fusion needs callee/collection contracts. |
| `<internal:marshal>:34`, String + Array | 0 | 0 | 1,041 | 0 | Real decode/copy work, not unused local syntax. No exact local elimination identified. |
| `story.rb:848,849,867`, String | — | — | 648 | — | Live title normalization substitutions and fresh return value; literal planning needs method/encoding/inflection assumptions. |

The JSON retains lower-ranked model/type/time/cache/middleware/app pools as
well, including the unattributed residual rather than reallocating it to a
favored candidate. Path-based dispositions organize the census; they are not
individual semantic proofs for every cold frame.

| Sampled method self Ir, gross share | Blog | Fizzy | Lobsters | Campfire | Guard-free disposition |
|---|---:|---:|---:|---:|---|
| `TagBuilder#tag_options` | 3.976% | 4.924% | 1.542% | 7.213% | Live options iteration, blank checks, mutable tag tables and helper calls. |
| `TagBuilder#tag_option` | 2.845% | 4.082% | 1.759% | 5.359% | Live key/value conversion, type selection, escaping and returned fragment. |
| `ERB::Util.xml_name_escape` | 1.258% | 2.316% | 0.950% | 2.813% | Cannot preescape names while retaining the original conversions and their effects. |
| `String#blank?` | 2.973% | 4.640% | 1.572% | 5.436% | Live encoding/regexp policy and methods; not literal dead code. |
| `Rack::ETag#digest_body` | 4.669% | 6.498% | 5.866% | 7.756% | Actual response digest and fresh output, not a literal expression. |
| `Marshal.load` | — | — | 8.564% | — | Decode work remains live. |
| `Inflector#apply_inflections` | — | — | 5.601% | — | Mutable rules and live conversion/regexp sends. |
| `Story#title_as_url` | — | — | 2.376% | — | Source-local, but its substitutions are sends over live titles. |

No removal is credited for any of these sites. A sealed specialization may
have a useful budget here; that does not make it a guard-free default pass.

## Candidate audit and executed counterexamples

1. **Static ERB text.** The observed original compiled templates already use
   `opt_str_freeze`: 36 / 57 / 204 / 57 static instruction occurrences in
   blog/Fizzy/Lobsters/Campfire. These are static counts, not hit frequencies.
   There is no fresh-String allocation to remove at those literal loads.
2. **Coalesce adjacent output operations.** Generated ERB calls
   `safe_append=` / `append=` on the current output buffer. Joining two text
   arguments removes an observable call, changes arguments and can skip a
   buffer replacement between expressions. The executable minimal buffer
   counterexample records `["left", "right"]` versus `["leftright"]`.
   No buffer-holder certificate is available in a guard-free tier.
3. **Freeze or share helper literal arguments/options.** The original mutable
   literal accepts `<<`, while the frozen replacement raises `FrozenError`.
   Two fresh option Hashes give mutation results `[1,1]`; sharing gives
   `[1,2]`. Keeping the outer helper send is insufficient: its arguments are
   observable. Preescaping a Symbol also fails after `Symbol#to_s` changes.
4. **Fold literal arithmetic.** `1 + 2` is `opt_plus`, not a constant load.
   Redefining `Integer#+` makes the original return 99 while folded `3`
   remains 3. Retaining CRuby's BOP handling means retaining the operation.
5. **Dead literal syntax / splat intermediates.** Ruby already removes the
   tested literal branch, dead array statement and unused-result parallel
   assignment array, while retaining the evaluated sends. A Prism scan of
   app Ruby plus actionview/actionpack/activerecord/activemodel/activesupport
   finds **zero** call-argument `**{...}` or `*[...]` candidates, with zero
   parse errors, across 1,048 / 1,159 / 1,107 / 1,159 files respectively.
   Two literal-positive and two dynamic-negative scanner controls pass.
   This scan covers those syntax classes, not every possible expression.

All five standalone semantic probes run in fresh unmodified Ruby processes;
their sources and expected divergent outputs are in the census. No candidate
proceeds to runtime installation, so there is no new ancestry-safe delivery
mechanism. Bet G owns that shared investigation; D has not built a competitor.

## Measurement scope and controls

- Allocations: observe original template ISeqs during ten requests, then warm
  400; three 100-request GC-enabled totals; separately trace 20 requests with
  GC disabled and enumerate newly allocated, source-attributed objects.
  The median is not an off-A/off-B/on optimization screen.
- The allocation trace has explicit unenumerated/unattributed residuals:
  **222.35 / 347.35 / 1,213.35 / 393.35 objects/request**. ObjectSpace source
  enumeration does not cover every GC-counted internal object. This is a
  limitation, not an assumed removable pool or a global small-ceiling proof.
- Instructions: warm 50, then fixed five-pool heap floors
  **1,000,000 / 250,000 / 100,000 / 20,000 / 10,000**. Two N=0/20 windows
  per worker, with separate untraced and instruction-triggered-stack workers.
  Both modes retain GC; no measured window collects. Every before/after
  eden-page count stays **611 / 306 / 246 / 99 / 100**, with no page additions.
- Valgrind **3.19.0** plus the existing Lowrail sampling/brk patch; source
  archive SHA256 `dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`.
  The sampler charges C work to the nearest Ruby frame. Self shares partition
  samples; inclusive shares overlap. Sample totals are **5,483 / 10,926 /
  41,170 / 14,182**; empty/truncated/dropped/lost and GC samples are all zero;
  no brk overflow. Corrected sampled-worker Ir differs from untraced Ir by at
  most **0.04835%** across the eight replicate comparisons.
- Use dump `totals:`, not `summary:`. The Lobsters empty window's summary
  wraps an unsigned counter; its actual self-cost total is retained. No
  rejected performance cohort was rerun to obtain a green control.
- This is a **diagnostic census**, not the six-round `lowrail bench` A/A
  pricing protocol. No request speedup, latency win, two-seed exact-response
  claim, new holder/ancestry equivalence claim or optimized own-suite parity
  is made. Those implementation gates and off-A/off-B/on allocations were
  deliberately not run because no runtime change passed the census gate.

## Fixture pins and reproduction

Base: [f257ddd](https://github.com/thomasklemm/lowrail/commit/f257ddd1d35284b1da4daad201852ab8cc2ee32e).
Prior studies: bet R
[758d8c9](https://github.com/thomasklemm/lowrail/commit/758d8c95ed8ab9dafcf07c5dc9d749febeb4bb70)
and bet L
[59211ca](https://github.com/thomasklemm/lowrail/commit/59211cadf4e6d8ead1c7fa4462e947ccf5765e56).
R profiled a Lobsters story, not this front page; L's older front-page total
includes observer allocations absent here. Their figures are not substituted
for this fresh four-app census. The Lobsters dependency wrapper/lock are
reused byte-for-byte from R, not newly invented dependency patches.

Use disposable databases and source trees. `script/corpus real-blog-r4`,
`script/corpus fizzy` and `script/corpus campfire-r81` prepare the existing
dependency-only fixtures. Blog is the retained archive verified by that
script, with its ordinary production db:prepare seeds (three articles and
three comments). Fizzy is
[6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9);
prepare production DB/assets and use the existing external
`bench/experiments/vm_epoch_fizzy_setup.rb` with `SKIP_TELEMETRY=1` to create
one user/account/bucket/session. Store its generated cookie JSON privately
outside the app and pass only its file path as `CENSUS_HEADERS`.

Campfire is
[02023b0](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa).
An initial empty-database `/session/new` attempt returned **302** and aborted;
that log is retained, not counted. Creating one ordinary Account and User in
the disposable DB makes the login route return 200; no app code/config patch
or Redis service is required for that route. The Account is `Default census`,
the User is `Census <census@example.invalid>`. This route is not a room workload.

Lobsters is the existing ruby/ruby-bench
[351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716)
snapshot at `.corpus/ruby-bench/benchmarks/lobsters`. Use the external
`fixtures/corpus/lobsters.Gemfile` / lock and its shipped SQLite DB; the worker
restores that DB to `:memory:` exactly as upstream benchmark.rb does.
DB SHA256: `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
**No agent source, fixtures, generated code or `.lowrail` output is written
into Lobsters.** Only ordinary app runtime outputs are allowed there; its
Git worktree remains clean. No proposal is made to the Lobsters project.

Run commands from the chosen app's working directory. `ROOT` is this Lowrail
checkout, `OUT` a fresh directory outside the app, `APP` one of the four worker
names. Unset inherited `RUBYOPT`, Lowrail preload and JIT-enable variables.
Set `BUNDLE_GEMFILE` only for the Lobsters external wrapper; use each other
app's unchanged effective bundle. Private session values never enter results.

```sh
export LOWRAIL=0 RAILS_ENV=production RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1
# Fizzy only: SKIP_TELEMETRY=1 CENSUS_HEADERS=/private/path/to/headers.json
mise exec ruby@4.0.7 -- ruby --disable-yjit \
  "$ROOT/bench/experiments/default_tier_census.rb" "$APP" allocations "$OUT/$APP-allocations.json"

# Build Valgrind 3.19.0 with bench/experiments/hotspots-valgrind.patch.
# Install with prefix VG="$OUT/vg"; the reporter hashes that counted binary.
# Build the existing extensions against its headers; no Ruby patches:
mise exec ruby@4.0.7 -- ruby -rrbconfig -e '
  c = RbConfig::CONFIG
  system(c.fetch("CC"), "-shared", "-fPIC", "-O2", "-I#{c.fetch("rubyhdrdir")}",
    "-I#{c.fetch("rubyarchhdrdir")}", "-I#{ARGV[0]}/include", ARGV[1], "-o", ARGV[2], exception: true)
' "$VG" "$ROOT/bench/callgrind.c" "$OUT/lowrail_callgrind.so"
# Repeat compiler command with hotspots_detail.c and lowrail_hotspots_detail.so.
export BENCH_CALLGRIND_EXTENSION="$OUT/lowrail_callgrind.so"
export HOTSPOT_EXTENSION="$OUT/lowrail_hotspots_detail.so"
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for MODE in instructions profile; do
  mise exec ruby@4.0.7 -- "$VG/bin/valgrind" --tool=callgrind \
    --instr-atstart=no --smc-check=all-non-file \
    --callgrind-out-file="$OUT/$APP-$MODE.cg" --log-file="$OUT/$APP-$MODE.vg" \
    ruby --disable-yjit "$ROOT/bench/experiments/default_tier_census.rb" \
    "$APP" "$MODE" "$OUT/$APP-$MODE.json"
done
# After all four apps; from the Lowrail root, outside any app bundle:
mise exec ruby@4.0.7 -- ruby bench/experiments/default_tier_report.rb "$OUT" NEW_REPORT.json
```

The reporter checks lock/harness consistency, allocation/sample partitions,
and expected counterexamples. The committed JSON includes exact effective
lock hashes, an aggregate digest over sorted app/config/db/test/lib source
hashes, and measured worker/tool hashes. Raw JSON, Callgrind dumps and logs
are retained privately under `.lowrail/private/default-tier/`; authentication
material is excluded. No app own-suite result is updated or relabeled by D.
