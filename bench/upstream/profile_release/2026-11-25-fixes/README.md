# lowrail-profile 0.1.0.rc1 after the M5 fixes: the receipts they touch (2026-11-25)

The M5 review fixes (exit status, the `--workloads` write and production guards, paths with spaces, compare's
coverage check, `--record` on ambiguous routes, compare floor tests, docs) changed the CLI, the workloads runner
and compare. These receipts rerun what that touches, from the rebuilt gem, as a stranger installs it:

* Gem: `gem build lowrail-profile.gemspec` from `gem/` at lowrail main `7b45ced2` (the gem's files are the same at
  `6dafad14`, where it was built), sha256 `324affa67569770b578d73d96fab7aef6ca53e4126ecefc838d227b331236f2d`,
  installed with `gem install --local` into each app's Ruby (`*/installed-from.txt`, `*-probes/results.txt`).
* [scripts/rerun.sh](scripts/rerun.sh), with the 2026-11-25 scripts
  ([../2026-11-25/scripts](../2026-11-25/scripts)) and method ([../2026-11-25/README.md](../2026-11-25/README.md)).
* Apps: the floor Blog (`.corpus/rc-blog-floor`, Ruby 3.3.14, Rails 7.2.4) of 2026-11-25, and a generated Blog on
  Ruby 4.0.7, Rails 8.1.4 (`script/corpus real-blog`, the same generator output on 8.1).

## Floor Blog, the full proof again ([blog-floor](blog-floor))

| Check | Result |
| --- | --- |
| Outcomes | 21 tests, identical in plain, plain2, off, off-env and every capture (`outcomes.txt`): 0 failures |
| Load order | plain = plain2 = off; every capture process = `off-env` (`features.txt`). `seed99` loads the same set in another order, as a different seed does |
| Tree | unchanged by every capture (`summary.txt`, `tree-*.txt`) |
| A/A `compare profiled head --aa base2` | exit 0; 2,017 lines, 3 actions compared; closest row `uri/common.rb:394` −1.25 against 1.25 (`margin.txt`) |
| Planted `html_escape` loop | exit 1: `output_safety.rb:228` +1.67 against 1.0, as on 2026-11-25, and `uri/common.rb:394` +3.88 against 1.0 |
| `--seed 99` against base | exit 2 (another seed is another capture) |

The second planted row is noise past a narrow floor, not the plant: `uri/common.rb:394` read 15.75–18.25 objects per
request across the five unchanged captures here and 14.25–21.75 on 2026-11-25, and this A/A pair happened to sit at
16.75–17.75, so its floor was the 1.0 minimum. The README says one A/A pair is a sample, not a bound.

## Exit status and the write guard, on both ends of the support range ([rc-blog-floor-probes](rc-blog-floor-probes), [rc-blog-81-probes](rc-blog-81-probes))

| | Ruby 3.3.14, Rails 7.2.4 | Ruby 4.0.7, Rails 8.1.4 |
| --- | --- | --- |
| Suite with a failing test (`assert_equal 1, 2`): plain, profiled | exit 1, exit 1 (both runs 1) | exit 1, exit 1 (both runs 1) |
| Suite killed by a test (`Process.kill("KILL", Process.pid)`): plain, profiled | exit 137, exit 137 (both runs 137) | exit 137, exit 137 (both runs 137) |
| `get "/articles", env: { "REQUEST_METHOD" => "POST" }`, no flag | refused before any request ("is sent as POST"), exit 1, articles 63 → 63 | the same |
| The same with `--allow-writes` | sent as a POST: `ArticlesController#create` 20 counted windows per run, answered 422 (a GET sends no CSRF token), exit 0, 63 → 63 | the same |
| `post articles_path` with `--allow-writes` (control: writes are counted) | exit 0, 63 → 123 (10 warmup + 20 counted, two runs) | the same |

The killed suite uses `KILL` because Rails' test runner turns a `TERM` into exit 1 itself; the gem's own test
covers `TERM` (143). Before the fixes the reviews found a profiled failing suite (runs `[1, 1]`, `[7, 7]`) and a
`TERM`-killed one exiting 0, and the `env:` probe writing 60 times without the flag
([docs/upstream](../../../../docs/upstream), the two `profile-release-*review-2026-11-25.md`). Articles are counted in
each Blog's development database with `bin/rails runner`.
