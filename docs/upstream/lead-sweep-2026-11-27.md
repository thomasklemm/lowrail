# Lead sweep (2026-11-27)

Every lead and parked idea in `docs/upstream/*.md`, `bench/upstream/**/README.md` and the held queue items
(`script/pr-queue status`), with its revisit condition, checked against GitHub and current code today. Leads that
other threads own today (connection lookup, query-cache key and env_config; UR1 and NK2; ZJIT-vs-YJIT gaps; the Solid
stack, memory and test suites) are listed and marked, not touched.

Setup: Rails main [`2e299253f9`](https://github.com/rails/rails/commit/2e299253f9) (2026-11-27), Ruby 4.0.10 (interpreter,
YJIT) and Ruby master [`0d399335b7`](https://github.com/ruby/ruby/commit/0d399335b7) built with ZJIT. 176 upstream
issues and PRs named in the records were read from GitHub today; their state is in the Check column. Probes, repros
and raw output: [`bench/upstream/lead-sweep-2026-11-27`](../../bench/upstream/lead-sweep-2026-11-27/). Timing numbers
below are micro-benchmarks for park-or-build decisions, each mode run twice as an A/A on this a1.large orb; none goes
into a body. Allocation counts are not time.

## Result

**Nothing was built for upstream, opened, posted or pushed to a fork.** No lead whose condition is met clears the
DECISIONS bars on current main and master; the ones closest are TO1 (explained loss, parked), the `Accept` parse
(needs a request share first) and two Ruby correctness repros that need Thomas.

**Conditions that changed and were re-measured:**

* **TO1 under ZJIT** (held for an unexplained ZJIT `f.text_field` +0.64% on master `f3e180b5eb`): the loss is still
  there on master `0d399335b7` (+0.6%, and +0.2% interpreted) and is now explained: the tag String outgrows its buffer
  on long attribute lists and reallocates (malloc/realloc +560 Ir per call). Not a JIT effect. TO1 stays held as a
  parked idea ([TO1 below](#to1-under-zjit)).
* **`Mime::Type.parse` now runs on every browser request of a new app.** Rails main's 8.2 defaults set
  `action_dispatch.strict_accept_header = true` (`railties/lib/rails/application/configuration.rb:378`), so a browser's
  `Accept` header is parsed instead of skipped. Per parse ([`accept_probe.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/accept_probe.txt)):
  Firefox 9.5 µs and 38 objects under YJIT (12 µs interpreted, 8.7 µs ZJIT), Chrome 21 µs and 81 objects (26 µs, 19.6 µs).
  A per-header cache was rails/rails#59455 (linyiru), closed 2026-10-30 after fatkodima: "will not have any difference
  on a real world app". Parked, upgraded: next step is a request-level share on an app with 8.2 defaults; a cache
  isn't rebuilt against a four-week-old maintainer decision.
* **GC fallback:** ruby/ruby#20110 (merged 11-24) removed most of the `nofree` majors. `bigslot.rb`: 4.0.10 2 majors,
  master `0d399335b7` 6–7, where master `9aa0898240` had 33 ([`bigslot-2026-11-27.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/bigslot-2026-11-27.txt)).
  ruby/ruby#17251 was pushed 11-26, so it hasn't stalled: GC stays held.
* **ZL3:** the lead 3 repro still takes 0.5 `send_polymorphic_fallback` per call on master `0d399335b7`; Shopify/ruby#776
  has no team answer since 11-14. New context: our OTS1 (ruby/ruby#19982, merged 11-24) is a recompile on a failed
  guard that the ZJIT team accepted. Held; for Thomas.
* **Rails leads unblocked by merges** (#59141, #59530, #59569, #59709, #59823, A1), all below the bar on main
  `2e299253f9`:
  * census-9 lead 8, an early return in `table_name_qualified_unscope_values`: −1 object per association load or merge
    (149 → 148, 218 → 215 with a scoped association), about 13 calls per request ([`unscope_probe.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/unscope_probe.txt), [`lead8.diff`](../../bench/upstream/lead-sweep-2026-11-27/lead8.diff));
  * census-10 A2, the second `AliasTracker` per through load: 2.3 µs / 0.7 µs / 0.8 µs (interp / YJIT / ZJIT) and 2
    objects, 0.6–0.8% of `author.comments.to_a` ([`a2_probe.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/a2_probe.txt));
  * per-row `attributes_builder`: 11 reads per 10-row load at 124–138 / 42–44 / 41–43 ns, 1.2–1.4% of the load in
    every mode; #59530 removed the slow path that the schema-context leads (a) and (b) were about
    ([`builder_probe.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/builder_probe.txt)).
* **IWC (`index_with` on Ruby 4.1):** a 12-key micro on master `0d399335b7` has plain `each` at 1 object and
  1,305–1,341 ns against `to_h` at 13 objects and 1,274–1,361 ns ([`index_with_micro.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/index_with_micro.txt)).
  Its condition asks for the 4.1 release candidate (only preview1 exists), so it stays parked with this as a first sign that
  a branch-free `each` may work on 4.1.

**Superseded or done upstream:** R1 (#59141 rewrote `map`/`deep_dup` as eager copies), the schema-context leads
(#59530), ZRS1 (merged), JB1 (#59953 merged today), the Ir-in-results-JSON idea (tekknolagi's ruby/ruby-bench#581),
the graphql-native Windows exclude (gone from ruby-bench's workflow), the prism zsuper `**kwrest` object (Bug #22527),
cbor-ruby#42 (cbor 0.6.2.2 released).

**Correctness, for Thomas (new issues):** both reproduce on 4.0.10 and master `0d399335b7`
([`repros.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/repros.txt)); no existing report found.

* `X = { **H, a: 1 }` under `# shareable_constant_value: experimental_everything` raises `NoMethodError` for
  `core#hash_merge_ptr` (master: `core#hash_merge_bang_ptr`), in every mode ([`shareable_kwsplat.rb`](../../bench/upstream/lead-sweep-2026-11-27/repros/shareable_kwsplat.rb)).
* An unused refinement of `Kernel#==` makes `A.new != 1` raise `NoMethodError` in the interpreter, while ZJIT returns
  `true` ([`kernel_eq_refinement.rb`](../../bench/upstream/zne1/leads/kernel_eq_refinement.rb)).

**Condition met, handed on:**

* hashie/hashie#659 merged today (19:28 UTC): the second Duel job under ZJIT ([calibration](../../bench/upstream/hashie_duel/zjit/README.md))
  can be built by the hashie Duel thread; HD1's queue state needs `script/pr-queue sync`.
* rails/rails#59413 closed by its author (Discourse overrides `disallow_raw_sql!`): the eager-matcher cost is pool
  resolution per `order`, for the connection-lookup thread.
* Bug #22419 closed: rerunning actionpack and actionview on master goes to the Ruby-master differential.
* ZJIT `scope_hm` after rails/rails#59569 merged: for the ZJIT-vs-YJIT thread.

**Stays parked, and why** (details in the table): C2/C3 (i18n #763–#766 still unanswered), UA1 (useragent dormant
since 2024-12), DV1, CIR1, TWZ1 and DSC1 (Rails 8.2 beta not out; latest 8.1.4.1), YS1/AS1/J1/`Kernel#dup` (their ruby/ruby
PRs are open), ZSV1/ZSD1/#1129/#1107 (the shortlist gate on ZS1), the Devise second route draw and ViewComponent
`precompute!` (boot only, ≤ 0.7–4% of a production boot, no exact fix), YJIT leads (maintenance mode), and every
lead whose upstream reference hasn't moved. Two leads could not be checked: the svar_lep crash (its 9-line repro is
only in reviewer orb T-01a1e02a; a reconstruction doesn't crash) and the cme `METHOD_ENTRY_CACHED` suspicion (no repro).

## TO1 under ZJIT

TO1 (write tag attributes into the tag's own String) was held for an unexplained ZJIT `f.text_field` +0.64% on
master `f3e180b5eb`. Rebuilt on main `2e299253f9`: it applies cleanly over main's newer `tag_options` change
(`f5e35938a2`). `script/upstream-bench` on Ruby master `0d399335b7`, every window JIT-flat
([table](../../bench/upstream/lead-sweep-2026-11-27/to1-zjit/table.md), raw in `to1-zjit/raw`):

| Per call, TO1 against main | Objects | Interpreter | ZJIT |
| --- | --- | ---: | ---: |
| `text_field_tag` | 7 → 6 | −1.1% (A/A 0.12%) | −0.8% (A/A 0.23%) |
| `submit_tag` | 13 → 12 | −1.0% (A/A 0.05%) | −1.1% (A/A 0.31%) |
| `tag.input` | 4 → 3 | −1.1% (A/A 0.16%) | −2.7% (A/A 0.11%) |
| `f.text_field` | 18 → 17 | **+0.2%** (A/A 0.03%) | **+0.6%** (A/A 0.48%; above both base runs) |
| `f.check_box` | 22 → 20 | −0.9% (A/A 0.22%) | −1.1% (A/A 0.19%) |

**The loss is explained, and it isn't the JIT.** Self Ir per `f.text_field` call, base against TO1
([`to1_zjit_fn_diff.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/to1_zjit_fn_diff.txt)):
`_int_malloc` +274, `_int_realloc` +96, `realloc` +80, `_int_free_chunk` +59, `ruby_xrealloc2_sized` +53, against
−39 `str_duplicate`, −34 object allocation and −34 `rb_str_buf_append` saved. A form-builder field writes its long
attribute list (`type`, `value`, `name`, `id`) into the `"<input"` String, which outgrows its buffer and reallocates
twice; main builds the attributes in their own buffer and copies them once. `text_field_tag`'s short attributes show no
malloc growth. The A/A spread is all `st.c:find_table_entry_ind` (hash-seed collisions), and ZJIT's own counters
agree: TO1 runs 0.6% fewer ZJIT instructions with the same ISEQ calls and side exits, plus one `rb_str_buf_append`
per call ([`to1_zjit_stats_diff.txt`](../../bench/upstream/lead-sweep-2026-11-27/results/to1_zjit_stats_diff.txt)).

Wall time (`script/upstream-bench --wall 30`, ZJIT on master and YJIT on 4.0.10) runs on an a1.xxlarge orb (thread
T-01a21e91-d4ee-77d5-8919-a607d3c925fd); its result is added below when it reports. It doesn't change the decision: the
mechanism above costs on every form-builder field whatever the wall cohort claims.

**Decision: TO1 stays held, as a parked idea.** Its win is 1 object and about 1–3% per short `*_tag` call. Form-builder
fields, where most attribute building happens (census 12: tag attribute building 2.43% mean, up to 11.4%), get the
object back but pay it in reallocation, and the 5-field form moved within noise in the revive run. Sizing the buffer up
front would make the change L2 for a sub-1% per-field effect. Nothing was pushed: the rebased tree is local only, and
the fork branch stays at `7f1f0dce45`.


## STATUS.md: stale sections (proposals; not edited, the inventory thread owns it)

* **"Next" (2026-10-20)** lists the paused engine's priorities (guarded tier, sealed tier, props pass). Replace with
  DECISIONS' current bets: the three big bets of 2026-11-25 (ZJIT gaps on real apps, unreleased Rails 8.2
  regressions, lowrail-profile for any app) and Next (a)–(d) from the same day, plus this sweep's open asks
  (TO1, the two correctness issues, ZL3's question, the `Accept` parse share).
* **"Older follow-ups"** under Next (candidate #4, Campfire fragments, route defaults, memo certificates) are lowering
  items: move them with the 2026-10-20/21 sections (Lowering prototype at a glance, the re-prices, Works, Evidence,
  Learned) to [prototype.md](../prototype.md) or the archive, and keep one line in STATUS.
* **At a glance (2026-11-17):** "Latest census: 9 (2026-11-14)" is stale; census 12 (2026-11-27) is current
  ([census 12](rails-main-census-12.md): main −8.54% median interpreted, hot work ranked). "Ruby 4.1 (2026-11-16)"
  predates the 4.0.9 differentials ([heavy apps](ruby41-differential-409-heavy.md), 2026-11-27). The heading date
  should follow its newest row.
* **"Rails main breaks two corpus apps … not reported as of 2026-11-14"** needs a recheck date (the ZJIT gap census
  2 still lists Fizzy and Lobsters as unmeasurable on main).
* Missing from At a glance: the open queue (25 held items, 50 ready), lowrail-profile 0.1's state (no release
  before the field test), and Ruby pin 4.0.10.

## Every lead

Rows are numbered as extracted; a lead named in two records appears in each area. "Parked: condition unchanged"
means its upstream references (Check column) haven't moved and it was not re-measured today.

### ZJIT and YJIT (zjit-*.md, yjit-*.md)

| # | Lead | Source | Revisit condition | Check (2026-11-27) | Decision |
| ---: | --- | --- | --- | --- | --- |
| 0 | YAO, rework of ruby#19648 (YJIT attached-object predicate) | yjit-attached-object-is.md:3, :100 | "PR and its original branch must remain unchanged until [Sol/Astra] review and Thomas's update decision"; the body assumes #19740 is still open | ruby#19648 merged 11-06 in its original form. | Closed: the PR merged; the reviewed rework is moot. |
| 1 | Fix PR for Shopify/ruby#1131 (YJIT `super` in a block rebound with `instance_exec`) | yjit-leads.md:127 | "Filed 2026-11-17 … a fix PR on ruby/ruby can follow" | Shopify/ruby#1131 open, no fix upstream. | Parked: a YJIT correctness fix would be a ruby/ruby PR. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 2 | YJIT `super` from a module prepended to a singleton class (`html_escape`) | yjit-leads.md:181 | "picked up later if YJIT performance work becomes relevant again"; check ZJIT first (:104-109) | GitHub: ruby#19487 open 11-18 | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 3 | YJIT `sendforward` with caller arguments | yjit-leads.md:185 | YJIT parked (:104); "ZJIT's counterpart is #18326" | GitHub: ruby#19671 closed 11-03 | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 4 | YJIT `where!(opts, *rest)` splat | yjit-leads.md:187 | YJIT parked (:104) | No upstream reference; not re-read today. | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 5 | YIB1 (guard the block-handler type before a generic `invokeblock`) | yjit-leads.md:189, :257-260 | "To pick it up: x86 Callgrind … railsbench/lobsters counters and Ir, then Thermos and Astra"; held while YJIT is parked | Unchanged. | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 6 | YJIT `BasicObject#!=` for `BasicObject#==` receivers | yjit-leads.md:196 | YJIT parked; the ZJIT side merged as ZNE1 | GitHub: rails#59811 closed 11-15; ruby#19909 merged 11-16 | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 7 | J2 wall time (YJIT `sendforward`, #19671) | yjit-sendforward.md:141-143 | "A maintainer run on bare-metal ruby-bench is needed for a timing number" | GitHub: ruby#19671 closed 11-03 | Parked: YJIT is in maintenance mode, leads are for understanding only (DECISIONS). |
| 8 | Z11 apps not run: Docuseal, Lago, Chatwoot, Flow **[owned elsewhere: test suites]** | zjit-app-differential.md:247-251 | bullet supports AR 8.2; awesome_print fixed; commonmarker builds on master; temporalio allows Ruby 4.1 | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 9 | J1 follow-up: `send` with a non-constant name | zjit-send.md:325-333 | "a follow-up to #19583 once it lands, not a separate PR now" | ruby#19583 still a draft. | Parked: waits for ruby#19583. |
| 10 | ZSF, Shopify/ruby#1133 (zsuper with keywords into a `(...)` method) | zjit-zsuper-forwardable.md:3-6, :70-72, :79 | "Nothing was posted on the issue and no PR opened"; "The CASA threshold-1 check … is still open"; "zjit-sfr-exp/* was not checked" | Repro passes on master 0d399335b7 under --zjit --zjit-call-threshold=1: the bug is only on k0kubun's headline branches; Shopify/ruby#1133 is filed and open. | Parked: nothing to fix on master; the fork fix waits for the headline branch to be proposed. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 11 | Z5 follow-up: polymorphic Module interpolation | zjit-objtostring.md:314-320 | "left for the issue discussion" (`TODO(max)` from #17499) | GitHub: Shopify/ruby#1091 closed 11-05; ruby#17499 merged 06-26 | Parked: condition unchanged or no trigger; not re-measured today. |
| 12 | ZSD1, Shopify/ruby#1106 (`String#dup` on bare Strings) | zjit-shortlist.md:322, :437-439, :449; zjit-stats-2026-11-18.md:427 | "Needs a fresh review of `baed628ce1` before posting"; "whether a 2.5% micro gain is worth sending is the open call"; "ZSD1 stays parked" | Shopify/ruby#1106 open, no assignee. | Parked: -2.5% of one cfunc call for a new HIR instruction; below the ZJIT bar. |
| 13 | ZSV1, Shopify/ruby#1122 (profile the real class for `setinstancevariable`) | zjit-shortlist.md:323, :396-406; zjit-stats-2026-11-18-evening.md:173 | "Nothing has been opened or posted, and the usual upstream approval still applies"; held | Shopify/ruby#1122 open; ZS1 approved by k0kubun 11-25 but not merged. | Parked: the shortlist gate (ZS1 merges first) still holds. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 14 | Shopify/ruby#1130 (one stack-overflow check for inlined frames) | zjit-shortlist.md:324, :463-484 | "Stop here unless tekknolagi wants the caller-side version, or #1023's virtual inline frames change the costs" | GitHub: Shopify/ruby#1130 open 11-16 | Parked: condition unchanged or no trigger; not re-measured today. |
| 15 | Shopify/ruby#1129 and #1107 constant folds | zjit-shortlist.md:325 | "unmeasured, small", "free"; the shortlist gate is "Nothing opens until ZS1 (#19912) gets a response" (:269) | Shopify/ruby#1129 and #1107 open, unassigned. | Parked: unmeasured, gated on ZS1 like the rest of the shortlist; ruby/ruby PRs need Thomas. |
| 16 | ZL3, lead 3 polymorphic miss → recompile | zjit-shortlist.md:327; zjit-leads.md:197-208, :319-355, :485-486 | "Which way lead 3 goes is their decision" (question posted on #776, 11-14); further checks "Only if the ZJIT team wants the recompile" | Re-measured: lead3_repro on master 0d399335b7 still 0.5 send_polymorphic_fallback per call (unchanged since 11-14). Shopify/ruby#776 has no team answer since our 11-14 comment. New context: our OTS1 (ruby#19982, merged 11-24) is a recompile-on-guard-failure the team accepted. | Held. Proposal for Thomas: cite OTS1 as precedent when asking the ZJIT team again; ruby/ruby PR needs Thomas. |
| 17 | Comment draft on Shopify/ruby#995 (IncrCounter double count fixed) | zjit-stats.md:86-99 | draft "not posted"; no condition stated | GitHub: Shopify/ruby#995 open 11-03; ruby#19485 merged 10-29 | Parked: condition unchanged or no trigger; not re-measured today. |
| 18 | Z10 per-ISEQ stats (`--zjit-stats-iseq`), Shopify/ruby#746 | zjit-stats.md:179-198; zjit-iseq-leads.md:5, :794-802 | "the #746 claim still waits for a reply" | GitHub: Shopify/ruby#746 open 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 19 | Comment draft on Shopify/ruby#1039 (Rails-main breadth for rows 11/19/20/22/47) | zjit-iseq-leads.md:777-792 | "not posted" | GitHub: Shopify/ruby#1039 closed 11-24 | Parked: condition unchanged or no trigger; not re-measured today. |
| 20 | Frameless `Hash#key?` / `Regexp#match?` | zjit-stats-2026-11-18.md:314-319, :426; zjit-cfunc-paths.md:125, :714; … | "Not worth it now" (≈0.03–0.08% of an iteration; up to 0.19% on shipit for `Hash#key?`) | GitHub: Shopify/ruby#1059 open 09-25; ruby#16019 closed 04-19 | Parked: condition unchanged or no trigger; not re-measured today. |
| 21 | `Hash#fetch`: one-argument and block forms after #19949 | zjit-stats-2026-11-18.md:311-313 | after #19949 merges | ruby#19949 open. | Parked: waits for ruby#19949. |
| 22 | `expandarray` `GuardType(ArrayExact)` with `recompile: None` | zjit-stats-2026-11-18.md:353-354 | "#1039 row 18 profiles expandarray, so it is left alone" | GitHub: Shopify/ruby#1039 closed 11-24 | Parked: condition unchanged or no trigger; not re-measured today. |
| 23 | YS1: `yield` to a Symbol block in an inlined iterator | zjit-stats-2026-11-18-evening.md:183-189; zjit-iseq-leads.md:229 | "wait for that merge" (ruby/ruby#19912) | ruby#19912 open (approved 11-25, not merged). | Parked: waits for ruby#19912 to merge. |
| 24 | AS1: auto-splat yields into an inlined iterator | zjit-stats-2026-11-18-evening.md:190-194; zjit-iseq-leads.md:230 | waits for ruby/ruby#19659 | ruby#19659 open. | Parked: waits for ruby#19659 to merge. |
| 25 | shipit `StableConstantNames` exits under #19617 **[owned elsewhere: connection lookup]** | zjit-stats-2026-11-18-evening.md:158-161 | "#19617's effect on current master was not rebuilt here" | GitHub: ruby#19617 open 11-03 | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 26 | ZNE1 lead 2: `!=` with a refinement of `Kernel#==` | zjit-not-equal.md:402-409 | "nothing is posted upstream" (:384) | Re-run on 4.0.10 and master 0d399335b7: interpreter raises NoMethodError, --zjit returns true (divergence still there; repro bench/upstream/zne1/leads/kernel_eq_refinement.rb). | Correctness, not reported: an issue with this repro is a new issue. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 27 | ZNE1 lead 3: missing `Integer#==` C frame below `BasicObject#!=` | zjit-not-equal.md:410-418 | "a question for #19162's authors, not a bug report" | GitHub: ruby#19162 merged 10-14 | Parked: condition unchanged or no trigger; not re-measured today. |
| 28 | ZNE1 lead 4: `RUBY_DEBUG` assertion in `clear_method_cache_by_id_in_class` | zjit-not-equal.md:419-427 | "Whether the assertion or the cache state is wrong is not known" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 29 | Z4 draft comment: the #18326 correctness bug | zjit-open-prs-on-rails.md:24-43, :246-268 | "Data only, for Thomas to check and post" | ruby#18326 still an open draft; the bug is in the PR, not on master. | Parked: nothing on master to report. |
| 30 | Z4 draft comment on #19583 (Rails data) | zjit-open-prs-on-rails.md:270-280; zjit-send.md:357 | "These numbers can go in only if its author asks" | GitHub: ruby#19583 open 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 31 | G: dynamic `super` in a final version (on top of #19682) | zjit-super-block.md:131, :187-195 | "worth building only if a real app shows mixed sites or exhausted versions at `super`" | GitHub: ruby#19682 merged 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 32 | H: branch on the block handler at flagged `super` sites | zjit-super-block.md:132, :157-163, :195 | same as G | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 33 | B / 8b: pass the frame's block to the `super` callee | zjit-super-block.md:133, :195; zjit-iseq-leads.md:222 | "B stays a parked prototype" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 34 | `invokesuperforward` specialization (`super(...)`) | zjit-super-block.md:107, :174-175, :190-194 | "need a ruby-bench measurement before anyone builds them"; measure "if row 46 or a `super(...)` PR appears" | GitHub: ruby#18326 open 11-03; Shopify/ruby#862 closed 01-27 | Parked: condition unchanged or no trigger; not re-measured today. |
| 35 | Splat zsuper `def m(*) = super` | zjit-super-block.md:108, :192 | same as above | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 36 | `super` from a block (Shopify/ruby#993) | zjit-super-block.md:173; zjit-cfunc-paths.md:97-99 | "it stays held" | GitHub: Shopify/ruby#993 open 06-17 | Parked: condition unchanged or no trigger; not re-measured today. |
| 37 | `Kernel#dup` in Ruby / patch-point dup (Shopify/ruby#1058) | zjit-cfunc-paths.md:21-29, :464-477, :479-498; zjit-shortlist.md:273-276 | "land the Ruby version behind `with_jit` once #19583 is in; re-measure it with #19617"; "stays blocked on both" | ruby#19583 draft, ruby#19617 open. | Parked: both blockers open. |
| 38 | `dup` hook table for Set/Struct/Data, plus `clone` | zjit-cfunc-paths.md:239-241, :342-343 | "Toward a PR (not started)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 39 | RUBY19681 reply to k0kubun (lobsters/real workloads) | zjit-compile-speed.md:351-355, :452-455 | "Nothing posted or PATCHed; upstream publication still requires Thomas's approval" | GitHub: ruby#19681 open 11-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 40 | FxHash for the side-exit dedup map (Shopify/ruby#1049) | zjit-compile-speed.md:214-218, :227-230 | "Measure it with the same A/A rounds as c1/c2 before proposing it" | GitHub: Shopify/ruby#1049 open 09-14 | Parked: condition unchanged or no trigger; not re-measured today. |
| 41 | ZRS1, ruby/ruby#19976 (super from a refined method, Shopify/ruby#1128) | zjit-differential.md:341-351, :579-636; zjit-not-equal.md:388-401 | "Drafts remain unchanged … nothing is approved for posting"; the PR branch is still at `1d86986033` | ruby#19976 merged 11-25, Shopify/ruby#1128 closed. | Done upstream. |
| 42 | Ractor::Port close in a forked child: SIGSEGV | zjit-differential.md:146-161 | "Not reported. It belongs to the Ractor and fork code" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 43 | redcarpet assertion under auto-compaction | zjit-differential.md:163-168 | "Not investigated further"; the r81 variants were not rerun (:648-649) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 44 | Z2/Z11 suites not run **[owned elsewhere: test suites]** | zjit-differential.md:174-178, :643-650; zjit-gap-census-2.md:249-252 | "not set up in this orb" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 45 | C: rest parameter copies a caller-built splat Array (Shopify/ruby#1095) | zjit-iseq-leads.md:223, :690 | "Free (ours, no assignee, no PR)"; ruby-bench Ir unmeasured | GitHub: Shopify/ruby#1095 open 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 46 | F: cme `METHOD_ENTRY_CACHED` correctness suspicion | zjit-iseq-leads.md:226 | "Needs a repro before anything else; if one exists it is an issue-worthy bug" | Not tried today. | Parked: needs a repro before anything; unchanged. |
| 47 | 7c: recompiling guards on skewed profiles keep exiting | zjit-iseq-leads.md:429 | "Free, unmeasured in general" | GitHub: ruby#19617 open 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 48 | 7d: inline callees that receive a forwarded block handler | zjit-iseq-leads.md:430 | "Free: #1039 row 44 (unassigned)", unmeasured | GitHub: Shopify/ruby#1039 closed 11-24 | Parked: condition unchanged or no trigger; not re-measured today. |
| 49 | 3d: megamorphic sites with one method entry **[owned elsewhere: connection lookup]** | zjit-iseq-leads.md:676 | "Free: #1039 rows 24/25/27" | GitHub: Shopify/ruby#1039 closed 11-24 | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 50 | A: `Hash.new(capacity:)` not specialized under ZJIT | zjit-iseq-leads.md:415 | "Remeasure #59557 once it lands" | rails#59557 closed 11-05; ruby#19662 closed. | Closed: both sides closed. |
| 51 | B: direct association scope build under ZJIT | zjit-iseq-leads.md:416 | "Next step: `--zjit-stats-iseq` on `scope_hm`" | rails#59569 merged 11-26. | Handed to the ZJIT-vs-YJIT thread (a ZJIT-only gap on a merged Rails path). |
| 52 | F (census 8): Discourse runs `Time.parse` only under ZJIT | zjit-iseq-leads.md:693 | "Free … mechanism, caller and Ir unmeasured" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 53 | F1-a: ZJIT segfault in `vm_lookup_cc` (CASA) | zjit-iseq-leads.md:704 | "not reproduced in 2 h"; free | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 54 | F1-b: `FixnumLShiftOverflow` exit in TZInfo at boot | zjit-iseq-leads.md:705 | free | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 55 | F1-c: recompile churn per request | zjit-iseq-leads.md:706 | "free upstream; overlaps J1's Z12" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 56 | F1-d: default exec region too small **[owned elsewhere: memory]** | zjit-iseq-leads.md:707 | "free (no issue found)" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 57 | G: railsbench GC heap bistability **[owned elsewhere: memory]** | zjit-iseq-leads.md:227 | "Unowned and not investigated further for now" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 58 | ZS1, ruby/ruby#19912: push -5 and post the replies | zjit-symbol-block.md:1357-1360, :1772-1783, :2032-2097 | "can be posted directly once checked; the PR is already approved"; the body must-fix shortens paragraph 1 (:2009-2011) | ruby#19912 approved 11-25, open. | Parked: replies and the -5 head are Thomas's ruby/ruby conversation. |
| 59 | C-level Symbol yields (`rb_yield` → `vm_yield_with_symbol`) | zjit-symbol-block.md:269-272, :290 | "The C-level yields are not a bet. Only their ceiling is measured" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 60 | `Symbol#to_proc` redefined with itself: exits on every call | zjit-symbol-block.md:893-894 | "Not applied" | GitHub: ruby#19912 open 11-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 61 | VM fix for the basic flag (`method_entry_set` invalidates the entry) | zjit-symbol-block.md:895-896 | "belongs in the VM … as its own PR" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 62 | svar_lep crash with a refined cached lambda | zjit-symbol-block.md:900-903 | "present on master, not from this change" (not reported) | The 9-line svar_bug.rb lives only in reviewer orb T-01a1e02a; a reconstruction (repros/svar_refined_lambda.rb) does not crash on 4.0.10 or master. | Parked: needs the original repro; then an issue for Thomas. |
| 63 | `RUBY_BOX=1`: `[1, 2].sum(&:dbl)` with refinements raises NoMethodError | zjit-symbol-block.md:908 | not reported | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 64 | Compaction plus `GC.stress`: empty class name in `ToProc#to_proc` | zjit-symbol-block.md:909-910 | not reported | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 65 | `zjit_alloc_bytes` +13,347 on railsbench **[owned elsewhere: memory]** | zjit-symbol-block.md:2081-2089 | "would need a per-allocation-site breakdown" | GitHub: ruby#19912 open 11-25 | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 66 | OO1: `OrderedOptions#_get` public **[owned: zjit-vs-yjit thread]** | zjit-yjit-gap.md:49-52, :173-233 | "if ZJIT doesn't learn protected sends (#1109) before 4.1, it is the cheapest way …" | GitHub: Shopify/ruby#1109 open 11-06 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 67 | Comment draft on Shopify/ruby#1109 (protected sends) **[owned: zjit-vs-yjit thread]** | zjit-yjit-gap.md:235-289 | "for whoever takes it" (not posted) | GitHub: Shopify/ruby#1109 open 11-06 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 68 | 13: JITFrame root marking on every GC **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:213, :306-315 | free in the 11-03 record; gap-census-2 (zjit-gap-census-2.md:177) reports k0kubun's `zjit-dev` `5cab45a617`, `4319a272fe` | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 69 | 14c: ISEQ callees with `**rest` or `(a, ...)` **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:214; zjit-yjit-gap.md:929 | "free: #1039 rows 36 and 43" | GitHub: Shopify/ruby#1039 closed 11-24 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 70 | 14d: a `nil` `&blk` passed to a C method **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:217; zjit-yjit-gap.md:930; zjit-stats-2026-11-18.md:306-307 | "free and small" | GitHub: Shopify/ruby#1039 closed 11-24 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 71 | 16: PatchPoint nop padding **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:219, :346-351 | "Measure cycles before acting" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 72 | 18: `with_vm_lock` → `gc_rest` on invalidation **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:220, :373-379 | "Wall-time and pause effect only, unmeasured" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 73 | D: YJIT skips an Array in the generated `_layout` **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:224, :691 | "Free … Mechanism and Ir unmeasured" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 74 | E: `nil.try(:x)` rest Array in Active Storage blocks **[owned: zjit-vs-yjit thread]** | zjit-iseq-leads.md:225, :692 | "Free"; the micro does not reproduce it | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 75 | `likely_a` for polymorphic subtype profiles (`String#<<`) **[owned: zjit-vs-yjit thread]** | zjit-gap-census.md:149-230 | "worth submitting only if `StringAppend` codegen gets cheaper"; "held, kept for a later round" | GitHub: Shopify/ruby#1051 closed 09-23 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 76 | Fizzy and Lobsters census unmeasurable on Rails main **[owned: zjit-vs-yjit thread]** | zjit-gap-census-2.md:73-77 | when Fizzy and typedstore work on Rails main | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |

### Rails (Rails census, request-path and app-suite records)

| # | Lead | Source | Revisit condition | Check (2026-11-27) | Decision |
| ---: | --- | --- | --- | --- | --- |
| 92 | W1 (main-regressions): create paths don't share main's gain | main-regressions.md:142, :163 | "Next. Bisect POST comment between 8.1.4.1 and `cadf0fc8d6` … judge each unjudged row. No fix built." | rails#59530 merged 11-09 changed one unjudged row. | Parked: the bisect is still undone; the 8.2 regression bet (rails-main-census-11) owns create paths. |
| 93 | R1 (main-regressions) | main-regressions.md:140 | "R1 can open … if #59141 closes, or once it merges, if its `keys` still recomputes" | rails#59141 merged 11-11 and rewrote AttributeSet#map/deep_dup into eager transform_row copies. | Superseded by rails#59141. |
| 94 | QB#3 bound relation template per association | query-building.md:254, :417 | "worth a design discussion with a maintainer before any code" | GitHub: rails#59212 open 11-06 | Parked: condition unchanged or no trigger; not re-measured today. |
| 95 | QB#4 statement cache for `exists?`/`count`/`size` | query-building.md:255 | "possible follow-up after #59212" | GitHub: rails#59212 open 11-06 | Parked: condition unchanged or no trigger; not re-measured today. |
| 96 | Fizzy UUID type / Solid Cache Arel reads (**OE**: Solid) | query-building.md:262-264 | "app or gem leads, not pursued" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 97 | Url helper `define_method` invalidation (VM lead) | rails-boot.md:353-368 | "A Ruby change … belongs to the Ruby side" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 98 | Devise draws routes twice | rails-boot.md:369-375 | "(lead)"; not exact in Rails | Not re-measured (needs Devise apps). | Parked: boot-only (0.7-4% of a production eager-load boot); no exact Devise or Rails fix. |
| 99 | Journey regexps rebuilt before dedup | rails-boot.md:384-388 | "below the bar … one app reached" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 100 | PM2 tag_options String-key `blank?` shortcut | perf-round-main.md:311-317 (also :205 backport) | "Reopen only if Rails decides `blank?` on attribute keys may be assumed pure"; backport "once it lands on main" | rails#57999 still open on the same lines. | Parked. |
| 101 | `emitting?` `{ name: }` per call | perf-round-main.md:258-260 | "Lead, not built"; can't share without changing what filters receive | GitHub: rails#58957 open 11-27 | Parked: condition unchanged or no trigger; not re-measured today. |
| 102 | `Notifications.notifier`, `_routes` via `helper_module._routes` | perf-round-main.md:378 | "small leads behind `Ractors.main?`, not measured further" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 103 | `result.rb:118` `types = {}` capacity | perf-round-main.md:392 | "held while #59557 is open" (#59557 closed 11-05; IWC rule: revisit when Ruby 4.1 nears release or is the minimum) | rails#59557 closed; Ruby 4.1.0 has preview1 only (no RC). | Parked: revisit on the 4.1 RC (IWC condition a). |
| 104 | `@association_cache \|\|= {}` spill | perf-round-main.md:398 | "a lead" | GitHub: ruby#18345 merged 08-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 105 | `join_dependency.rb:17` `each_with_object({})` | perf-round-main.md:402 | "a lead" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 106 | `only_columns` class-chain walk | perf-round-main.md:437 | "a lead: the class-chain walk could be cheaper, not measured further" | GitHub: rails#57364 merged 05-15 | Parked: condition unchanged or no trigger; not re-measured today. |
| 107 | MK1 cookie cipher per request | p-map.md:170, :290-291 | "Open only together with other cookie-jar work" (item note) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 108 | AMS 0.10 in Mastodon | p-map.md:171 | "a lead for AMS, not pursued" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 109 | #59538 frozen shared `binds` | merged-audit.md:56-84 | "If a report turns up, the fix is to pass `[]` … again" | GitHub: rails#59538 merged 11-02 | Parked: condition unchanged or no trigger; not re-measured today. |
| 110 | #59536 frozen `collect_warnings` | merged-audit.md:86-98 | same: on a report | GitHub: rails#59536 merged 11-02 | Parked: condition unchanged or no trigger; not re-measured today. |
| 111 | #59562 `event_method_names` class-level name | merged-audit.md:100-108 | same: on a report | GitHub: rails#59562 merged 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 112 | #59560 `HashLookupTypeMap#fetch` overrides | merged-audit.md:110-117 | same: on a report | GitHub: rails#59560 merged 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 113 | #59537 private `tag_string` arg order | merged-audit.md:119-124 | same: on a report | GitHub: rails#59537 merged 11-02 | Parked: condition unchanged or no trigger; not re-measured today. |
| 114 | #59571 scope arity 0 | merged-audit.md:126-132 | same: on a report (ransack checked fine) | GitHub: rails#59571 merged 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 115 | ZJIT `track_cme_assumption` flag gap (**OE**: ZJIT) | merged-audit.md:192-195 | "belongs in the ZJIT lead queue as unmeasured" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 116 | HWIA `merge(...)` rest Array | as-request-paths.md:373 | "needs a second single-argument path (L2) … Not built" | Unchanged. | Parked: L2, below the bar. |
| 117 | `InheritableOptions#initialize` copies | as-request-paths.md:374 (also census-12:121) | "Design question after #59105 (P1-1)"; OO1 held | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 118 | `Array#deep_dup` `map { _1.deep_dup }` | as-request-paths.md:375 | "Lead only" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 119 | `groups_for` dup per event | as-request-paths.md:371 | "new cached state (L2)"; census-12 row 1 "not yet priced" | GitHub: rails#58957 open 11-27 | Parked: condition unchanged or no trigger; not re-measured today. |
| 120 | `APP_DIRS_PATTERN` removed | api-regressions.md:156 | "Coordinator: record only" | GitHub: rails#56333 merged 12-12 | Parked: condition unchanged or no trigger; not re-measured today. |
| 121 | `NumericalityValidator#validate_each` kwargs | api-regressions.md:157 | "would only break a caller that passes the keywords; none was found" | GitHub: rails#59246 merged 10-22 | Parked: condition unchanged or no trigger; not re-measured today. |
| 122 | `SpawnMethods#merge(other, *rest)` | api-regressions.md:158 | "No caller was found" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 123 | F1-1 `def m(k: 1, **) = super` extra Hash | frontier-census-f1.md:277, :272-273 | "no ruby/ruby PR … while our open ruby/ruby PRs exceed 15"; next step "a fix on top of #19670" | ruby#19670 closed 11-10; open ruby/ruby PRs of ours: 8. | Parked: a ruby/ruby PR needs Thomas to name it. |
| 124 | F1-2/4/5 not-inlined `Hash#key?`, `Fiber.[]`, `html_escape` (**OE**: ZJIT) | frontier-census-f1.md:278-281 | "Z7 decides" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 125 | F1-3 default `--zjit-exec-mem-size` (**OE**: ZJIT/memory) | frontier-census-f1.md:279 | "data for an issue; Thomas decides" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 126 | F1-6 recompiles after warmup (**OE**: ZJIT) | frontier-census-f1.md:282 | "hand to J1's Z12" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 127 | F1-7 CASA ZJIT segfault (**OE**: ZJIT) | frontier-census-f1.md:283, :362-365 | "Next steps if it is picked up again: a debug build … repeated CASA runs" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 128 | find_by_sql typed literals: docs note | find-by-sql-typed-literal-binds.md:39-44 | "maintainer decisions" | rails#59565 open, no comments. | Parked. |
| 129 | Herb statement-line trim rework | herb-tags-across-branches.md:154-155, :172-175 | "belongs with whoever owns Herb's trim logic"; event: "herb#2892 reply → answer only what is asked" (inventory.md:74) | GitHub: marcoroth/herb#2892 open 11-06 | Parked: condition unchanged or no trigger; not re-measured today. |
| 130 | `current_time_from_proper_timezone` connection checkout | ar-request-paths.md:221 (ar-write-paths.md:191) | "Not built, as leads"; W2 removed the wasted call | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 131 | `any_changes?` → `LazyAttributeSet#keys` | ar-request-paths.md:222; ar-write-paths.md:190 | "Lives in the attribute set that open #59141 rewrites; would conflict" (#59141 merged; K1 merged; L6 note: "fewer #keys walks … investigated separately") | rails#59141 and K1 merged; DT1 held today (CASA regression). | Parked with DT1. |
| 132 | C6-2 preloader class lists in place | ar-write-paths.md:188 | "Parked until #59564 merges" (#59564 closed unmerged 11-10, on an ownership objection) | rails#59564 closed 11-10 on tenderlove's ownership objection. | Closed for good (same objection applies). |
| 133 | activerecord-postgis-adapter 3-arg override | ar-gems-after-59141.md:19 | open upstream issue; watch | GitHub: rgeo/activerecord-postgis-adapter#445 open 11-23 | Parked: condition unchanged or no trigger; not re-measured today. |
| 134 | activerecord-cockroachdb same override | ar-gems-after-59141.md:20 | "record only (niche adapter)" | GitHub: cockroachdb/activerecord-cockroachdb-adapter#409 open 10-19 | Parked: condition unchanged or no trigger; not re-measured today. |
| 135 | `OutputBuffer#initialize` `+""` | actionview-render-c12.md:55 | "About 0.015%" — under the bar | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 136 | `field_id` skip `gsub` | actionview-render-c12.md:56 | "about 0.01% overall" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 137 | T2 `append_tag_option` (parked) | actionview-render-c12.md:33 | "(T2, parked)" | rails#57999 still open. | Parked. |
| 138 | SafeBuffer.new misses `opt_new` | actionview-render-c10.md:302-310 | "no ruby/ruby PR or issue (no new ruby/ruby PRs, DECISIONS)"; jhawthorn declined #19667 | GitHub: ruby#19667 closed 11-03; ruby#19703 merged 11-04 | Parked: condition unchanged or no trigger; not re-measured today. |
| 139 | `ThroughReflection#options` via `delegate` (parked) | ar-read-paths.md:41-59 | "would also go into `reflection.rb` while that file is being reworked. Not built." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 140 | Query-cache key hashing (**OE**: query-cache key) | activerecord-cpu.md:204; rails-main-hotlines-2026-11-27.md:63-64; … | "price after it lands" (#59518) — **#59518 merged 2026-11-27** | GitHub: rails#59518 merged 11-27 | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 141 | SQLite `stmt.types` mapping per query | activerecord-cpu.md:211 | "not exact" (re-prepare after schema change) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 142 | Campfire invalid-body 500 | campfire-rework-2026-11-18.md:56-58, :224 | Marcello asked to open it as his own PR (CF350 note) | GitHub: basecamp/once-campfire#350 closed 11-18 | Parked: condition unchanged or no trigger; not re-measured today. |
| 143 | CF346 follow-ups: batched enqueue + 8 s shutdown | campfire-rework-2026-11-18.md:226 | "Reopen them as follow-ups after #346 merges?" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 144 | `Mime::Type.parse` Firefox Accept | actionpack-request-path.md:326-327 | "Worth a round of its own; it touches parsing" | Re-measured on main 2e299253f9 (each mode twice): Mime::Type.parse costs 9.5-9.6 us / 38 objects (Firefox) and 20.7-21.4 us / 81 objects (Chrome) under YJIT 4.0.10, 8.7-8.9 / 19.6 us under ZJIT master, 12.1-12.5 / 26.3-26.5 us interpreted. New: Rails main's 8.2 defaults set strict_accept_header = true (configuration.rb:378), so every browser request of a new app parses the Accept header. A per-header cache was rails#59455 (linyiru), closed 10-30 after fatkodima: 'will not have any difference on a real world app'. | Parked, upgraded: needs a request-level share on an app with 8.2 defaults before any shape is built; a cache is declined, a no-cache rewrite would recover only part of the 9-21 us. |
| 145 | strscan `skip` nil vs raise / Journey spin | actionpack-request-path.md:329-348 | asked as strscan#223; "whether Rails should guard its loop" | ruby/strscan#223 still open. | Parked. |
| 146 | ZJIT `InvokeSuper` on singleton receivers (**OE**: ZJIT-vs-YJIT) | actionview-cpu.md:743-746 | "Check with ZJIT's send-fallback stats on erubi-rails before recording a ZJIT lead" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 147 | R2-3 URL default merge | actionview-cpu.md:729; rails-common-paths.md:282 | "R2-3 … stays held" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 148 | Rack ETag via OpenSSL SHA-256 | stack-map.md:250 | "Yes, Rack" — covered by rack#2522 | GitHub: rack/rack#2522 open 11-20 | Parked: condition unchanged or no trigger; not re-measured today. |
| 149 | concurrent-ruby map / `details_cache_key` | stack-map.md:258-261 | "No exact gem change identified" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 150 | PT1 transactional-fixture pool scans (**OE**: test-suite overhead) | test-overhead.md:13-20, :356, :392-395 | "gates if the idea is revisited with sufficient impact" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 151 | Schema context (a) cheaper `schema_context` | schema-context.md:115-118 | "Not built. Open #59530 … rewrites" (**#59530 merged 11-09**) | Re-measured: after rails#59530 Post.attributes_builder costs 134 ns (interp), 41 ns (YJIT), 42 ns (ZJIT master). | Closed: rails#59530 removed the slow path. |
| 152 | Schema context (b) faster slow path | schema-context.md:119-121 | "Not built, for the same overlap" (#59530 merged) | Same as (a). | Closed: rails#59530. |
| 153 | Per-row `attributes_builder` hoist | schema-context.md:140-145 | "open #59141 … still reads `klass.attributes_builder` once per row" (#59141 merged 11-11) | Re-measured: 11 reads per 10-row load, 1.2-1.3% of Post.all.to_a in every mode (interp 1.5/112.6 us, YJIT 0.45/41.1 us, ZJIT 0.46/34.3 us). | Parked: below the bar. |
| 154 | `csrf_meta_tags` under `:header_only` | rails8-defaults.md:373-376 | "this month's work, so it waits" (written early Nov) | Sam Ruby's :header_only change landed 10-25 and is now an 8.2 default; not re-measured. | Parked: the only shape that drops the second protect_against_forgery? call skips it for overrides of the documented embed_authenticity_token?; at most half of 1.7% of a bare page. |
| 155 | `AssetUrlHelper` config reads | rails8-defaults.md:377-379 | "A follow-up for him [maintainer], not for us" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 156 | `ActionDispatch::Static` six `stat(2)` | rails8-defaults.md:380-381 | "Being reworked by others" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 157 | Form parsing `URI.decode_www_form_component` | rails8-defaults.md:382-383 | "ruby/uri is parked" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 158 | Solid Cache local cache per request (**OE**: Solid) | rails8-defaults.md:384-385 | "small, left" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 159 | DSC1 Discourse UTF-8 repair after #59570 | vm-share.md:316-318 | "open a short Discourse issue or PR at the Rails 8.2 beta … could open earlier if Thomas prefers" | Rails 8.2 beta not out (latest 8.1.4.1). | Parked until the 8.2 beta. |
| 160 | vm-share #8 singleton-class receivers | vm-share.md:126 | "not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 161 | vm-share #9 `Time.===` → `super` | vm-share.md:127 | "not built: no exact replacement" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 162 | Debug-page source extracts | rails-main-hotlines-2026-11-27.md:55-57 | "lazy extracts would change the page. Lead only." (DV1 held: "Reopen if a suite … renders many debug pages") | DV1 held today (relevance). | Parked with DV1. |
| 163 | `IsolatedExecutionState.[]` + connection lookup (**OE**: connection lookup) | rails-main-hotlines-2026-11-27.md:65-66; rails-main-census-12.md:119-120; … | "Needs pricing" | No upstream reference; not re-read today. | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 164 | `build_request` env_config merge (**OE**: env_config) | rails-main-hotlines-2026-11-27.md:67; rails-main-census-12.md:125 | "Needs pricing" | No upstream reference; not re-read today. | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 165 | CSRF token masking | rails-main-census-12.md:122, :129 | "no measured avoidable price yet" | GitHub: rails#59430 merged 10-30 | Parked: condition unchanged or no trigger; not re-measured today. |
| 166 | `cast_result` PG / `symbolize_keys!` cookie jar | rails-main-census-12.md:127 | "The ranked lists hold the rest" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 167 | `Time#change` Rationals | rails-main-census-4.md:291; census-5:114 | "Not small. Lead only." (#59323 fixed 6→2 objects, hotlines:55) | GitHub: rails#59323 merged 10-23 | Parked: condition unchanged or no trigger; not re-measured today. |
| 168 | `Merger#initialize` `other.values` copy | rails-main-census-4.md:292; rails-main-census-5.md:124, :239-244 | "if maintainers want a reader" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 169 | YJIT-only allocations (Class#new, zsuper, collectors) (**OE**: ZJIT-vs-YJIT) | rails-main-census-4.md:301-321; census-5:333-350; census-3:200, :254 | "belong in a ruby/ruby report with this script" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 170 | `capture_helper.rb:59` `yield(*, **)` | rails-main-census-5.md:143, :349-350 | "did not reproduce standalone and stays unexplained" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 171 | `handler_for` per-class cache | rails-main-census-8.md:375-377 | "L2. No open or closed PR found." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 172 | Census-8 ZJIT leads C–F (**OE**: ZJIT-vs-YJIT) | rails-main-census-8.md:429-443 | "all are free, unmeasured in Ir" | GitHub: Shopify/ruby#1095 open 11-03 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 173 | Census-9 lead 2 K5 `form_tag { }` with block | rails-main-census-9.md:39 | "K5 is optional" (K6 merged #59804) | rails#50312 merged. | Parked: K5 is optional and bypasses the public form_tag (closed in k6 README). |
| 174 | Census-9 lead 4 by-name access after #59141 | rails-main-census-9.md:41; census-10:56 | "tenderlove plans index-based generated writers"; L6 closed: "fewer #keys walks … investigated separately" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 175 | Census-9 lead 5 partial-select reads | rails-main-census-9.md:42; census-10:57 | "Measure … 1–10,000 rows; low priority" | GitHub: rails#59141 merged 11-11 | Parked: condition unchanged or no trigger; not re-measured today. |
| 176 | Census-9 lead 8 / census-10 #4 `table_name_qualified_unscope_values` | rails-main-census-9.md:45; rails-main-census-10.md:46, :316-319 | "natural to fold into A1 if kamipo takes that" — A1 merged without it (A1 note: "needs its own proof") | Re-measured on main 2e299253f9 (4.0.10): an early return saves 1 object per call, author.posts 149 -> 148, scoped association 218 -> 215, merge 104 -> 103; ~13 calls per request in the census. | Parked: about 13 objects per request, below the bar; A1 merged without it. |
| 177 | Census-10 A2 second `AliasTracker` per through load | rails-main-census-10.md:44, :271-290 | "After A1; or fold into #59569's follow-up" — A1 and #59569 both merged | Re-measured: Relation#alias_tracker costs 2.3 us interp / 0.83 us YJIT / 0.82 us ZJIT and 2 objects, 0.6-0.8% of author.comments.to_a. | Parked: below the bar; its pool lease belongs to the connection-lookup thread. |
| 178 | Census-10 C block forwarding in `type_for_attribute` | rails-main-census-10.md:45, :292-312 | "Low; mention with A1" — A1 merged | rails#59816 merged; A1 merged. | Parked: a nil &block hop costs the interpreter only; Rails doesn't take JIT-shaped changes. |
| 179 | Census-6 join-dependency alias names | rails-main-census-6.md:267 | "needs a global table of frozen names … Lead." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 180 | Census-3 `define_element` Arrays | rails-main-census-3.md:203 | "Untried." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 181 | Census-3 untried pool (ranks >300; preloader, `name.to_s`, `build_joins([])`) | rails-main-census-3.md:407, :436, :439, :444 | "Untried"; `build_joins([])` covered by #59377 (open) | GitHub: rails#59377 open 11-08 | Parked: condition unchanged or no trigger; not re-measured today. |
| 182 | FLK1 restart.txt mtime diagnostics | rails-ci-flakiness.md:189-191 | "Next step that only Rails' Buildkite can take" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 183 | Engine `commands_test.rb` hang | rails-ci-flakiness.md:193-198 | "#53215 (open) … whether it is this hang is unproven" | GitHub: rails#53215 open 06-30 | Parked: condition unchanged or no trigger; not re-measured today. |
| 184 | `MultipleFixtureConnectionsTest` sqlite3:ractor flake | rails-ci-flakiness.md:199-201 | "was not investigated" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 185 | `BroadcastLogger#method_missing` tags | rails-framework-census.md:133-137, :466-467 | "overlaps open #56650 … and #53105. Excluded." | GitHub: rails#56650 open 10-13 | Parked: condition unchanged or no trigger; not re-measured today. |
| 186 | `ActiveSupport::Ractors.[]` (AR round) | rails-framework-census.md:160-161 | "Lead for an Active Record round" (later rejected at :470) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 187 | Generated URL `path_for` copy | rails-framework-census.md:462-465; census-6:95 | "a maintainer question rather than a PR" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 188 | `CustomUrlHelper#call` `only_path` slice | rails-r7-queue.md:501; rails-common-paths.md:275 | "Lead: … not built"; encoding change for US-ASCII | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 189 | TZInfo AmbiguousTime on fall-back casts | rails-common-paths-2.md:369 | "Recorded; not filed (Thomas first)." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 190 | `Tryable#try` signature | rails-common-paths-2.md:370 | "Lead only, not built or measured on apps" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 191 | Second alias lookup in `where` | rails-common-paths-2.md:371 | "Reviewer hypothesis, not measured" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 192 | IW `index_with` on Array subclasses | rails-issue-fixes.md:17, :66 | "Lead, not opened (coordinator agreed)" (+5.3% per plain call) | Unchanged. | Parked. |
| 193 | #58499 Opera for Android | rails-issue-fixes.md:28, :221 | "Needs gshutler/useragent#74 (open) plus a Rails decision" | gshutler/useragent#74 open; gem dormant. | Parked. |
| 194 | #59168 `ractorize!` + LazyRouteSet | rails-issue-fixes.md:29, :221 | "Not built: waiting for maintainer direction" | GitHub: rails#59168 open 10-19 | Parked: condition unchanged or no trigger; not re-measured today. |
| 195 | #59153 Herb in non-main Ractor | rails-issue-fixes.md:30 | "Not built: external gem" | GitHub: marcoroth/herb#2805 open 11-06 | Parked: condition unchanged or no trigger; not re-measured today. |
| 196 | #15854 per-owner preload limits | rails-issue-fixes.md:35, :217 | "kamipo's open #58815 runs the scope per …" | GitHub: rails#58815 open 09-20 | Parked: condition unchanged or no trigger; not re-measured today. |
| 197 | #16452 clearer constant-alias error | rails-issue-fixes.md:220 | "no reactions or duplicates since 2014" | GitHub: rails#16452 open 02-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 198 | Propshaft release before 8.2 | app-suites.md:318-322 | "propshaft needs a release before Rails 8.2" | Not checked. | Parked until the 8.2 beta (compatibility). |
| 199 | PG extension array default (app-suites F1) | app-suites.md:366-378 | "Held: covered by open #57785"; branch "in case it is ever needed on its own" | GitHub: rails#57785 open 11-10 | Parked: condition unchanged or no trigger; not re-measured today. |
| 200 | DS1 clearer key-mismatch error | app-suites.md:611-614 | "the coordinator decides whether that is worth a PR" (DS1 Discourse fix is ready, #45658) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 201 | Discourse `send_query` note (CHANGELOG/guide) | app-suites.md:655-661 | "S1-style follow-up; not built" | GitHub: rails#57057 merged 06-12 | Parked: condition unchanged or no trigger; not re-measured today. |
| 202 | PI2 truncate cleanup | app-suites.md:788-797 | "recorded as a possible small exact cleanup" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 203 | "Missing host to link to!" wording | app-suites.md:970-973 | "A possible one-line follow-up; not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 204 | Prototype C UrlHelper deprecation stand-ins | app-suites.md:1121-1130 | "record only, not queued" | GitHub: rails#55410 merged 07-15 | Parked: condition unchanged or no trigger; not re-measured today. |
| 205 | `Time.zone` frozen stub note | app-suites.md:1214-1219 | "S1-style follow-up; not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 206 | rspec-rails release request (ZM2/DC3) | app-suites.md:1456; :1259 | "waits for a Rails 8.2 beta" (DECISIONS:307) | Rails 8.2 beta not out. | Parked until the 8.2 beta. |
| 207 | Arel `Fragments` grouping | where-parens-history.md:545-547 | "Worth a follow-up mention, not part of this PR" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 208 | Census-11 RQ1: framework files no longer load alone | rails-main-census-11.md:27 | "record; low" (precedent b3b2662f13) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 209 | Census-11 JB1 job `context[:job]` | rails-main-census-11.md:24 | "owned: rails#59951, #59953 … record only" | rails#59953 merged 11-27 (job kept in the execution context). | Done upstream. |
| 210 | ConnectionStub docs line | rails-82-differential.md:344 | "Lead only (doc line)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 211 | Guard-simplification TAP2748 / I18N766 trims | guard-simplification-2026-11-18.md:22-23, :173, :182 | "not built" | GitHub: Shopify/tapioca#2748 open 11-20; ruby-i18n/i18n#766 open 11-18 | Parked: condition unchanged or no trigger; not re-measured today. |

### Gems, censuses and the ledger

| # | Lead | Source | Revisit condition | Check (2026-11-27) | Decision |
| ---: | --- | --- | --- | --- | --- |
| 212 | **C2** (i18n) | gem-request-census-2.md:103; i18n-performance.md:25 | "#763–#766 have no maintainer response yet; revisit after the first one" (queue C2 note) | ruby-i18n/i18n#763-#766 open, 0 comments, last activity 11-18. | Parked: no maintainer response yet. |
| 213 | **C3** (i18n) | gem-request-census-2.md:103; i18n-performance.md:26 | same as C2: "revisit after the first one [of #763–#766 moves]" | Same as C2. | Parked: no maintainer response yet. |
| 214 | i18n `normalize_keys` cache | i18n-performance.md:278 | none stated; "public API … needs a size bound. Not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 215 | i18n interpolation double scan | i18n-performance.md:291 | none; "would change which error is raised first. Lead, not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 216 | Devise second route draw: docs | gem-request-census.md:407 | "Lead: Devise could document …" (no trigger) | Not re-measured (needs Devise apps). | Parked: a docs line saves only a boot draw; heartcombo/devise#5400 and #5716 show apps that need the draw. |
| 217 | Devise second route draw: Rails side | gem-request-census.md:407-408 | "belongs to rails/rails, not to a gem" (no trigger; rails/rails cap) | Never tried; Rails 8 loads routes lazily in development and test, so the double draw is a production eager-load boot cost. | Parked: boot-only, no exact design. |
| 218 | ViewComponent `precompute!` per-ancestor globs | gem-request-census.md:358-381; gem-side-candidates.md:241 | "Lead, not built" after VC#2769; later "main changed again in merged 2775 and `cef283f0` … no new cache layered onto it" | view_component 4.23.0-4.25.0 shipped #2769 and later rework (#2800, 11-20); not re-measured (needs the Sure app). | Parked: ceiling <= 0.7% of one app's boot; maintainers rework the file weekly. |
| 219 | ViewComponent `Requested#locale` error path | gem-side-candidates.md:242; ecosystem-tests.md:247 | "unbuilt compatibility lead … a cross-version error-formatting design/test is needed" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 220 | **UA1** (useragent) | useragent.md:241-242; outside-rails-leads.md:73 | "If gshutler answers #73, or any new commit or release lands … goes next"; rerun ips with tight A/A first | gshutler/useragent: last commit 2024-12-04, #73 open with no maintainer reply. | Parked. |
| 221 | Rails `allow_browser` decision cache | gem-request-census.md:418; gem-census.md:414 | "Lead for Rails" (no trigger; gem-side-candidates.md:245 defers useragent to it) | Never tried. | Parked: a cache keyed by a request header is the shape fatkodima declined in rails#59455 (10-30). |
| 222 | tzinfo T1: UTC period per lookup | gem-request-census-2.md:328-333 | "tzinfo has not answered #171 … Not built" (no response yet) | tzinfo/tzinfo#171 open, 0 comments. | Parked. |
| 223 | connection_pool keyword forwarding | gem-census.md:416; gem-side-candidates.md:244 | "needs its author's view first (#223)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 224 | connection_pool `Fiber#raise` leak | gem-census.md:419 | "Not yet reduced to a reproduction" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 225 | rack `clean_path_info` fast path | gem-request-census-2.md:334; gem-side-candidates.md:247 | blocked while "rack/rack#2302 and … #2458 change the same area" | rack/rack#2302 open (updated 11-20). | Parked. |
| 226 | nokogiri `extract_params` `reverse!` | gem-request-census-2.md:340; gem-side-candidates.md:249 | "too close to call. Not built" / "deferred" while our #3759 is open | sparklemotion/nokogiri#3759 open. | Parked. |
| 227 | rails-html-sanitizer `PermitScrubber#tags=` copy | gem-request-census-2.md:347 | "touches the code of three security fixes. Not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 228 | jbuilder `_blank?` | serialization-cpu.md:329; census-backlog.md:206 | "Parked behind someone else's open PR … jbuilder `_blank?` behind rails/jbuilder#622" | rails/jbuilder#622 open. | Parked. |
| 229 | http_accept_language | census-backlog.md:206; profile-hotlines-census-2026-11-26.md:94 | "behind iain/http_accept_language#80"; README: "Not suggested … dormant since 2017" | iain/http_accept_language#80 open; gem dormant since 2017. | Parked. |
| 230 | json gem `<>&` generator option (S-jsonopt) | serialization-cpu.md:332; census-backlog.md:49 | "Retain hold: … a feature requiring ruby/json maintainer interest" / "needs byroot's interest first" | GitHub: ruby/json#763 closed 08-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 231 | S-tr: Ruby 4.1 `tr!` escape path | serialization-cpu.md:327; census-backlog.md:47 | "Park: `tr!` is the Ruby 4.1 path … Unmeasured (no Ruby 4.1 build in this orb)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 232 | HWIA `merge` → `update(*other_hashes)` rest | census-backlog.md:45 | "Park: … needs a signature/forwarding contract change" | GitHub: rails#59294 merged 10-31 | Parked: condition unchanged or no trigger; not re-measured today. |
| 233 | Action Text `reverse_merge` (rank 20) | census-backlog.md:59 | "Drop for this round" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 234 | schema_context leads parked behind #59530 | census-backlog.md:206 | "Parked behind someone else's open PR … behind matthewd's #59530" | rails#59530 merged 11-09; re-measured (see schema context rows). | Closed: rails#59530. |
| 235 | `preprocess_order_args` eager matcher | census-backlog.md:206 | "behind #59413" | rails#59413 closed 11-17 by its author: Discourse overrides disallow_raw_sql!(args, permit: nil), so a new keyword breaks it; ~40 us per request. | Handed to the connection-lookup thread (the cost is resolving the pool per order()). |
| 236 | `references_eager_loaded_tables?` | census-backlog.md:206 | "behind #59377" | rails#59377 open. | Parked. |
| 237 | R1 LazyAttributeSet copies keep `@materialized` | contributions.md:1271 | "held, the idea is taken by open #59141" | rails#59141 merged; branch no longer applies. | Superseded by rails#59141. |
| 238 | `find_by_sql` typed-literal binds on PG (#58427) | census-backlog.md:219; pg-census.md:273 | "None has a rails/rails issue … issues need Thomas's OK"; our #59565 only adds a cast hint | GitHub: rails#58427 merged 08-09 | Parked: condition unchanged or no trigger; not re-measured today. |
| 239 | `render formats: [:html, :bogus]` inconsistency | census-backlog.md:224 | "Present; inconsistency, not reported" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 240 | Internal-only differences of our merged PRs | census-backlog.md:223 | "nobody has reported one. Fix recipes are in the audit" (act if reported) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 241 | Rails' own suites flakiness | census-backlog.md:227 | "Not rechecked" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 242 | R2-1 belongs_to to table without PK | ecosystem-round-2.md:99-115 | "(held) … an issue for matthewd would need Thomas's OK" | GitHub: rails#59120 merged 10-16 | Parked: condition unchanged or no trigger; not re-measured today. |
| 243 | R2-18 will_paginate SCHEMA query count | ecosystem-round-2.md:124-162 | "The fix belongs in will_paginate's spec … Not reported" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 244 | R2-2 CommandRecorder (scenic, fx) | ecosystem-round-2.md:168-172 | scenic reported; fx "read from source, not run", not reported | GitHub: scenic-views/scenic#466 open 11-04 | Parked: condition unchanged or no trigger; not re-measured today. |
| 245 | SQLite attached-DB schema readers | ecosystem-tests.md:156 | "park this real regression pending an affected production caller" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 246 | Chatwoot `Relation::Merger` splats | inertia-chatwoot-census.md:357 (and :137) | "not small; lead" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 247 | `Http::Headers#env_name` / `Sec-Fetch-Site` | inertia-chatwoot-census.md:138, :355 | "below the bar" / "Lead" | GitHub: rails#49853 merged 08-14 | Parked: condition unchanged or no trigger; not re-measured today. |
| 248 | Inertia small leads (bound-config, partial-headers, shared-keys, dotted-names) | inertia-round-2.md:53-60; inertia-chatwoot-census.md:349; contributions.md:1312 | "a lead to fold into a later resolver PR if a maintainer wants more"; "Not bundled (Thomas)" | GitHub: inertiajs/inertia-rails#449 open 11-27; rails#449 merged 05-07 | Parked: condition unchanged or no trigger; not re-measured today. |
| 249 | `Enumerable#index_by` presize | index-with-capacity.md:615 | "A Rails follow-up could presize it the same way" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 250 | `Enumerable#to_h` presize (Ruby) | index-with-capacity.md:613 | "the Set gap is a Ruby lead" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 251 | **IWC** pair-free `index_with` on Ruby 4.1 | contributions.md:1270 | "Revisit when (a) Ruby 4.1 nears release and … ruby/ruby#18345 is measured on the RC … or (b) Rails' minimum Ruby is 4.1" | Re-measured micro (12 keys): on master 0d399335b7 plain each = 1 object, 1,281 ns vs to_h 13 objects, 1,288 ns; on 4.0.10 each 1,564 ns vs to_h 1,944 ns. Ruby 4.1 has preview1 only. | Parked: the condition asks for the RC; this preliminary micro suggests plain each may work again without a version branch on 4.1. |
| 252 | **KW1** single kw splat / nil splat Hash | contributions.md:1268 | "parked, Thomas hasn't decided; mention it to Kevin rather than open a PR" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 253 | **KW2** st_table conversion at 3–8 entries | contributions.md:1269 | "parked as a design question for Kevin" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 254 | **T2** Array tag values without `safe_join` | contributions.md:1274 | "parked as a lead … narrow" (no trigger) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 255 | **B1-1** route source location dir | contributions.md:1275-1281 | "parked as a lead … Rails slots go to production hot paths first" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 256 | E2c SQLite index from own schema | contributions.md:419 | "parked as a held idea to cut maintainer noise" | GitHub: rails#59672 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 257 | PM1 QueryIntent session + mutex | contributions.md:420; pr-retrospective-2026-11-17.md:268 | "Low impact until Ruby 4.1; revisit after its release with a per-request GC measurement"; matthewd: consolidate the Ractor proxy's QueryRequest | GitHub: rails#59673 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 258 | PM3 `EventReporter::LogSubscriber` logger read | contributions.md:421 | "Too small to move a request; parked as an idea" | GitHub: rails#59674 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 259 | CB2 around-callback args | contributions.md:422; census-backlog.md:52 | "Too small to move a request; parked as an idea" | GitHub: rails#59677 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 260 | `ThroughReflection#options` via delegate | contributions.md:1343 | "One lead was parked … needs a comment (L2–L3)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 261 | `OutputBuffer.new` / `field_id` (C12) | contributions.md:1345 | "Two leads were measured and not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 262 | `SafeBuffer.new` misses `opt_new` (Ruby) | contributions.md:1347 | "recorded, no ruby/ruby PR or issue" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 263 | Census 9: `values_for_database` row rebuild | contributions.md:1364 | "Leads, none opened" | GitHub: rails#59141 merged 11-11 | Parked: condition unchanged or no trigger; not re-measured today. |
| 264 | Census 10 A1 / A2 / C | contributions.md:1374 | "Leads, none built (rails/rails at the cap)" | GitHub: rails#59825 merged 11-17 | Parked: condition unchanged or no trigger; not re-measured today. |
| 265 | **TWZ1** TimeWithZone DST double lookup | ruby-bench-dst.md:404-407; ruby-bench.md:38 | "Thomas can pick it up after the 8.2 beta; it then needs a Sol pass" | Rails 8.2 beta not out. | Parked until the 8.2 beta (Thomas). |
| 266 | GC slot-count pool budget (fallback) | contributions.md:1115; queue GC note | "reopen only if #17251 stalls or is closed" | ruby#17251 pushed 11-26, active. ruby#20110 merged 11-24. Re-run bigslot.rb: 4.0.10 2 nofree majors, master 0d399335b7 6-7 (master 9aa0898240 had 33). | Held as fallback: #17251 hasn't stalled; #20110 removed most of the regression. |
| 267 | Rails 8.1.4.1 +0.8–1.5% Ir on ruby-bench | ruby-bench-improvements.md:373 | "A lead for a later Callgrind diff, not posted" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 268 | ruby-bench: Ir in results JSON/table | ruby-bench-after-576.md:148-152 | "a design question for Max … Recommend asking him once RBCG1 is in front of him" | ruby/ruby-bench#581 (tekknolagi, 11-18, open) reports valgrind Ir per iteration. | Superseded by ruby/ruby-bench#581. |
| 269 | ruby-bench: fixed-heap note | ruby-bench-after-576.md:156-158 | "Worth mentioning to Max … if #19851's railsbench deltas turn out noisy" | GitHub: ruby#19851 open 11-12 | Parked: condition unchanged or no trigger; not re-measured today. |
| 270 | ruby-bench: JIT-flat check | ruby-bench-after-576.md:159-160 | "larger than a small follow-up" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 271 | ruby-bench: GC recording in default harness | ruby-bench-gc.md:246 | "Revisit only if the maintainers ask for GC numbers on rubybench, together with a rubybench parser fix" | GitHub: ruby/ruby-bench#562 open 11-10 | Parked: condition unchanged or no trigger; not re-measured today. |
| 272 | Callgrind GC-segment toggle | ruby-bench-gc.md:339 | "That is a follow-up, not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 273 | lobsters empty time-filtered routes | ruby-bench-improvements.md:162 | "worth raising only if a maintainer asks about lobsters' route mix" | GitHub: ruby/ruby-bench#527 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 274 | ruby-bench hold (new PRs) | pr-retrospective-2026-11-17.md:146 | "Hold: ruby-bench … seven PRs with no response" | GitHub: ruby/ruby-bench#569 open 11-18 | Parked: condition unchanged or no trigger; not re-measured today. |
| 275 | graphql-native Windows exclude | ruby-bench-improvements.md:624 | "once a graphql-c_parser release contains the fix" | ruby-bench test.yml Windows jobs have no --excludes today. | Done upstream. |
| 276 | puma reactor timeouts / response headers | puma-cpu.md:371 | "both already have concrete open work" | GitHub: puma/puma#4047 open 10-17 | Parked: condition unchanged or no trigger; not re-measured today. |
| 277 | css_parser / premailer mailer CPU | background-census.md:316; gem-side-candidates.md:243 | "defer rather than guess … Open 184 owns selector splitting" | GitHub: premailer/css_parser#184 open 03-22 | Parked: condition unchanged or no trigger; not re-measured today. |
| 278 | rgeo `to_wkt` | oss-profile-sweep-1.md:165; profile-hotlines-2026-11-25.md:43 | "Worth it only if Dawarich's track serializer matters" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 279 | concurrent-ruby `dupped_backend` | profile-hotlines-2026-11-25.md:38 | "Check first whether the callers are `keys`/`values`" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 280 | typeid `UUID#string` | profile-hotlines-2026-11-25.md:47; profile-hotlines-census-2026-11-26.md:100 | "weaker"; gem dormant since 2024-04 | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 281 | rails_vite `manifest_path` | profile-hotlines-census-2026-11-26.md:48 | README: "one app and not production: weak" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 282 | gems-on-master: bundled prism | gems-on-master.md:81 | "Watch `gems/bundled_gems` before the release" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 283 | gems-on-master: discourse_ai-tokenizers | gems-on-master.md:83 | "Once ankane/tokenizers-ruby releases a 0.7.x that builds on 4.1" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 284 | gems-on-master: Flow / temporalio | gems-on-master.md:85 | "until temporalio publishes a 4.1 build" | GitHub: temporalio/sdk-ruby#218 open 02-10; ruby#218 closed 12-02 | Parked: condition unchanged or no trigger; not re-measured today. |
| 285 | gems-on-master: cbor git overlay | gems-on-master.md:63 | "#31 open since 2026-06" | cabo/cbor-ruby#31 merged 11-05, cbor 0.6.2.2 released. | Harness follow-up for the E2 bet: move the overlay to the release. |
| 286 | gems-on-master: rinku, lago-expression | gems-on-master.md:64, :71 | open PRs | GitHub: vmg/rinku#97 open 11-25; getlago/lago-expression#91 open 11-18 | Parked: condition unchanged or no trigger; not re-measured today. |
| 287 | **ZL3** ZJIT recompile on polymorphic miss | contributions.md:1415 | "ZL3 stays held until the team answers" | See ZL3 row above. | Held (see ZL3). |
| 288 | ZJIT `SPLAT_MUT` rest (`URI.for`) | jit-parity-census.md:333, :386 | "worth an issue for the ZJIT team" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 289 | ZJIT `Kernel#send` specialization | jit-parity-census.md:379, :391 | "would need a ruby-bench headline effect to qualify" | GitHub: ruby#19583 open 11-03 | Parked: condition unchanged or no trigger; not re-measured today. |
| 290 | ZJIT read gap on blog | ruby-bench-blog-findings.md:130 | "a lead, not a finding" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 291 | ZJIT stats include boot/warmup | ruby-bench-improvements.md:183 | "a one-line follow-up if someone asks" | GitHub: ruby/ruby-bench#352 merged 12-09 | Parked: condition unchanged or no trigger; not re-measured today. |
| 292 | MutexAtomicFixnum / `@query_cache_version` | gem-request-census.md:421 | "Lead for Rails" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 293 | ruby/uri decode/encode copies (UR1) | gem-request-census.md:426; outside-rails-leads.md:18; background-census.md:308 | "ruby/uri is parked (DECISIONS)" | GitHub: ruby/uri#269 open 11-11 | Owned today by the UR1/NK2 thread (T-01a21e77-cd50); not touched. |
| 294 | NK2 nokogiri CSS→XPath cache | outside-rails-leads.md:16, :25 | "comes next once flavorjones has answered #3759 and the Ractor PRs have landed" | GitHub: sparklemotion/nokogiri#3759 open 11-18 | Owned today by the UR1/NK2 thread (T-01a21e77-cd50); not touched. |
| 295 | query-cache key behind #59518 | census-backlog.md:206 | "behind #59518" | GitHub: rails#59518 merged 11-27 | Owned today by the connection/query-cache/env_config thread (T-01a21e69); not touched. |
| 296 | Campfire Solid-stack review threads | rules-review-2026-11-18-ecosystem.md:124-131, :138 | "Thomas decides; not built" / "once Thomas decides on the trailer rewrite" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |

### Ruby, ruby-bench and bench/upstream READMEs

| # | Lead | Source | Revisit condition | Check (2026-11-27) | Decision |
| ---: | --- | --- | --- | --- | --- |
| 297 | GC (queue item, held) | ruby-master-round-2.md:26, :259-261; ruby-4.1-regression-watch.md:489-492; … | "reopened only if #17251 stalls or is closed"; regression watch: "if #17251 does not land before 4.1, `gc-pool-budget` … is still the smaller fix" | See GC row above. | Held as fallback (see GC). |
| 298 | KW2 (parked) | ruby-master-round-2.md:116 | "parked 2026-11-10, a design question for Kevin Newton" (full record in contributions.md, outside this set) | GitHub: ruby#18345 merged 08-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 299 | Hash dup of 3–8-key st_table | ruby-master-round-2.md:27, :128-129 | "Low priority: ask byroot …"; "That is an idea, not a measured patch" | GitHub: ruby#18345 merged 08-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 300 | No 320 B slot / QueryIntent ≤ 30 ivars — **owned elsewhere (memory)** | ruby-master-round-2.md:29; ruby-4.1-regression-watch.md:761-764 | "Recorded as a lead for #16282's authors … Rails could avoid it … keeping QueryIntent at 30 ivars or fewer" | GitHub: ruby#16282 merged 04-09 | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 301 | ZJIT caller splat into rest param — **owned elsewhere (ZJIT)** | ruby-4.1-regression-watch.md:766-781; ruby-master-round-2.md:30 | "Recorded as a ZJIT lead for the next JIT pass; no report or fix" | GitHub: Shopify/ruby#1095 open 11-03; ruby#18267 merged 09-02 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 302 | ZJIT unowned buckets (leads 3, 4, megamorphic, `**rest` of 14) — **owned elsewhere (ZJIT-vs-YJIT)** | ruby-master-round-2.md:390-393 (table :375-389) | "Unowned, largest first: lead 3 … protected calls (lead 4, free since our PR closed)" | GitHub: Shopify/ruby#776 open 11-14; ruby#19483 closed 11-04 | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 303 | `bundle exec ruby -rGEM` ignores the lockfile (Ruby issue) | ruby-4.1-readiness.md:155; ruby-master-round-3.md:160-164; ruby-master-rails.md:147-158 | "Next step unchanged: a ruby/ruby issue that cites Feature #19089 and the two commits, if Thomas agrees"; ticket draft "For Thomas to post … Not posted anywhere" | Not re-run today. | Parked: a new ruby/ruby issue. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 304 | mocha alias-fallback warning | ruby-master-round-3.md:109; ruby41-differential-409.md:27 | "Watch #804. It is only a warning until 4.3" | GitHub: freerange/mocha#804 open 09-22 | Parked: condition unchanged or no trigger; not re-measured today. |
| 305 | skylight alias-fallback warning | ruby-master-round-3.md:110 | "Thomas decides whether to tell skylight" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 306 | bluecloth / rbtrace in gems-on-master | ruby-master-round-3.md:90-91 | "Add bluecloth to gems-on-master as 'no fix, unmaintained'"; "Add it to gems-on-master" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 307 | Ractor `[BUG]` in actionpack/actionview | ruby-4.1-readiness.md:45; ruby-master-rails.md:76 | "Watch; re-run actionpack/actionview once #19283 merges" | ruby#19283 closed unmerged 11-13; Bug #22419 closed. | Handed to the Ruby-master differential bet: rerun actionpack/actionview on master. |
| 308 | Notifications Regexp subscriber under Ractor copy | ruby-4.1-readiness.md:44; ruby-master-rails.md:75 | "Watch." | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 309 | cbor-ruby TypedData PR (draft) | ruby-4.1-ecosystem.md:16, :158-173 | "Drafts (not posted)" — needs Thomas's OK; F1 owns tracker checks | cabo/cbor-ruby#42 closed; #31 merged and released. | Done upstream. |
| 310 | tiktoken_ruby magnus bump (draft) | ruby-4.1-ecosystem.md:17, :175-181 | "Drafts (not posted)" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 311 | lago-expression Ruby cap (draft) | ruby-4.1-ecosystem.md:18, :183-190 | "Drafts (not posted)"; maintainers "may prefer '>= 4.0.2', '< 5'" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 312 | tokenizers 0.7.1 | ruby-4.1-ecosystem.md:19 | "none; wait for 0.7.1" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 313 | Bundler 4.0.x + empty `.bundle/config` (rubygems issue draft) | ruby-4.1-ecosystem.md:14, :192-212 | Draft issue, not posted; "368fc29ce1 cherry-picks cleanly onto `4.0`" | GitHub: ruby/rubygems#9379 merged 03-10 | Parked: condition unchanged or no trigger; not re-measured today. |
| 314 | SEP1 (queue item, held) | ruby41-gem-differential.md:37, :58-86; ruby-4.1-ecosystem.md:15, :214-226; … | "SEP1 is held"; restore declined twice; "open question only on autoswitch" (eregon's question unanswered); draft reply and Redmine draft "not posted" | Reply posted 11-27 on ruby#16909; Redmine text waits for Thomas. | Held for Thomas. |
| 315 | TWZ1 (queue item, held) | ruby-bench-dst.md:19, :404-408; ruby-bench.md:38; … | "Thomas can pick it up after the 8.2 beta; it then needs a Sol pass on `ba1f364214`"; held for open-PR cap | Rails 8.2 beta not out. | Parked until the 8.2 beta. |
| 316 | rubybench GC-row hazard | ruby-bench-gc.md:120-136 | "After the next submodule bump, those two benchmarks would publish GC ms …"; "This is a coordinator decision" (not posted) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 317 | Default-harness GC recording | ruby-bench-gc.md:241-247 | "Revisit only if the maintainers ask for GC numbers on rubybench, together with a rubybench parser fix" | GitHub: ruby/ruby-bench#562 open 11-10 | Parked: condition unchanged or no trigger; not re-measured today. |
| 318 | ruby-bench#562 fix for XrXr | ruby-bench-gc.md:307-323; ruby-bench.md:67; … | "for when he returns to it"; "Thomas decides"; notes "unpostable until [fork] runs are green" | GitHub: ruby/ruby-bench#562 open 11-10 | Parked: condition unchanged or no trigger; not re-measured today. |
| 319 | ruby-bench#539 gc_balloon note | ruby-bench.md:68; bench/upstream/ruby_bench_others/README.md:20 | "Thomas decides" (draft note `pr539-note.md`) | GitHub: ruby/ruby-bench#539 open 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 320 | ruby/ruby#19685 GC-time reply | bench/upstream/zjit_root_mark_gc/README.md:1-7, :69-90; ruby-bench-gc.md:3-5 | "Reply draft (not posted)"; "the PR was not reopened" | GitHub: ruby#19685 closed 11-04 | Parked: condition unchanged or no trigger; not re-measured today. |
| 321 | Callgrind GC-segment split | ruby-bench-gc.md:337-339 | "That is a follow-up, not built" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 322 | lobsters stale fixture windows | ruby-bench-improvements.md:152-162 | "worth raising only if a maintainer asks about lobsters' route mix" | GitHub: ruby/ruby-bench#527 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 323 | ZJIT stats include boot/warmup | ruby-bench-improvements.md:164-183 | "at most, mirroring #352's boot exclusion would be a one-line follow-up if someone asks" | GitHub: ruby/ruby-bench#352 merged 12-09 | Parked: condition unchanged or no trigger; not re-measured today. |
| 324 | #425 `blank?` receiver data | ruby-bench-improvements.md:236-239 | "stays here unless he asks again" | GitHub: ruby/ruby-bench#425 open 10-29 | Parked: condition unchanged or no trigger; not re-measured today. |
| 325 | Rails 8.1.4.1 +0.8–1.5% Ir | ruby-bench-improvements.md:370-374 | "A lead for a later Callgrind diff, not posted" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 326 | Ir in ruby-bench results JSON (for Max) | ruby-bench-after-576.md:148-152; bench/upstream/pr-queue/items/RBCG1.md:18-20 | "Recommend asking him once RBCG1 is in front of him" — RBCG1 closed 2026-11-27 in favour of #581 | ruby/ruby-bench#581 open (tekknolagi). | Superseded by ruby/ruby-bench#581. |
| 327 | Fixed-heap note for Max | ruby-bench-after-576.md:156-158 | "Worth mentioning to Max with the numbers if #19851's railsbench deltas turn out noisy" | GitHub: ruby#19851 open 11-12 | Parked: condition unchanged or no trigger; not re-measured today. |
| 328 | JIT-flat check in callgrind harness | ruby-bench-after-576.md:159-160 | "larger than a small follow-up" (not built) | GitHub: ruby/ruby-bench#576 merged 11-12 | Parked: condition unchanged or no trigger; not re-measured today. |
| 329 | W1 create paths don't share main's gain | ruby-bench-blog-findings.md:29-60 | ledger "main-regressions.md W1 … candidate, no fix" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 330 | SQLite statement-cache misses on writes | ruby-bench-blog-findings.md:153 | "worth checking which statements miss the statement cache" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 331 | Turbo broadcast / Solid Queue enqueue cost — **owned elsewhere (Solid stack)** | ruby-bench-blog-findings.md:149-152, :171 | "candidates for Rails work on Turbo broadcasts and Solid Queue enqueue" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |
| 332 | ZJIT ~5% behind YJIT on blog reads — **owned elsewhere (ZJIT-vs-YJIT)** | ruby-bench-blog-findings.md:128-131 | "this is a lead, not a finding" | No upstream reference; not re-read today. | Owned today by the ZJIT-vs-YJIT thread (T-01a21e77-a32b); not touched. |
| 333 | RUBY19659 "if XrXr asks for more" (ZJIT) | ruby19659-review-2026-11-25-fable.md:61-77 | "If he asks for more … Not built" (queue item RUBY19659 is ready/open) | GitHub: ruby#19659 open 11-26; Shopify/ruby#803 open 01-29 | Parked: condition unchanged or no trigger; not re-measured today. |
| 334 | Shopify/ruby#1133 zsuper fix (ZJIT) | ruby41-differential-1.md:14-23, :282 | "#1133 counts as known until it is gone" | GitHub: Shopify/ruby#1133 open 11-25 | Parked: condition unchanged or no trigger; not re-measured today. |
| 335 | Discourse `sub!` on `Symbol#to_s` | ruby41-differential-409.md:37 | "App bug, still on Discourse main" (no fix drafted) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 336 | react-starter-kit YJIT 4.0.9 run | ruby41-differential-409.md:75 | "to rerun after the matrix" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 337 | kwsplat: `{**H, a: v}` under `shareable_constant_value` | bench/upstream/kwsplat/README.md:11-15 | listed as "Lead", kept out of ruby/ruby#19670 (closed 2026-11-10); no later record | Re-run: X = { **H, a: 1 } under shareable_constant_value: experimental_everything raises NoMethodError (core#hash_merge_ptr on 4.0.10, core#hash_merge_bang_ptr on master 0d399335b7). No Redmine or GitHub report found (searched hash_merge_ptr, shareable_constant_value). | Correctness, not reported: issue with repros/shareable_kwsplat.rb. Goes to Thomas (ruby/ruby PRs, new issues and replies need him). |
| 338 | kwsplat: prism zsuper with `**kwrest` | bench/upstream/kwsplat/README.md:8-10; ruby-master-round-2.md:31, :135 (round-1 #1 … | "Follow-up fix" out of #19670; round 2 says round-1 kwsplat shapes fixed — confirm zsuper `**` shape | Bug #22527 fixed it on master (4a3a75e6). | Done upstream. |
| 339 | Census 9 lead 8 (`table_name_qualified_unscope_values`) | bench/upstream/a1/README.md:111-115 | "it needs its own proof. Left as a held idea." | See census-9 lead 8 above. | Parked: below the bar. |
| 340 | Form-helper PR 3 (`*_tag` copies: HFT, LT, CBT) | bench/upstream/form_helper_stack/README.md:200, :206 | "PR 3 and PR 5 are parked, at −1 object per call each too weak to send" (HFT already rejected in K6) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 341 | Form-helper PR 5 (DA `data-`/`aria-` names) | bench/upstream/form_helper_stack/README.md:202, :206 | "PR 3 and PR 5 are parked" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 342 | TB (`Tags::Base#tag_builder`) | bench/upstream/form_helper_stack/README.md:178, :254, :270 | "TB and T2: parked; they are the weakest candidates" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 343 | T2 (`append_tag_option` Array join) | bench/upstream/form_helper_stack/README.md:179, :244-245, :270 | "parked lead, contributions.md"; "Build them, or keep them parked?" | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 344 | TO1 — **revived today** | bench/upstream/revive-2026-11-27/README.md:10, :87; … | "held: ZJIT `f.text_field` +0.64% unexplained, and no form-level effect" | Re-measured on main 2e299253f9 and master 0d399335b7 (ZJIT): f.text_field +0.6% (A/A 0.48%), explained by malloc/realloc growth of the tag String; other helpers -0.8% to -2.7%. | Held as a parked idea (see TO1 section). |
| 345 | FH2 — **revived today** | bench/upstream/revive-2026-11-27/README.md:11, :106 | "parked: Astra broke V and TR; the exact remainder (PH + SV) is within noise" | Parked today by the revive thread. | Parked. |
| 346 | LBL1 — **revived today** | bench/upstream/revive-2026-11-27/README.md:12, :118, :138 | "parked: boundaries rejected; the exact variant gains nothing under production Fallbacks" | Parked today by the revive thread. | Parked. |
| 347 | SP1 — **revived today** | bench/upstream/revive-2026-11-27/README.md:13, :90 | "approved" (queue item SP1 now `state: merged`) | Merged. | Done. |
| 348 | DT1 (queue item, held) | bench/upstream/lead6/realworld-2026-11-27/README.md:121-136 | "DT1 is held as a parked idea, no reviews started" (Hackatime −1.26%, CASA +0.11–0.38%) | Held today (CASA regression). | Parked. |
| 349 | CRSI1 (queue item, held) | bench/upstream/hotline_candidates/README.md:4, :98-107; … | "held, below the bar" (−0.059% of a Blog request; on main only async queries build it) | GitHub: rails#59373 merged 10-31 | Parked: condition unchanged or no trigger; not re-measured today. |
| 350 | CIR1 (queue item, held) | bench/upstream/rails_main_hotlines/names82/README.md:28 | "fix built, CIR1 held" (item: "compatibility freeze until the 8.2 beta"; no caller of reach) | rails#59950 merged 11-26; Rails 8.2 beta not out. | Parked until the 8.2 beta or a real caller. |
| 351 | hashie Duel ZJIT job | bench/upstream/hashie_duel/zjit/README.md:33-36 | "Follow-up PR, after #659 merges"; open question on renaming the YJIT check | hashie/hashie#659 merged 11-27 19:28 UTC; calibration done today (bench/upstream/hashie_duel/zjit). | Condition met today: the follow-up (second Duel job under ZJIT) is ready to build by the hashie Duel thread; open question on renaming the YJIT check stays. |
| 352 | DUEL1 (queue item, held) | bench/upstream/hashie_duel/callgrind/README.md:1-5; items/DUEL1.md note | DUEL1 note: "nothing goes upstream unless Thomas decides otherwise; if he does, an issue with the numbers first" | Held today. | Held for Thomas. |
| 353 | PM1b (queue item, held) | bench/upstream/query_request/README.md:1-5; items/PM1b.md:17-19 | "Frozen snapshot churn needs a better lifecycle before proposing it; final independent Claude Code review is pending" | GitHub: rails#59673 closed 11-05 | Parked: condition unchanged or no trigger; not re-measured today. |
| 354 | strscan / `Journey::Parser` on master | ruby-master-rails.md:147-148 | "unchanged on `5888302d4f`" (record actionpack-request-path.md, outside this set) | No upstream reference; not re-read today. | Parked: condition unchanged or no trigger; not re-measured today. |
| 355 | C2 / C3 (i18n, held; record outside this set) | bench/upstream/profile_hotlines_census/README.md:116; … | items C2/C3: "revisit after the first one" of #763–#766 gets a maintainer response | Same as C2/C3. | Parked. |
| 356 | Census field test serial overhead — **owned elsewhere (test-suite overhead)** | bench/upstream/profile_release/census-field-test/README.md:72 | "Serial overhead remeasure: not done" | No upstream reference; not re-read today. | Owned by another Bet thread (Solid stack, memory or test suites); not touched. |

## Declined for good, superseded or taken (from the same records, not reopened)

- J1 ZJIT `Kernel#send` (zjit-send.md:262-269): Stopped: tekknolagi's draft ruby/ruby#19583 is the same prototype
- Hash#size (Shopify/ruby#808) (zjit-objtostring.md:322-327): Below the bar (≈0.001% of Ir)
- `String#match?` #1059, `Time#utc?` #1060, `String#length` #808 (zjit-cfunc-paths.md:89-96): Each ≤0.05%: Onigmo dominates, the call is cheap, or it is already frameless
- `Kernel#instance_of?`, `String#+@`, `String#dup` (round 1) (zjit-gap-census.md:238-239): ≤0.02% each, below the bar (`String#dup` later became ZSD1)
- Z3 issue draft (zjit-polymorphism.md:166): Became Shopify/ruby#1099, which we closed as overlapping #995 (zjit-leads.md:138); its patterns live on as ZL3, #18616 and #19858
- 15a: attr_reader in a final version (zjit-iseq-leads.md:200, :486-489; zjit-stats-2026-11-18.md:423-425): Taken by tekknolagi's ruby/ruby#18616 (11-16 head). Revisit only if #18616 is dropped (fork `zjit-final-attr-reader-shape` @ `a0dd4a08af`).
- 15b: ivar reads on singleton objects (zjit-iseq-leads.md:215; zjit-shortlist.md:277-279): Done for reads by #19858; the send side is #1120's design question
- 14a/14b (zjit-iseq-leads.md:198): Wait for #1039 row 7 (k0kubun)
- VB1 (`&:value!` block literal in Rails) (zjit-leads.md:473-477; zjit-stats-2026-11-18.md:428): Closed Rails-side by skipkayhil ("fix it in the JITs"); answered by ZS1
- #19483 (protected sends) and its inlined-`self` follow-up (zjit-open-prs-on-rails.md:166-167; zjit-yjit-gap.md:288-289): Closed 11-04 (no `run_benchmarks.rb` move); the data now goes to #1109 and OO1
- Z9 draft for #18960 / quadratic exit size (zjit-compile-speed.md:224-225, :338-348): #18960 merged; Rails does not reach the quadratic case
- Emit / scratch_split compile hotspots (zjit-compile-speed.md:219-220): No small exact change exists
- Reply draft for #1014 (zjit-symbol-block.md:921-926): Thomas decided to open #19912 without commenting on the issue
- F1-f: Hash singleton per request (zjit-iseq-leads.md:708): Taken: iain/http_accept_language#80 and ruby/ruby#19617
- UA1 (useragent `detect` rewrite) (zjit-iseq-leads.md:365-369): Dropped: it costs YJIT 1.1% and buys ZJIT no wall time
- **R7-2 `Symbol#name` in `Hash#as_json`** (rails-r7-queue.md:33-58, :213): a +12.5% interpreter loss on Ruby 4.1; 4.1 ships Dec 2026.
- **R7-5 sanitized value in place** (rails-r7-queue.md:215): "Don't open"; gain inside the A/A.
- **R2-4 `OutputBuffer#capture(*)`** (rails-framework-census.md:472; rails-common-paths.md:273): waited on ruby#19655, which closed unmerged 11-04.
- **`IndexedRow.build_indexes` loop** (rails-82-impact.md:356-363): byroot's deliberate `to_h` choice for Ruby 4.1; recommendation "drop it".
- **`index_with` pair Arrays** (rails-main-census-4.md:290): deliberate, reverted upstream (#59203). "Not reopened."
- **`apply_inflections` memo** (rails-main-census-8.md:359-365): "Decided 2026-11-03: not pursued".
- **C8-2 `where_clause` EMPTY default** (rails-main-census-8.md:370-374): JIT loss blocks it.
- **`has_default_scope?` owner check** (rails-r6-leads.md:96-105; census-6:234): deliberate (#59234); no exact cache.
- **Relation delegator `...` lead** (rails-main-census-6.md:229): resolved by R6-1, merged as rails#59571.
- **Slimmer `define_non_cyclic_method`** (rails-boot.md:376-383): runtime loss for a boot gain.
- **QLT prepared statements with query log tags** (p-map.md:293-301): "Verdict: no change in Rails."
- **CP-4 `apply_seconds_precision` via `floor`** (rails-common-paths-2.md:368): not exact (TZInfo DST).
- **`view_assigns` without subtraction** (rails-framework-census.md:451-461): slower per render; rejected.
- **YJIT leads** (`invokeblock_symbol`, `BasicObject#!=`, `invokesuper` singleton): vm-share.md:322-329, actionview-cpu.md:735-742: "not to be built" (YJIT in maintenance mode).
- **find_by_sql options 3/4** (find-by-sql-typed-literal-binds.md:45-49): not exact / reverses a deliberate design.
- **`index_with` pair-free form via a Ruby-version branch** (IWC, contributions.md:1270): "Don't reopen in that form" (only the Ruby 4.1 conditions remain; see the `result.rb:118` row).
- **CB2** (queue note): "not to be reopened as is".
- **TE1 / V1-C2, `html_escape` without `super`** (census-backlog.md:187, :42). Real callers prepend `unwrapped_html_escape` (angular_xss, Discourse). "No exact shape keeps those prepends without the super."
- **C6-2, preloader lists in place** (census-backlog.md:185, :40). It waited on our #59564, which we closed 2026-11-10 (contributions.md:406). An ownership-safe rework leaves too little to measure.
- **Fanout subscription list, rank 2** (census-backlog.md:186, :41). "Retain rejection: `silenced?` is live subscriber behavior."
- **`Arel.sql` rest/kwrest, rank 5** (census-backlog.md:44). `Arel.sql` is public API.
- **Census 5 R23 residue, rank 12** (census-backlog.md:51). `.values` is a snapshot. Replacing it changes `structurally_compatible?`.
- **PG `sql_key` per query** (pg-census.md:264, census-backlog.md:55). Removing it means redesigning the statement cache.
- **`URL.path_for` buffer ownership, rank 9** (census-backlog.md:48). Retained or frozen buffers mean ownership can't be transferred.
- **R2-4 `OutputBuffer#capture(*)`** (census-backlog.md:238). ruby/ruby#19655 was closed, so the gain would be interpreter-only and permanent.
- **CB1, `nil.try` with `(...)`** (census-backlog.md:53). It skips keyword-splat coercion: "Do not open."
- **IW, `index_with` on Array subclasses** (contributions.md:1346). +5.3% on every Array call. "Coordinator agreed: don't open."
- **R7-2, `Symbol#name` in `as_json`** (contributions.md:1348). It is a permanent loss on Ruby 4.1. **R7-1** (contributions.md:1349): L2 with no measurable effect.
- **AT-builder behind #59141** (census-backlog.md:206). #59141 has merged, but census 9 rejected AT-1 because it skips the overridable `instantiate_instance_of` (contributions.md:1364).
- **`LazyAttributeSet#keys` behind #58002** (census-backlog.md:206). #59141 replaced the method, and K1 has merged.
- **SQLite quoted-name index regex** (ecosystem-tests.md:178). fatkodima declined it in rails/rails#55627.
- **rack cookie-key `match?`** (gem-request-census-2.md:337). It changes conversion and exceptions. **globalid `reject!`** (gem-request-census-2.md:352): too small. **Loofah `extend`** (gem-request-census-2.md:345): it is the gem's design.
- **tzinfo `Timestamp.for_time`** (gem-census.md:411). Inherent: "the Rational is the value it stores".
- **i18n `MissingTranslation` sentinel** (i18n-performance.md:286). Not exact. **`I18n.config` inlining** (:282): it would bypass overrides. **Rails `HtmlSafeTranslation` kwargs** (:295): "Rejected for now".
- **CRSI1, concurrent-ruby `SafeInitialization#new`** (profile-hotlines-census-2026-11-26.md:107). The per-request source is gone on main (#59373 / 91f0f89aeb), and the effect is far below the bar. **XNE1** has already been done on main (#59117).
- **csv `parse_quotable_loose`**, **bootsnap `storage_to_output`** (profile-hotlines-2026-11-25.md:49, census-26 README). Not leads: 1% of Huginn's jobs, and a one-time load.
- **`opt_new` Hash `capacity:` in YJIT/ZJIT** (index-with-capacity.md:608). It waited on #19662/#19663, which we closed on 11-03/11-04, so the condition can't be met. [OE]
- **YJIT `SPLAT_MUT` with leading params, and jit-parity C** (jit-parity-census.md:387, :18). YJIT has been parked since 2026-11-17, and #19666 is closed. [OE]
- **graphql #5509 introspection delegation, `default_logger` memo** (graphql-ruby.md:686-692). L3 and a behaviour change, respectively.
- **Internal-API consumers (Zammad, authlogic, Mastodon)** (contributions.md:1322). Thomas stopped it: "fixing the ecosystem for Rails 8.2 is not our job."
- **pg field-name Strings, `PG::TextDecoder::Date`** (pg-census.md:260, :262). These are app upgrade leads, not upstream work (pg 1.7.0 interns the names; a pg release with the C date decoder is still to come).
- **Already resolved and dropped from the table:** scimitar#172 / blind_index#62 (ractor-freezes.md:213; closed or merged), GQ1 (opened as graphql-ruby#5908), PHR1/RQ1/CC1/INRP1/HM1/HD1 (opened), DRV1/DRV2 (opened #769/#770), Rails `typedstore` break (fixed by byroot/activerecord-typedstore#114), rubygems#10017 (fixed by #10047).
- **F2 heap-Float `eql?`** — docs/upstream/ruby-small-hash-lookup.md:313-421: real ×2.2 on master (ruby/ruby#19410) but no heap-Float Hash key anywhere; "recorded, not built".
- **F1 small-Hash lookup** — docs/upstream/ruby-small-hash-lookup.md:3: closed in favour of byroot's ruby/ruby#19905 (merged).
- **UG82D shadowing warning** — bench/upstream/rails_main_hotlines/ug82d/shadowing/README.md:85-96: "A PR would most likely be closed. Open nothing."
- **hashie L1–L4** — bench/upstream/hashie_leads/README.md:5, :20-29: dropped (no gain, behaviour change, slower, too small); "No lead clears it; nothing is queued."
- **Candidate L lazy last default** — bench/upstream/form_helper_stack/README.md:109: needs a Proc default custom backends see; not exact.
- **PM2 blank checks in `tag_options`** — bench/upstream/form_helper_stack/README.md:242: no allocation, no exact form, "Not reopened."
- **K5 `form_tag_with_body`** — bench/upstream/k6/README.md:6-7: bypasses the public `form_tag`.
- **8.1 records in 6.1 Marshal format** — bench/upstream/l3/README.md:107-111: intended and documented (rails/rails#59249), not built.
- **XNE1 `xml_name_escape`** — bench/upstream/hotline_candidates/README.md:4-12: superseded by rails/rails#59117.
- **RK4 `split_header`** — bench/upstream/rk4/README.md:1, :39-41: superseded by rack/rack#2520 (approved); a PR would compete.
- **rails_vite `manifest_path`, http_accept_language, typeid, `helper_names`, `Arel::Table#[]`, tzinfo `for_time`** — bench/upstream/profile_hotlines_census/README.md:132-134, :145-156: one app/test-only, dormant gems, or inherent.
- **Rails Ractor R3/R4 tests** — docs/upstream/ruby-master-rails.md:86-93: design owned by maintainers (rails/rails#58736, #58974); no Rails branch. Watch only.
- **ruby-bench ranks 3–8, shipit ANALYZE, lobsters `/reply`, Rails-main variant, Callgrind harness, write workloads, ZJIT memory flags** — docs/upstream/ruby-bench-improvements.md:25-45, :455-485; docs/upstream/ruby-bench.md:48-50: "recorded, no PR".
- **Warmup issue** — docs/upstream/ruby-bench-improvements.md:422-434; docs/upstream/ruby-bench.md:46-48: "Verdict: no PR" (<1% compile share, rubybench uses 30 warmups); draft kept.
- **Significance-star issue** — docs/upstream/ruby-bench.md:44-45: not opened; superseded by RB-PV (ready).
- **GC-roots benchmark, forced-GC probe column, least-squares split, per-object normalisation** — docs/upstream/ruby-bench-gc.md:248-262: rejected.
- **Per-process hash seed spread** — docs/upstream/ruby-bench-improvements.md:790-792: property of Ruby; "Recorded, not fixed".
- **`String.new` without arguments +174 Ir** — docs/upstream/ruby41-differential-409.md:73: deliberate (`14285dee21`), "not a regression report".
- **Mocha Redmine note on Bug #22291** — docs/upstream/ruby41-differential-409.md:51-55: Thomas, 2026-11-27: "Mocha zu wenig relevant" (MO1 ready separately).
- **net-http / net-protocol** — docs/upstream/ruby-4.1-readiness.md:184; docs/upstream/ruby-master-round-3.md:165-170: ruby/net-http#362 closed; "Next step: none upstream".
- **temporalio packaging** — docs/upstream/ruby-4.1-ecosystem.md:20: fails on 4.0.7 too; not a 4.1 issue.
- **Chatwoot commonmarker 0.23.12** — docs/upstream/ruby41-differential-409-heavy.md:149-151: maintainer declined the C-branch port.
- **eventmachine 1.2.7, Active Support 8.0 json 3, pry spec order** — docs/upstream/ruby41-gem-differential.md:38-40: "record only".
- **Fizzy `uuid_primary_keys.rb` SystemStackError on Rails main** — docs/upstream/ruby41-differential-409.md:77: app × Rails-main interaction, independent of Ruby.
- **Fixed (no longer leads):** round-1 kwsplat second Hash (docs/upstream/ruby-master-round-2.md:31, drop `kwsplat-fit-merge`); graphql-native Windows exclude (docs/upstream/ruby-bench-improvements.md:689); Time.new Bug #21301 note superseded by draft ruby/ruby#20208 (TN1, docs/upstream/ruby-time-new.md:10-11).
