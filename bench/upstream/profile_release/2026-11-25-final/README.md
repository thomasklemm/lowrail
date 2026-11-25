# lowrail-profile 0.1.0.rc1, last round: false alarms of compare and its CI job (2026-11-25)

After the M5 confirm reviews (thermos-opus and thermos-fable in [docs/upstream](../../../../docs/upstream)), a line's
noise floor became twice its noise, as an action's already was, and the README's CI job profiles head a second time
when compare exits 1 and fails only if that comparison exits 1 too. These receipts measure how often that gate fails
unchanged code and whether it still catches the planted regressions.

* Gem: `gem build lowrail-profile.gemspec` from `gem/` at lowrail main `737b2df3`, sha256
  `f569d5f5ebbf20902d4cdc84dc7fc5e7b895efd2b90988cd6e16898de0a86d31`. The new captures (fresh app, `planted2`) came
  from a build at `758c1d26` (sha256 `e1137d8a…`), whose profiler files are the same; only the README differs.
* [scripts/gate.rb](scripts/gate.rb) runs the gem's own `Lowrail::ProfileCompare#status` on every assignment of
  distinct captures to base, A/A and head (the default gate), and to head2 (the CI job: fail only if both exit 1). It
  does this with a line's floor as before (its noise, `rc1`) and as now (twice it). A planted head counts as caught
  when compare exits 1 with an `output_safety`/`erb/util` row, in both comparisons for the CI job.

## Results

| App, captures | Unchanged heads failing: one compare, rc1 → now | The CI job (second head), rc1 → now | Plant caught, one compare / the CI job |
| --- | --- | --- | --- |
| Blog, Ruby 3.3.14 / Rails 7.2.4: 12 unchanged, 3 planted ([gate-blog-floor.txt](gate-blog-floor.txt)) | 60 of 1,320 (4.55%) → 22 (1.67%) | 48 of 11,880 (0.40%) → 4 (0.03%) | 396 of 396 / 792 of 792 |
| Fresh app, Ruby 4.0.7 / Rails 8.1.4.1, two process workers: 24 unchanged ([gate-fresh-81.txt](gate-fresh-81.txt)) | 100 of 12,144 (0.82%) → 100 (0.82%) | 400 of 255,024 (0.16%) → 400 (0.16%) | no plant (below) |
| Campfire: 3 unchanged, 2 planted ([gate-campfire.txt](gate-campfire.txt)) | 0 of 6 → 0 | too few unchanged captures for a head2 | 12 of 12 / 12 of 12 |
| CodeTriage: 3 unchanged, 2 planted ([gate-codetriage.txt](gate-codetriage.txt)) | 0 of 6 → 0 | the same | 12 of 12 / 12 of 12 |
| Lobsters: 3 unchanged, 2 planted ([gate-lobsters.txt](gate-lobsters.txt)) | 0 of 6 → 0 | the same | 12 of 12 / 12 of 12 |

* **Blog.** The captures are the floor Blog's from the M4, fixes and thermos-opus receipts (`profiled`, `base2`,
  `head`, `aa3`–`aa5`, `planted`). The rc1 rows reproduce thermos-opus's 60 of 1,320 and 48 of 11,880 exactly. Now the
  remaining failures are `set.rb:512` (12) and `uri/common.rb:394` (10) for one compare, and `uri/common.rb:394` (4)
  for the CI job. With twice the floor, one compare also flags fewer unrelated lines next to the plant (58 → 13 of
  396).
* **Fresh app** ([fresh-81](fresh-81), [scripts/fresh_app.sh](scripts/fresh_app.sh),
  [scripts/fresh_captures.sh](scripts/fresh_captures.sh)). thermos-fable's captures were not kept (its thread is
  archived, the files were outside its workspace), so the app was rebuilt from its recipe and captured 24 times, each
  from emptied tables. Every failure is `RAILS/actionpack/lib/action_dispatch/journey/path/pattern.rb:77`. Each run
  reads it at 5.57 or 7.14 objects per request, by how the two workers split the seven requests. Five captures read
  7.14 in both runs (c11, c17, c21, c23, c24), and five read about 5.6 in both (c1, c3, c13, c14, c20). One compare
  fails exactly when head is one of the first five and base and A/A are two of the second: 5 × 4 × 5 = 100. The CI
  job fails when head2 is also one of the first five: 400. A floor multiple cannot help here: the base pair's own
  spread is 0–0.14, so its floor is `--min`. thermos-fable's 42 of 336 came from the same kind of capture, with
  another line (`inflector/methods.rb:76`). No plant: `/widgets` is requested once per worker process, so a plant
  there has no warm value; plants are checked on the four corpus apps.
* **Campfire, CodeTriage, Lobsters.** Unchanged and `planted` are the M4 captures; `planted2` ([scripts/planted2.sh](scripts/planted2.sh))
  is a second planted capture with the M4 plant, command and proof.sh, so the CI job has a planted head2. No
  unrelated line was flagged next to a plant.

## Floor Blog from the final gem ([blog-floor](blog-floor), [scripts/floor.sh](scripts/floor.sh))

| Check | Result |
| --- | --- |
| Outcomes | 21 tests, identical in plain, plain2, off, off-env and every capture (`outcomes.txt`): 0 failures |
| Load order | plain = plain2 = off; every capture process = `off-env`, `planted` included (`features.txt`); `seed99` loads the same set in another order |
| Tree | unchanged by every capture (`summary.txt`) |
| A/A `compare profiled head --aa base2` | exit 0; closest row `CommentsController#create` +21.00 against 22.00 (`margin.txt`) |
| Planted `html_escape` loop | exit 1, only `output_safety.rb:228` +1.67 against 1.0 |
| `--seed 99` against base | exit 2 |
