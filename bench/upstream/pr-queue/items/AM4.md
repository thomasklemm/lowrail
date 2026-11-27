---
id: AM4
repo: rails/rails
kind: fix
area: "Action Mailer test helper without Active Job"
reviewer: "byroot (#59820)"
branch: thomasklemm/mailer-test-helper-without-active-job
head: "3c0cab74afaaeaadceaf4d38a993ff4a77a0eae6"
base: main
built_on: "088fc0cf61"
introduced_by: 59820
depends_on: []
stacked_on:
alternative_of:
impact: "Since #59820 (merged 2026-11-16, unreleased) actionmailer no longer depends on activejob, but action_mailer/test_helper.rb still does require \"active_job\" and include ActiveJob::TestHelper. The Action Mailer railtie includes that helper on on_load(:action_dispatch_integration_test), so an app with actionmailer and without activejob (the setup #59820 allows) raises LoadError as soon as ActionDispatch::IntegrationTest loads, and every ActionMailer::TestCase does too. Discourse (48k stars; its Gemfile lists actionmailer, actionpack, actionview, activemodel, activerecord, activesupport and railties, not activejob) fails its whole spec suite on main with it. AM3 (#59987) fixed only the boot path."
evidence: [bench/upstream/rails_main_hotlines/am4, bench/upstream/rails_main_hotlines/slice-casa-chatwoot-discourse-flow-loomio-mastodon-sure.md]
rank: 3
risky: false
pr:
state: built
note: "2026-11-27 (Rails 8.2 pre-beta round): found by the heavy-app slice (group 3, Discourse: LoadError from action_mailer/test_helper.rb:4 via railtie.rb:67, required by rspec/rails; bisected to ed17c90871, #59820). Built on main 088fc0cf61, 2 files: test_helper.rb requires active_job with rescue LoadError, includes ActiveJob::TestHelper only if ActiveJob is defined, and capture_emails calls the block directly without it (assert_emails with a block goes through capture_emails, which performed enqueued jobs). One railties integration_test_case_test.rb test: an app without activejob in its load path (boot.rb rejects activejob/lib, loads only the AR, AC, AM and test_unit railties) runs an integration test with assert_emails; fails on main with the LoadError. No CHANGELOG entry: it completes #59820's own unreleased entry. Discourse's Gemfile permalink is at its current main 049eeeddd7. Behind the LoadError Discourse itself still adapts (spec/support/mocks.rb relies on rspec-rails loading rspec-mocks' matchers through its Active Job matchers), so its suite needs an app change too; the fix is still needed for any such app."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #59820","open PRs naming capture_emails that change actionmailer/lib/action_mailer/test_helper.rb"], hits: []}
passes: []
---

# Let the Action Mailer test helper load without Active Job

Since Action Mailer no longer depends on Active Job, an application can use Action Mailer without the `activejob` gem, but `ActionMailer::TestHelper` still requires it. The railtie includes that helper in every integration test, so such an application raises `LoadError: cannot load such file -- active_job` as soon as `ActionDispatch::IntegrationTest` loads, and every `ActionMailer::TestCase` does too. [Discourse](https://github.com/discourse/discourse/blob/049eeeddd7716b305cb34ce6140a8b9bbcbcc5d8/Gemfile#L11-L17) lists the frameworks it uses without Active Job, and its test suite fails this way on main.

This requires Active Job only when it is available and includes its test helper only then. Without it, `capture_emails`, and so `assert_emails` with a block, runs the block directly. The assertions for enqueued emails still need Active Job.
