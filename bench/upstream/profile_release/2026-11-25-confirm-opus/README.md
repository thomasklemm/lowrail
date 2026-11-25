# lowrail-profile 0.1.0.rc1: confirm review receipts (thermos-opus, 2026-11-25)

The confirm review of thermos-sol's M5 list
([docs/upstream/profile-release-review-2026-11-25.md](../../../../docs/upstream/profile-release-review-2026-11-25.md#confirm-review-thermos-opus-2026-11-25))
reran the fixes' receipts from a gem built at lowrail main `b6109a84`. That commit's `gem/` is identical to `14579fb4`.

* Gem: `gem build lowrail-profile.gemspec` from `gem/`, sha256
  `324affa67569770b578d73d96fab7aef6ca53e4126ecefc838d227b331236f2d`, the same bytes as the builder's
  ([../2026-11-25-fixes](../2026-11-25-fixes/README.md)), 14 files. Installed with `gem install --local` into each app's Ruby.
* Apps, generated fresh in this orb: `LOWRAIL_CORPUS_RUBY=3.3.14 LOWRAIL_RAILS=7.2.4 script/corpus real-blog rc-blog-floor`
  with [../2026-11-25/blog-floor.patch](../2026-11-25/blog-floor.patch)'s three `params.expect` rewrites, and
  `LOWRAIL_CORPUS_RUBY=4.0.7 LOWRAIL_RAILS=8.1.4 script/corpus real-blog rc-blog-81`. Each was made a git repository
  (`git init`, one commit) so the scripts' tree and plant checks work.
* [scripts/rerun.sh](scripts/rerun.sh) is the builder's script, copied unchanged. [scripts/blog81.sh](scripts/blog81.sh) runs its
  part 1 (the full floor proof) on the 8.1 Blog too. Both runs add three more unchanged captures (`aa3`–`aa5`) for the A/A question.
  [scripts/aa_sim.rb](scripts/aa_sim.rb) replays compare's floor over every assignment of the unchanged captures.

## Floor proof on both ends of the support range

| Check | Ruby 3.3.14, Rails 7.2.4 ([blog-floor](blog-floor)) | Ruby 4.0.7, Rails 8.1.4 ([blog-81](blog-81)) |
| --- | --- | --- |
| Outcomes | 21 tests, 0 failures, identical in all 12 setups | 21 tests, 0 failures, identical in all 12 setups |
| Load order, captures | each process of profiled, base2, head and planted = `off-env`; seed99 loads the same set in another order; aa3–aa5 were not compared | each process of every capture = `off-env`, aa3–aa5 included; seed99 loads the same set in another order |
| Load order, plain/off | plain's cold first run had an extra process and loaded two `enc` files that plain2 and off do not, with nothing else extra or missing | off: same set, another order. An extra off run, not kept here, loaded Bundler's resolver (`pub_grub`) at boot from the Gemfile copy, which moves files after it. That run loaded no Lowrail file |
| Tree | unchanged by every capture | unchanged by every capture |
| `compare profiled head --aa base2` | exit 0; 2,017 lines, 3 actions; closest `uri/common.rb:394` +1.50 against 4.50 | exit 0; 1,804 lines, 3 actions; closest `uri/common.rb:456` +0.21 against 1.00 |
| Planted `html_escape` loop | exit 1: only `output_safety.rb:228` +1.67 against 1.0 | exit 1: `erb/util.rb:15` and `output_safety.rb:242`, each +1.67 against 1.0 |
| `--seed 99` against base | exit 2 | exit 2 |

## Exit status and write guard ([rc-blog-floor-probes](rc-blog-floor-probes), [rc-blog-81-probes](rc-blog-81-probes))

Both Blogs gave the same results:

* A failing suite exits 1, both plain and profiled (runs `1 1`).
* A suite killed with `KILL` exits 137, both plain and profiled (runs `137 137`).
* `get "/articles", env: { "REQUEST_METHOD" => "POST" }` without the flag: refused before any request ("is sent as POST"), exit 1,
  articles 3 → 3.
* The same request with `--allow-writes`: `ArticlesController#create` gets 20 windows per run and answers 422, exit 0, articles 3 → 3.
* `post articles_path` with `--allow-writes`: exit 0, articles 3 → 63.

## One A/A pair against more ([aa-sim-blog-floor.txt](aa-sim-blog-floor.txt), [aa-sim-blog-81.txt](aa-sim-blog-81.txt))

The 3.3 / 7.2 Blog has 12 unchanged captures: 3 from 2026-11-25, 3 from the fixes receipts and 6 from here. Every assignment of
distinct captures to base, A/A and head gives these rates of an unchanged head that fails:

| Strategy | Suite runs | Unchanged heads failing | Rows |
| --- | ---: | ---: | --- |
| default: base, one A/A, head | 6 | 60 of 1,320 (4.5%) | `uri/common.rb:394` 48, `set.rb:512` 12 |
| two A/A captures | 8 | 172 of 11,880 (1.4%) | `uri/common.rb:394` 148, `set.rb:512` 24 |
| default, then on failure a second head, runs pooled as head's | 6, or 8 after a failure | 49 of 11,880 (0.4%) | `uri/common.rb:394` 49 |
| default, then on failure a second head compared on its own; fail only if both exit 1 (shell only) | 6, or 8 after a failure | 48 of 11,880 (0.4%) | `uri/common.rb:394` 47, `set.rb:512` 1 |

`uri/common.rb:394` read 14.25–21.75 objects per request across the 12 captures. All three planted captures still fail on
`output_safety.rb:228` under every strategy: 132 of 132 with the default, 1,320 of 1,320 with two A/A captures and 264 of 264 with
the rerun. On the 4.0 / 8.1 Blog (6 unchanged captures) no strategy fails an unchanged head. With the default, the planted capture fails on `output_safety.rb:242` or
`erb/util.rb:15` in 30 of 30 assignments and on no other row.
Ruby 4.0's `uri` gem line (`common.rb:456`) does not swing there.
