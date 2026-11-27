# L6 real-world check, ZJIT analysis and a work-reducing alternative (DT1), 2026-11-27

Asked: is L6 (#60016, inline `index_for_name`/`lookup`) measurable outside Callgrind, does it matter in a real
request, and is there a better fix in the right layer. #60016 was closed by Thomas during this work; nothing was
pushed to it. Pins: Ruby 4.0.10 (mise, a704b7cd95) for interpreter and YJIT; Ruby master `42a644f6e0` built here
(`scripts/build-master.sh`, +ZJIT +YJIT) for ZJIT. Rails main `088fc0cf61`; L6 `8b1c6428ea`; DT1 `4e635c7ca5`
(fork branch `thomasklemm/dirty-skip-untouched`). Orb: 2 vCPU Xeon @ 2.60GHz, processes pinned with `taskset`.

## Method (wall time)

`scripts/drive2.rb` + `scripts/worker2.rb`: per round, one fresh process per (mode, columns, arm); arm order rotates
by round. Each process: shared setup (`scripts/setup_model.rb`, SQLite in memory, fixed heap floors), 1,500 warm
calls per case, one unkept window, then 10 windows of 120 calls per case, cases interleaved, `GC.start` + GC off per
window, thread CPU time. Per process the median window; per round log(arm/main); mean over 6 rounds with a seeded
bootstrap 95% CI (`scripts/an.rb`). `main2` is a second process of the same tree: the A/A. Cases: `update` (one
reused record, `update!` of one column), `find_update` (fresh `find`, then `update!`, as a request does),
`find_changed`, `serializable_hash`.

JIT gate: every YJIT/ZJIT process compiled 4 ISEQs during the windows, identical in all four arms; the YJIT log
(`yjit-log-window-compiles-main-30.log.gz`) shows they are the worker's own GC.start/disable/enable and
window block, not Rails code. ZJIT counts 3,600 side exits per process in every arm (one per measured call, harness).
So the formal JIT-flat gate fails on harness code only; read JIT rows as indicative, not as body numbers.

Run 1 (`micro-wall-run1.jsonl`, stopped after 3 rounds) measured DT1's first shape `298a1f4a13`, whose
`touched_keys` walked the names twice: `update` regressed (+7% YJIT at 30 columns). Fixed in `4e635c7ca5` (one pass).

## Results (`micro-wall2.md`, 6 rounds)

| mode | cols | case | main ns/call | A/A main2 | L6 | DT1 |
|---|---:|---|---:|---:|---:|---:|
| ZJIT | 30 | find_changed | 29,391 | −1.2% [−6.0, +5.2] | −1.6% [−9.1, +7.7] | **−18.7% [−23.7, −13.4]** |
| ZJIT | 30 | find_update | 118,473 | −1.9% [−7.9, +5.0] | −3.1% [−9.6, +3.4] | **−6.5% [−11.8, −1.7]** |
| ZJIT | 30 | update | 87,260 | −3.4% [−8.9, +2.8] | −1.4% [−8.3, +5.9] | **−6.8% [−10.3, −3.4]** |
| ZJIT | 30 | serializable_hash | 10,288 | −5.0% [−8.9, +0.1] | −5.4% [−11.6, +1.5] | −2.8% [−7.6, +2.1] |
| ZJIT | 100 | find_changed | 62,758 | −4.8% [−8.2, −1.1] | −2.0% [−7.0, +3.4] | **−33.0% [−35.8, −30.4]** |
| ZJIT | 100 | find_update | 180,420 | −4.5% [−7.7, −0.9] | −2.2% [−7.9, +3.9] | **−15.2% [−21.1, −9.2]** |
| ZJIT | 100 | update | 120,297 | −5.6% [−10.2, −0.8] | −1.5% [−8.4, +4.5] | **−11.1% [−15.3, −6.8]** |
| ZJIT | 10 | find_changed | 20,661 | −3.3% [−7.9, +0.9] | −2.4% [−8.6, +5.5] | −11.3% [−17.0, −5.2] |
| YJIT | 30 | find_changed | 36,494 | +11.6% [+3.3, +20.1] | −1.3% [−7.1, +4.9] | **−30.5% [−33.3, −27.9]** |
| YJIT | 30 | find_update | 173,760 | +6.4% [+0.6, +12.3] | −4.8% [−10.6, +0.5] | **−13.2% [−15.2, −10.9]** |
| YJIT | 30 | update | 117,576 | +7.1% [0.0, +14.6] | −4.9% [−11.2, +1.0] | −4.7% [−7.0, −2.4] |
| YJIT | 100 | find_update | 239,387 | +3.1% [−1.1, +7.6] | +2.4% [−4.2, +9.6] | **−16.8% [−21.7, −11.6]** |
| interp | 30 | find_changed | 109,373 | −2.2% [−8.7, +3.4] | −6.4% [−11.4, −1.8] | **−23.4% [−26.3, −20.3]** |
| interp | 30 | update | 324,869 | −3.4% [−7.3, +0.2] | −7.8% [−10.6, −5.3] | −2.7% [−4.4, −0.9] |
| interp | 30 | serializable_hash | 17,855 | −3.1% [−6.6, −0.3] | −11.2% [−14.2, −7.5] | −1.7% [−5.8, +1.7] |
| interp | 100 | update | 400,586 | +0.8% [−3.3, +5.6] | −8.6% [−11.3, −5.6] | −6.3% [−7.7, −4.8] |

Full table with 10 columns and every case: `micro-wall2.md`. Reading: the A/A spreads ±5–12% in places, so only
effects well outside both zero and the A/A count. **L6** is distinguishable only in the interpreter (−6 to −11%);
under YJIT and ZJIT no L6 cell is outside the A/A. **DT1** is outside the A/A for every `find_changed` cell and for
`find_update` at 30 and 100 columns in all three modes; `serializable_hash` (untouched path) does not move.

## Callgrind (`bench/upstream/dt1/body/DT1-2026-11-27`)

Ruby 4.0.10, no JIT, 30 columns: find + `update!` 2,111,005 → 1,871,399 (−11.4%), find + `changed?` 712,854 →
486,626 (−31.7%), A/A ≤ 0.06%. YJIT −13.5% / −34.2%, not JIT-flat, no claim.

## Allocations (`allocs-fix2.txt`, objects per call, Ruby 4.0.10)

| cols | case | main | L6 | DT1 |
|---:|---|---:|---:|---:|
| 10 | find + update! | 253 | 253 | 239 |
| 30 | find + update! | 300 | 300 | 246 |
| 30 | find + changed? | 90 | 90 | 59 |
| 30 | update! (reused record) | 208 | 208 | 182 |
| 100 | find + update! | 466 | 466 | 272 |
| 100 | find + changed? | 184 | 184 | 83 |

ZJIT master at 30 columns: 300 → 246 and 88 → 57.

## Real requests (Hackatime, PostgreSQL 17, census copy `censusl6rw`)

`users` has 42 columns, `heartbeats` 37. `scripts/app_time.rb` / `app_drive.sh`: 10 rounds, arms main/main2/L6
(`app-hackatime-cpu.md`, `app-hackatime-wall.md`). No L6 cell is outside the A/A under YJIT; interpreter
`PATCH display name` −4.2% CPU [−7.3, −1.5] against an A/A of [−5.6, +5.4], so not distinguishable.
stackprof (`app-profile-*.json`): samples with `LazyIndexedAttributeSet#[]` or `#keys` on the stack are 1.0% (YJIT)
and 2.0% (interpreter) of `PATCH display name`, 0–0.4% of the read requests; all `LazyIndexedAttributeSet` frames on
top 2–3% of the write, ≤1.6% of reads. Objects per request (`app-objects.md`, A/A within ±10): DT1 changes
`PATCH display name` 2,948 → 2,920 (−28, ~1%) in both modes; no other workload moves. DT1's request wall time was
not measured outside the A/A here.

## ZJIT: work or dispatch?

`zstats-update-30-main.txt` (`--zjit-stats`, update! at 30 columns): `block in keys` is the most-called JIT function
(6.5%), then `index_for_name` (3.3%) and `attribute_at` (2.8%); the dirty tracker's `changed?`/`attribute_changed?`/
`changed_from_assignment?`/`changed_in_place?`, and `transform_attributes!`, `from_database`, `forgetting_assignment`,
`Attribute#initialize` follow at 2–2.8% each: per-column work. 820k `getivar` fall back
(`no_profile_missing_ic`, 98.5%: lead 11, taken upstream by tekknolagi); inlining is rejected mostly for
`budget_exceeded` (72%) and `too_large` (27%). Side exits are negligible (6,485 in 18M sends).

Test (`zjit-inline-budget*.txt`): `--zjit-inline-budget=2000` lets ZJIT inline the helpers (inlined calls 504 →
1,200, dynamic getivar 2,284 → 400) but `zjit_insn_count` stays 25.35M and wall time is unchanged (3 rounds each, within
±3%). So under ZJIT the cost is the work (hash lookup per name, an Attribute and its checks per column), not
dispatch; a ZJIT change would not recover it. No ruby/ruby candidate from this.

Helpers, call vs body (`helpers-cost-30.txt`, ns per element at 30 names; interp / YJIT / ZJIT):
`index_for_name` 38 / 21 / 17 vs `@indexes[name]` 25 / 19 / 16; `lookup` 20 / 7 / 3.6 vs `@attributes&.[]` 6.8 / 2.3 /
1.8; `attribute_at` 41 / 28 / 29 vs inline 16 / 23 / 24. `indexes` is an `attr_reader` (0.5 ns). `row_keys` builds one
Array of the 30 name references per call, 96–127 ns, against 1.7–3.8 µs for the whole `#keys`: it is ~5% of `#keys`.
`default_attribute`'s default arguments are evaluated only when the caller omits them, on the first build of an
attribute. So the helpers have no allocation or repeated work to remove at the source; the cost is that dirty tracking
walks and builds every column, which DT1 removes.

## Where the three `#keys` calls come from (`callers-main-30.txt`)

`update!` of one column on a loaded record, 30 columns: `has_changes_to_save?` → `any_changes?` → `attr_names` (two calls), and `changed_attribute_names_to_save` (partial update)
once; `attribute_changed?` calls `#[]` once per attribute (30 + 6 + 2). `changes_applied` then maps every attribute
(`forget_attribute_assignments` → `map(&:forgetting_assignment)`, building all of them). Caching one key list across
the three calls is not exact (writes in `before_save` callbacks change it); DT1 instead shrinks each walk to the
attributes that were built or cast.

## Exactness of DT1

Active Model 1,223 runs; Active Record SQLite 10,459 runs (4 errors need the `sqlite3` CLI, also on main) and
PostgreSQL 11,391 runs; 0 failures (`tests-fix2.log`). Differential probe (`scripts/diff_probe.rb`, 68 scenarios,
`probe2-*.norm`): identical on main and DT1 after masking now-timestamps and object addresses. Boundaries a review
must attack: in-place mutation of a value read through a path that neither builds nor casts (none found: every
reader casts into `@casted_values`), `ReindexedAttributeSet` (becomes), Marshal/YAML of a set saved with unbuilt
attributes, and subclasses overriding `forget_attribute_assignments`.
