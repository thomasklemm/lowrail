# ZJIT and `super` in methods that receive a block: ruby/ruby#19682 rethought

Stand: 2026-11-04, 10:30 UTC. PR [ruby/ruby#19682](https://github.com/ruby/ruby/pull/19682) at `0442275697`,
approved by k0kubun ("raised a couple of points to consider before moving forward, but I'd like to land a fix for the
permanent exit"), CI green, both review points answered. Nothing was posted or pushed upstream for this page.

## Kurzfassung (Deutsch)

**Das Problem.** Ruft eine Methode, die einen Block bekommen hat, `super` auf, reicht Ruby den Block automatisch an
die Elternmethode weiter. ZJIT spezialisiert `super` nur für Frames ohne Block, und die Prüfung darauf kompiliert
nie neu: Solche Stellen springen bei jedem Aufruf in den Interpreter zurück. In Rails ist das vor allem
`ControllerRuntime#cleanup_view_runtime` (railsbench 98 % dieser Exits, shipit 98 %), in lobsters außerdem
`Psych::Handlers::DocumentStream#initialize` (54 %). Pro Iteration: railsbench 2.052, lobsters 341, shipit 57; in den
21 F1-Konfigurationen erreicht der Exit 18 von 18 Apps und ist dort der viertgrößte Exit-Grund.

**Was der PR tut.** Das Profil merkt sich, ob der Frame einen Block hatte; dann nimmt die Stelle den allgemeinen
`super`-Weg, und die Prüfung kompiliert neu, falls später doch ein Block kommt. Ergebnis: 0 Exits auf allen vier
ruby-bench-Rails-Benchmarks, 0 Byte mehr Speicher (das Flag passt in vorhandenes Padding).

**Löst er das größte Problem?** Für den *dauerhaften Exit*: ja, vollständig. Für "`super` in ZJIT" insgesamt: nein.
Die Stellen werden nicht schnell, sondern nur nicht mehr pathologisch. Der Frame-Block ist nur 2,7 % (railsbench)
bzw. 3,4 % (lobsters) aller dynamischen `super`-Aufrufe. Die großen Brocken sind `super(...)` (25–40 %), `def m(*)
super` (16–22 %) und polymorphe `super`-Stellen. Grob geschätzt sind alle dynamischen `super` zusammen etwa 0,8 %
der railsbench-Instruktionen wert, der Frame-Block-Teil etwa 0,02 % (Schätzungen aus einem Mikro-Benchmark, keine
Obergrenzen). Auf ruby-bench sichtbar macht diesen Teil kein Design.

**Die Alternativen.** (F) Ohne Profil nur neu kompilieren und in der letzten Version aufgeben (k0kubuns Zeile 45 in
Shopify/ruby#1039): kürzer, aber ~20 Exits, alle Versionen der Methode verbraucht, und die letzte Version verliert
jede `super`-Spezialisierung. (A) Zur Laufzeit auf den Block prüfen und verzweigen: k0kubuns Zeile 46 tut das nur an
polymorphen Stellen und in der letzten Version; eine monomorphe Stelle mit Block verhält sich dort wie F. Unser Flag
ergänzt Zeile 46 also, statt mit ihr zu konkurrieren. (H) Nur an Stellen mit gesetztem Flag verzweigen: behebt die
Stellen, die nur manchmal einen Block haben; nicht gebaut. (B) Den Block wie YJIT direkt an die Elternmethode
durchreichen: pro Aufruf am schnellsten (537 statt 928 Instruktionen), braucht aber eine neue Art Block-Handler, die
auch das Inlining kennen muss; ruby-bench bewegt sich nicht.

**Empfehlung.** #19682 so lassen, wie er ist: klein, freigegeben, folgt dem Muster, das das Team gerade selbst
verwendet (Profil + neu kompilierender Guard, z. B. #19633 vom 3. November). Nicht erweitern. Zwei bekannte Grenzen
hier festhalten statt im PR: (1) Hat eine Methode keine Version mehr frei, bleibt der Exit; gemessen nur im
Grenzfall `--zjit-max-versions=1`, eine echte letzte Version wurde nicht nachgestellt. (2) Eine Stelle, die nur
manchmal einen Block bekommt, wird insgesamt langsamer als auf master (im Mikro +43 % bei jedem vierten Aufruf mit
Block; erst ab etwa 90–95 % Block-Aufrufen gewinnt der PR). Auf ruby-bench betrifft das nur 15 Aufrufe pro
lobsters-Iteration. Für beides gibt es kleine Folge-Ideen (Leads, keine PRs jetzt). Keine Kommentare, kein Issue
jetzt; die Zahlen unten sind bereit, falls jemand fragt. Die größeren freien Lücken (`super(...)`, `def m(*) super`)
sind Leads für später, wenn wieder PRs gehen, und berühren den Code, den Zeile 46 umbaut.

## 1. The problem from the user's side

`super` without its own block passes the method frame's block handler on (`vm_caller_setup_arg_block` for
`VM_CALL_SUPER`). ZJIT's specialized `invokesuper` (`zjit/src/hir.rs`, `emit_super_call_guards` on master
`4d2f677b60`) calls the target with `block: None` and guards `ep[VM_ENV_DATA_INDEX_SPECVAL] ==
VM_BLOCK_HANDLER_NONE` with `recompile: None`, so a method that is always called with a block side-exits on every
call for the life of the process.

**Which code hits it.** Exit sites from `--zjit-trace-exits=exit_unhandled_block_arg` on master `a8b095a07e`
(ruby-bench gems, 10 warmup + 5 measured iterations; share of all exits of this kind):

| Benchmark | Sites |
| --- | --- |
| railsbench | `ControllerRuntime#cleanup_view_runtime` 97.8 % (called by `Instrumentation#render` with a block); 0.5 % each `Jbuilder::CollectionRenderer`, `ObjectRendering`, `PartialRenderer#initialize`, `PreloadCollectionIterator#each_with_info` |
| lobsters | `Psych::Handlers::DocumentStream#initialize` (`def initialize &block; super`) 53.6 %, `cleanup_view_runtime` 34.3 %, `ActiveRecord::Core#initialize` / `ActiveModel::API#initialize` 8.6 %, `Inheritance::ClassMethods#new` 2.8 % |
| shipit | `cleanup_view_runtime` 98.1 % |
| erubi-rails | none after warmup |

On Rails main the census apps add `AssociationRoute::Cache#fetch_or_store` (`super(key.nil? ? NIL_KEY : key)` under
`fetch_or_store(key) { new }`; [zjit-iseq-leads.md](zjit-iseq-leads.md) lead 8).

**How often.** Per ruby-bench iteration, `--zjit-stats`, 10 warmup + 10 measured, `--zjit-exec-mem-size=512
--zjit-mem-size=1024`:

| | railsbench | lobsters | shipit | erubi-rails |
| --- | ---: | ---: | ---: | ---: |
| `exit_unhandled_block_arg`, master `a8b095a07e` | 2,052 | 341 | 57 | 0 |
| same, with #19682 | 0 | 0 | 0 | 0 |
| its share of all side exits on master | 8.7 % | 2.7 % | 0.1 % | 0 % |
| all side exits, master → #19682 | 23,709 → 21,687 | 12,648 → 12,308 | 49,566 → 49,509 | 10,000 → 10,000 |
| dynamic `super` calls (all kinds), master → #19682 | 75,235 → 77,287 | 10,296 → 10,652 | 23,367 → 23,424 | 50,000 → 50,000 |

On Rails main: the 10 census-3 apps average 21 exits per request (campfire 67, writebook 63, fizzy 31;
Shopify/ruby#1100). F1's 21 configurations (18 apps; [frontier-census-f1.md](frontier-census-f1.md)) reach it in all
18 apps, 1,429 per operation summed over the configurations (mean 68, thinkroom 381), the fourth-largest exit reason
there after `patchpoint_no_singleton_class` (39,371), `guard_type_failure` (4,832) and
`patchpoint_stable_constant_names` (4,275). The F1 apps were not rerun with #19682.

**What it costs.** Callgrind on a micro (`D#f(k) = super(k)` over `C#f`, loop-inclusive Ir per call, A/A identical to
the instruction):

| Build | never a block | always a block | block on every 4th call |
| --- | ---: | ---: | ---: |
| master `a8b095a07e` | 426 | 963 (1 exit per call) | 684 (2,992 exits per 12,000 calls) |
| #19682 (binary `533e79d815`, differs from `0442275697` only in a test) | 426 | 928 (dynamic `super`) | **979** (every call dynamic) |
| B, pass the frame's block (prototype `thomasklemm/zjit-super-block-pass`) | 426 | 537 | 588 |

In the micro the exit itself costs tens to a few hundred instructions; in an app the interpreter also runs the rest
of the method after the exit. Rough estimates for railsbench (4,938 M Ir per iteration), scaled from the micro's
trivial methods and so not upper bounds: the 2,052 frame-block calls ≈ 0.9 M Ir (2,052 × 426, master minus B)
≈ 0.02 %; every dynamic `super` together ≈ 39 M Ir (77,287 × ~500, the micro's dynamic minus specialized cost)
≈ 0.8 %; `super(...)`, splat and keyword sites likely cost more per call than the micro. Callgrind on ruby-bench (10 warmup + 5 measured, two runs each, GC not excluded) shows nothing beyond run-to-run
spread, which is too wide to see effects of this size: the PR (an earlier variant) −0.04/+0.01 % railsbench, −0.01/−0.06 % lobsters, −1.26/+0.08 % shipit; B
+0.07/−0.07 %, +0.05/−0.11 %, +0.07/−0.21 %; master's second run +0.01/+0.01/+0.03 %.

**Is the PR the biggest part?** For the permanent exit, yes: it removes all of it on all four benchmarks. For
`super` as a whole, no. Sampled `super` fallbacks with #19682 (`--zjit-trace-fallbacks-sample-rate=199`, every 200th
fallback, classified by the call-site flags of the sampled method's `super`; warmup included):

| Kind | railsbench | lobsters | shipit | erubi-rails |
| --- | ---: | ---: | ---: | ---: |
| `super(...)` / zsuper in `def m(...)` (`invokesuperforward`, never specialized) | 25 % | 27 % | 29 % | 40 % |
| splat zsuper, `def m(*) = super` (complex args) | 22 % | 18 % | 18 % | 20 % |
| `super(*args, &block)` (`SafeInitialization#new`, `_layout_for`) | 13 % | 4 % | 1 % | – |
| `**kw` / `kw:` (complex args) | 8 % | 8 % | 11 % | – |
| polymorphic `super` (Shopify/ruby#1039 row 46) | 5 % | 22 % | 18 % | – |
| `super` from inside a block (Shopify/ruby#993) | 8 % | 14 % | 13 % | – |
| literal `super { }` (`InheritableOptions#initialize`) | 5 % | 3 % | 8 % | 40 % |
| frame's block, this PR's sites (now dynamic instead of exiting) | 3 % | 3 % | 0.4 % | – |
| other (attrset/ivar target, unresolved) | 11 % | 1 % | 3 % | – |

F1, per operation summed over 21 configurations, master: `super_polymorphic` 1,726, `super_complex_args_pass` 1,454,
`exit_unhandled_block_arg` 1,429, `super_from_block` 1,073, `invokesuperforward` 1,030, `guard_super_method_entry`
exits 495, `super_call_with_block` 123.

## 2. The design space

What each option does with a `super` whose frame has a block. "Review load" is my estimate of what the ZJIT team
would have to check.

| Option | Exits | Profile memory | Code and review load | Where it is |
| --- | --- | --- | --- | --- |
| **#19682**: profile whether the frame had a block (skip `super(&b)` and `super { }`); if so, dynamic `super`; the block guard recompiles | 0 when profiling saw the block; otherwise 5 (`--zjit-num-exits-until-invalidate`) and one recompile | 0 B: a `bool` in `ProfileEntry` padding (`zjit_alloc_bytes` today: railsbench 7,853,517 → 7,826,157, lobsters 20,986,070 → 20,977,851, shipit +6 KB, all within run-to-run drift) | 7 added lines in `hir.rs`, 13 in `profile.rs`, rest tests and snapshot `recompile` markers. Same idiom as master's monomorphic `invokeblock` (guard with `Recompile`) and #19633 (profiled nil in `expandarray`, merged 2026-11-03) | approved |
| **F**: recompile on the guard, no profile; in the ISEQ's final version (`policy.no_side_exits`) dispatch every `super` dynamically | ≈ 15–20 per ISEQ (k0kubun's commit message: 999,999 → 20), then 0 | 0 | ≈ 10 lines. Burns all `--zjit-max-versions` (4) of the method, and the final version gives up every specialized `super` in it, not just this one | k0kubun's `zjit-lobsters7`, `7b373cdb14` (#1039 row 45, +0.04 %), bundled with `UnwrapSvar` for the method-entry guard |
| **A** as on k0kubun's branch (`6f1119a5f1`, #1039 row 46, +0.30 %): a monomorphic site in a version that may still recompile keeps the recompiling block guard (`s.is_monomorphic() && !self.policy.no_side_exits` → `SuperGuards::Full`); polymorphic sites and final versions get a chain that tests the block handler once at run time (`IsBitEqual`/`CondBranch`) and sends a frame with a block to a dynamic `super` | monomorphic always-block site: like F (~20, then a final version that branches); polymorphic and final-version sites: 0 | 0 | 718 lines in `hir.rs`, mostly the polymorphic method-entry chain; needs a branch and a join at the `super` site in `type_specialize`, which master's `super` specialization doesn't have (master builds such diamonds for `invokeblock` and ivars while building HIR). The run-time block test sits in the chain only, so it does not cost every monomorphic site an extra arm | k0kubun's branch, unassigned row |
| **G**: #19682 plus F's final-version fallback (dispatch `super` dynamically when `policy.no_side_exits`) | closes the final-version case at F's cost, but only in that rare last version | 0 | ≈ 5 lines from `7b373cdb14`; matches master's `invokeblock`, which branches instead of guarding in a final version (`hir.rs:3392`). The final version then gives up every specialized `super` in the ISEQ | not built |
| **H**: #19682, but where the flag is set, test the block handler at run time: no block → specialized arm, block → dynamic arm | 0 | 0 | Fixes mixed sites (estimated ≈ 550 Ir per call at 1 in 4, not measured). Same branch-and-join machinery as A's chain, at flagged sites only | not built |
| **B**: pass the frame's block handler to the specialized callee, as YJIT does (`BlockHandler::FindFromCurrentFrame` in `gen_invokesuper_specialized`) | 0 | 0 with the #19682 bit | New `BlockHandler::FrameBlock` through HIR printer, operand visitors, codegen and the inliner (the prototype refuses to inline such calls); cfunc targets stay dynamic. 537 vs 928 Ir per call, ruby-bench flat | our prototype `7b18d100e9`, unpublished |
| **B0**: always pass the frame's block, no profile, no guard (exact YJIT parity) | 0 | 0 | Simplest at run time, but every `super` site, including the no-block majority, loses callee inlining and `block_given?` folding (the inliner can't take a run-time block) | not built |

**What the team would most likely prefer.** k0kubun approved #19682 after its two review points (memory, `super(&b)`),
both addressed with measurements. The team's own recent work uses the same shape: profile, specialize, guard with
`Recompile` (`invokeblock`, `getivar`/`setivar`, `expandarray`), and for `invokeblock` and ivars a branch instead of a
guard in a final version.
Max Bernstein's #19000 cut profile memory in September, and k0kubun's first review point was memory, so a 0-byte flag matters. A, G, H and B
are improvements the PR leaves open. A is on k0kubun's own branch inside a larger change, and it keeps a recompiling
guard at monomorphic sites, so it does not make #19682's flag redundant: an always-block monomorphic site still needs
the flag to avoid ~20 exits and a spent version budget. G and H are small and sit on top of #19682; B has no
benchmark effect, which is the bar for new JIT performance PRs.

**Two limits of #19682.**

* **No version left.** A block that first appears after the ISEQ's last version was compiled exits on every call
  again, because `exit_recompile` returns early at `--zjit-max-versions`. The repro (compiled without a block, then
  10,000 calls with one) gives 5 exits with the default 4 versions and 10,000 with `--zjit-max-versions=1` (master:
  10,000 either way). That run is the degenerate case: with one version, `CompilePolicy::new` never sets
  `no_side_exits` (it needs an earlier invalidated version), so F, A and G would not help there either. A real final
  version (reached after invalidations), where G or A would close the hole, was not constructed. For an inlined
  `super` the budget that counts is the outer ISEQ's (`exit_recompile` invalidates `jit.iseq()`); the reviewer's
  inlined variant behaved the same (5 / 10,000). None of the four benchmarks hit it (0 exits with #19682). Master's
  method-entry guard never recompiles at all.
* **Sites that sometimes get a block.** The flag is sticky, so a site that saw a block in any profiled call goes
  fully dynamic: 979 Ir per call instead of master's 684 in the 1-in-4 micro (+43 %). Interpolating master's 684
  (1 in 4) and 963 (always), the PR only wins in this micro when roughly 90–95 % or more of a site's calls carry a block; in a real method the exit
  also hands the rest of the method to the interpreter, which moves that point down. Clearing the
  flag on re-profiling would not help: a 1-in-4 site sets it again in every profiling window. H fixes it. On
  ruby-bench this moved 15 extra calls per lobsters iteration (`super_call_with_block` +356 vs 341 former exits) and
  none on railsbench, shipit or erubi-rails.

## 3. Related upstream work

* **k0kubun's `zjit-lobsters7` branch** (Shopify/ruby#1039, updated 2026-11-03): rows 45 (`7b373cdb14`) and 46
  (`6f1119a5f1`) touch this guard (F, then A). Both rows are unassigned and not upstreamed; k0kubun said on
  Shopify/ruby#1100 that the issue was free to take and then approved #19682. Row 46 moves the guards into
  `emit_specialized_super`/`emit_super_chain`, so whoever lands second has a textual conflict in
  `emit_super_call_guards`; semantically the two fit together (the flag for monomorphic sites, the chain for
  polymorphic sites and final versions).
* **Shopify/ruby#993** (XrXr, open): `super` from inside a block (`SuperFromBlock`), 8–14 % of dynamic `super` above.
* **ruby/ruby#18326** (nozomemein, open): specializes `sendforward`; `invokesuperforward` (the largest `super`
  bucket) is the analogous, unowned gap. Shopify/ruby#862 only added dynamic dispatch for it.
* **ruby/ruby#19617** (k0kubun, open): extra versions after PatchPoint invalidation of a final version
  (`--zjit-patch-versions`). It does not touch `super`, but more versions make #19682's final-version limit rarer.
* No open ruby/ruby PR or Shopify/ruby issue besides these touches `invokesuper` block handling (searched
  2026-11-04: "ZJIT super", "invokesuper", "splat super").

## 4. Recommendation

1. **Keep #19682 as it is.** It is the smallest change that ends the permanent exit, costs no memory, follows the
   team's current guard idiom, and is approved. Simplifying it to F would trade one exit-and-recompile for ~20 exits
   and the method's whole version budget; extending it to A, G, H or B would add review load to an approved PR for no
   ruby-bench effect.
2. **Don't touch the PR or post anything.** The two limits above are recorded here. If a reviewer asks: mixed sites →
   H (branch at flagged sites); a real final version → G (dynamic `super` when `no_side_exits`), or the chain from
   row 46 for the polymorphic case.
3. **Leads, not PRs or issues, while ruby/ruby PRs are capped.** Free and larger than this PR's shape: specializing
   `invokesuperforward` (25–40 % of dynamic `super`; pairs with #18326) and splat zsuper `def m(*) = super`
   (16–22 %; master's caller-splat dispatch exists for `Send`). Both edit the `super` specialization that row 46
   rewrites, and every dynamic `super` together is roughly 0.8 % of railsbench Ir (estimate), so they need a
   ruby-bench measurement before anyone builds them. G and H are small follow-ups to #19682 itself, worth building
   only if a real app shows mixed sites or exhausted versions at `super`. B stays a parked prototype.
4. **How to help beyond the PR.** Nothing upstream now. Per [DECISIONS](../DECISIONS.md), benchmarks of others'
   branches and breadth data for #1039 stay in our docs, and new issues need Thomas's OK; the `super` kind breakdown
   above is not a verified bug. The useful thing to keep ready is this page's measurement setup, so that if row 46
   or a `super(...)` PR appears, we can measure it on the F1 apps and ruby-bench within a day.

## 5. Reviewer challenge

A separate reviewer (a fresh agent with the evidence above, asked to argue against the recommendation) checked the
PR code paths and the numbers. Verdict: agree with changes. What it found and what changed here:

* **A was described wrong.** I had written that row 46 tests the block handler at every specialized site and so
  closes both limits. It doesn't: `6f1119a5f1` keeps the recompiling guard at monomorphic sites
  (`hir.rs` line 8036 on that commit) and branches only in polymorphic chains and final versions. Fixed in the table;
  the consequence is that #19682's flag complements row 46 instead of being superseded by it.
* **The final-version repro is degenerate.** `--zjit-max-versions=1` never sets `no_side_exits`, so it shows the
  "no version left" hole but not a case F, A or G would fix. Now stated; a real final version was not constructed.
* **Two options were missing:** G (#19682 + dynamic `super` in a final version, ≈ 5 lines) and H (branch on the
  block handler only at flagged sites, fixes mixed sites). Added as leads, not as changes to the approved PR.
* **The mixed-site cost was understated** (the PR loses unless ~90–95 % of a site's calls carry a block, in the
  micro). Added. Clearing the sticky flag would not help.
* **"Upper bounds" were estimates** scaled from a trivial micro. Reworded.
* **No correctness problem in the PR.** Checked: inlined `super` reads the callee's own profile and converges after 5
  exits; the profiler reads the block handler from the method's local frame (`VM_CF_BLOCK_HANDLER`), the same one
  `super` forwards; `define_method` bodies stop at `SuperFromBlock` before the flag matters; `super(&b)` and
  `super { }` detection is right. Not checked: an inlined site whose outer ISEQ is in a real final version.

The recommendation stands after these changes: keep #19682, post nothing, keep G, H, B and the larger `super` gaps as
leads.

## 6. Method

* Builds: master `a8b095a07e` (the PR's base) and the PR as binary `533e79d815` (its only difference from
  `0442275697` is one assertion in a test); B is the `thomasklemm/zjit-super-block-pass` prototype (`7b18d100e9`,
  binary built from that working tree, confirmed by `send_fallback_super_call_with_block` = 0 on the block micro).
* ruby-bench `73918b2` gems (Rails 8.1.1/8.1.2, erubi-rails Rails 8.0.3). Stats harness: 10 warmup iterations,
  `RubyVM::ZJIT.reset_stats!`, 10 measured, all of `RubyVM::ZJIT.stats` dumped. `--zjit --zjit-stats-quiet
  --zjit-exec-mem-size=512 --zjit-mem-size=1024`; 0 `compile_error_out_of_memory`.
* Sites: `--zjit-trace-exits=exit_unhandled_block_arg` (master) and `--zjit-trace-fallbacks-sample-rate=199` (PR),
  Perfetto FXT parsed for the top frame; flags from `RubyVM::InstructionSequence#to_a` of every loaded method's
  `invokesuper`/`invokesuperforward`, joined on method label and path.
* Micro: `class C; def f(k) = block_given? ? yield(k) : k; end; class D < C; def f(k) = super(k); end`, loop of
  10,000 vs 110,000 calls after 2,000 warmup calls, `valgrind --tool=callgrind`, difference / 100,000.
* Upstream code read on master `4d2f677b60` (`zjit/src/hir.rs` `InvokeSuper` in `type_specialize`,
  `dispatch_invoke_block_iseqs`, `CompilePolicy`; `zjit/src/codegen.rs` `exit_recompile`, `invalidate_iseq_version`),
  YJIT `gen_invokesuper_specialized`, and k0kubun's `zjit-lobsters7` (`7b373cdb14`, `6f1119a5f1`).
