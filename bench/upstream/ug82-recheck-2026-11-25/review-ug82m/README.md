# UG82M review — approve

Reviewed on 2026-11-25 in Lowrail at `156cbbdadc142a8d43ce69996ab1274bacf8ff75`.
Loaded `thermos`, `thermo-nuclear-review`, and `thermo-nuclear-code-quality-review`.
Applied both rubrics directly in the requesting thread, without subagents or other
threads, as requested. This is one reviewer's application of both rubrics, not two
independent reviewers.

- Fork branch: `thomasklemm/upgrade-guide-mailer-active-job-railtie` in `thomasklemm/rails`.
- Reviewed head: `de4d27b257337464438695d3d6600af13bdf0482`.
- Reviewed rails/rails main: `f785381cca8621772cba659ff93f825eb7f99942`.
- Stable control: released Rails 8.1.4.1; tag commit `3f290b759c8e2ffe7c257951b1255740751355e4`.
- Reviewed body: the paragraph below the title in `bench/upstream/pr-queue/items/UG82M.md`
  at the Lowrail commit above, including the money-rails sentence. Its exact text is
  also captured in `source-audit.txt`.

Read Lowrail's `AGENTS.md`, `docs/PLAN.md`, and the requested Pull requests,
PR descriptions, Review gates, and Claims are checked sections of `docs/DECISIONS.md`.

## Verdict and smallest fixes

**Approve. No correctness/security or maintainability findings. No fixes required
in the guide, commit message, or current PR body.**

**Guide decision: no change.** The section already identifies the missing
`config.active_job` configuration and tells applications with the affected
explicit framework list to require the Active Job railtie. That instruction is
not conditional on the app itself setting an adapter or calling `deliver_later`.
It also fixes gems configuring Active Job. The new money-rails example supplies a
concrete affected caller in the PR body; adding a gem-specific example or another
warning to this small migration section is not needed to make its instructions
correct. The exception is raised by the same missing configuration, at a different
loading boundary, not by a separate migration requirement.

The guide's default-adapter description is about the ordinary, otherwise
unconfigured delivery path. Direct `ActiveJob::Base.queue_adapter = :inline`
continues to work, and production defaults are Async on both versions. The guide
does not claim configured adapters are silently ignored. Its configuration error
and enqueue statements describe distinct paths, not successful enqueue after a
configuration error.

## Sentence audit

Line numbers below refer to `guides/source/upgrading_ruby_on_rails.md` at the
reviewed head. `source-audit.txt` records the diff, commit message, versioned source,
release tag, and the exact PR body.

| Text | Evidence and assessment |
| --- | --- |
| Guide heading, line 150: “Action Mailer no longer loads Active Job” | The first sentence immediately specifies the railtie dependency. 8.1.4.1 requires `active_job/railtie` at line 4 of the mailer railtie; main does not. Appropriate concise heading, not a promise that no mailer operation can ever load Active Job. |
| Guide sentence 1, line 152: `require "action_mailer/railtie"` used to load the Active Job railtie too. | Confirmed from both versioned railtie files and the runtime `active_job_railtie` result. |
| Guide sentence 2, lines 152–156: explicit framework lists without the Job railtie lose `config.active_job`; configuring it raises at boot, while default `deliver_later` uses Active Job's default adapter. | `probe.rb configured` succeeds with Inline on 8.1.4.1, raises `NoMethodError` during configuration on main. `plain` in test changes TestAdapter to AsyncAdapter. The production controls both enqueue through AsyncAdapter. The separate direct-configuration control delivers through Inline on both. |
| Guide sentence 3 and snippet, lines 156–162: require the Active Job railtie explicitly, before the mailer railtie. | `explicit` restores `config.active_job`, TestAdapter, and successful enqueue on main. Both money-rails explicit-require controls boot and enqueue with `serializer_registered=true`, including eager loading. The same require list also works on 8.1.4.1. |
| Guide final sentence, line 164: applications requiring `rails/all` are unaffected. | Both versions of `rails/all.rb` explicitly require `active_job/railtie`; `probe.rb all` boots, exposes the configuration, and enqueues through TestAdapter on both trees. |
| Commit subject: “Note in the upgrade guide that Action Mailer no longer loads Active Job” | The entire one-commit diff adds exactly the described guide section, under “Upgrading from Rails 8.1 to Rails 8.2”. There is no additional message body or trailer. Author and committer are Thomas Klemm. |
| Body sentence 1: explicit Mailer-without-Job framework lists got the Job railtie through the Mailer railtie until #59820. | Stable source contains the require. The introducing merge `ed17c90871d2c65acc201c082c1f6f924d6d55f9` removes it. Main still lacks it. This is deliberate upstream decoupling; the candidate documents it rather than reversing it. |
| Body sentence 2: on main setting `config.active_job.queue_adapter` raises `NoMethodError` on boot. | Both the supplied `mailer_job.rb config` and the independent `configured` control reproduce the error. The latter reports `phase=configuration`, before `initialize!`, as part of evaluating the application's boot configuration. Stable configures and actually delivers via Inline in the independent control. |
| Body sentence 3: gems configuring Active Job when it loads can fail the same way; money-rails 3.0.0 makes this explicit-railtie app fail at boot with eager loading. | Opened the actual line permalink. The peeled `v3.0.0` tag equals its SHA, and the installed gem's hook is byte-identical to the linked source. Hook line 42 reads `Rails.application.config.active_job`; lines 43–44 configure its serializers. The main eager control fails at `phase=initialize!` at that line. The lazy control fails at `phase=mailer_class_load`, not after successful enqueue. Stable controls succeed and register the serializer. The same config access remains on money-rails main `d577b19084a27340ceca3a809940f49e151d50cd`, line 44. RubyGems reports 3.0.0 as latest. |
| Body sentence 4: the change adds an 8.1-to-8.2 upgrade section telling users to require the Job railtie explicitly. | Confirmed against the exact head diff and surrounding heading. |

The body is focused on the concrete boot failure and the migration, without test
counts, performance claims, internal review history, or the previous inaccurate
configured-adapter/CHANGELOG claims. No unnecessary code comments were added.

## Commands and decisive results

Full command/source output is in `source-audit.txt`; runtime output in
`supplied-repros.txt` and `controls.txt`; tool and resolved gem versions, plus both
Gemfile recipes, in `environment.txt`; syntax/lint checks in `checks.txt`.

- `git -C .corpus/rails rev-parse origin/main refs/remotes/ug82-review/head v8.1.4.1^{}`
  produced the three full reviewed SHAs above. `git ls-remote` independently
  confirmed the current fork head and canonical Rails main.
- `git -C .corpus/rails show --format=fuller --stat de4d27b257337464438695d3d6600af13bdf0482`
  showed one guide file, 16 insertions, and only the subject quoted above.
- `git -C .corpus/rails merge-tree --write-tree f785381cca de4d27b257`
  produced tree `c908208a1342ccb310b560bcc5e022073af90b43`, exit 0, no conflicts.
- `git -C .corpus/rails diff --check de4d27b257^ de4d27b257`: exit 0.
- In a fresh Ruby process for each row, using each tree's bundle:
  `bundle exec ruby bench/upstream/ug82-recheck-2026-11-25/mailer_job.rb config`,
  the same with `plain`, and the supplied `mailer_money.rb` and
  `mailer_money_eager.rb`. The supplied scripts reproduce their recorded results.
  Their exit status is not a pass/fail oracle: some rescue expected errors and
  exit 0; stable's configured example attempts real SMTP and reports connection
  refused. The independent controls use `delivery_method=:test` instead.
- `RAILS_ENV=test BUNDLE_GEMFILE=<stable-or-main.Gemfile> bundle exec ruby bench/upstream/ug82-recheck-2026-11-25/review-ug82m/probe.rb <mode>`
  for each of `plain`, `configured`, `direct`, `explicit`, `all`, `money_lazy`,
  `money_eager`, `money_lazy_explicit`, `money_eager_explicit`; also `plain` with
  `RAILS_ENV=production`. Twenty fresh-process control scenarios in total.
  Main has exactly three expected failures: configured (`configuration`),
  money_lazy (`mailer_class_load`), money_eager (`initialize!`). Stable has none.
  All successful rows report `enqueue=true`; Inline/Async actually deliver one
  test email, whereas TestAdapter leaves zero deliveries. Both fixed money rows
  also report `serializer_registered=true`.
- Opened `https://github.com/RubyMoney/money-rails/blob/f5e2af72988a684ed88904ddc7f39974cc7d23ee/lib/money-rails/hooks.rb#L42`;
  fetched both that raw source and money-rails main's hook; checked release tags
  with `git ls-remote`; queried `https://rubygems.org/api/v1/versions/money-rails/latest.json`
  → `{"version":"3.0.0"}`. `cmp` of the released source with the installed gem:
  exit 0.
- `mdl --config <rails-main>/.mdlrc <exact-head-guide.md>` with mdl 0.18.1: exit 0.
- `ruby -c bench/upstream/ug82-recheck-2026-11-25/review-ug82m/probe.rb`: `Syntax OK`.

## Maintainability and limitations

Readability L0: the note belongs in the existing upgrade guide, stays within the
8.2 section, gives one diagnosis and one explicit require list, and adds no runtime
logic, abstraction, dependency, or feature gate. The guide was already well over
1,000 lines; this does not cross that threshold or justify splitting the historical
upgrade guide. Metrics for executable methods are inapplicable to the doc-only diff.

No Rails branch, PR, or queue-item file was changed. Only this Lowrail evidence
directory was added. Runtime claims were checked on main and released 8.1.4.1;
Markdown lint used the exact candidate guide. The Rails component suites and Guides
HTML build were not rerun, and this review makes no whole-suite or app-prevalence
claim. The original on-load failure is upstream behavior, not introduced by the
documentation candidate.
