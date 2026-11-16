---
id: BX1
repo: ruby/ruby
kind: fix
area: gem_prelude.rb, bundle exec
reviewer: "hsbt (author of c3c0e280d0, cadf8e7933 and #18400)"
branch: thomasklemm/bundle-exec-dash-r
head: "339a9d6d51"
base: master
built_on: "4c5c1a9f2c"
depends_on: []
stacked_on:
alternative_of:
impact: "Ruby 4.1 regression: `bundle exec ruby -rGEM` activates the newest installed GEM instead of the locked one (Gem::LoadError when an older version is locked); the fix restores 4.0's order and keeps Bug #22123's box fix"
rank: 1
risky: false
state: built
pr:
note: "Thomas, 2026-11-16: open as a PR restoring 4.0 behaviour (variant A); #18218 read as an optimization whose behaviour change slipped through; the narrower RUBYOPT-only variant (B) is the fallback if hsbt wants to keep #18218's cleared-RUBYOPT child behaviour. Body: we -> I, rubygems follow-up promise cut (fix the lib/rubygems.rb note separately after merge). DECISIONS exception of 2026-11-16 (a PR with the repro instead of a Redmine issue). Built and tested on the M3 (release build, docs/upstream/ruby-master-round-3.md). Fail without the fix, pass with it: test_box.rb test_bundler_setup_loaded_only_in_main_box_while_decorator_gems_are_autoloaded (renamed from ..._not_loaded_while_..., which asserted the regression) and the reverted `bundle exec ruby -r./stub -ropenssl` example in spec/bundled_gems_spec.rb. No lockfile example in that spec: it is about bundled_gems.rb's warnings, and spec/bundler/commands/exec_spec.rb is synced from ruby/rubygems. Follow-up for ruby/rubygems: lib/rubygems.rb's note that the BUNDLER_SETUP require can go once 4.1 is the oldest supported Ruby. Reverses one behaviour #18218 named on purpose: a child that clears RUBYOPT but keeps BUNDLER_SETUP is bundled again, as on 4.0.9."
passes:
  - {reviewer: claude-code, orb: T-01a1e3b3-a0ec-763a-a2d1-71b56ea7b5cc, head: "339a9d6d51", date: 2026-11-16, verdict: nits, open: "No must-fix. Own release builds of 4c5c1a9f2c and 339a9d6d51 on the M3 (YJIT; openssl@3 through PKG_CONFIG_PATH, because pkg-config now resolves openssl@4 4.1.0, which master's ext/openssl does not build against). Tests: the renamed test_box test fails on base ([] instead of ['true']) and passes on the fix; base's old test fails on the fix build; the reverted bundled_gems_spec example fails on base and passes on the fix (20/20), and is an exact revert of 2b0dfbe690; all of test_box.rb (90 tests) is green on both. With the kept box condition removed, both BUNDLER_SETUP box tests fail, so it is load-bearing and covered. Body repro verbatim: 4.0.9 prints 3.0.0, base raises the quoted Gem::LoadError, the fix prints 3.0.0. Bug #22123: the RUBY_BOX=1 path-gem repro passes; a tracing BUNDLER_SETUP shows it runs once, in the main box, and not again for 3x Ruby::Box.new (0.21 s against 1.99 s on 4.0.9). RUBY_BOX=1 bundle exec ruby -rrainbow raises LoadError on base (the Bug #22295 path, which stays without Bundler) and prints 3.0.0 with the fix. Decorators: the autoload entries are unchanged (ErrorHighlight and SyntaxSuggest stay autoloaded); under bundle exec, Bundler's vendored Thor loads did_you_mean on base and fix alike. Edge cases where the fix equals 4.0.9: bundle exec without a Gemfile (Could not locate Gemfile, exit 10), BUNDLER_SETUP without RUBYOPT (bundled, locked version), ruby -rbundler/setup -rGEM (3.0.0 on all three), --disable-gems (no Gem, BUNDLER_SETUP ignored; bundle exec ruby --disable-gems unchanged), a missing locked gem and a raising Gemfile (same errors), and a child that clears RUBYOPT (bundled again). Startup: the child ruby -e1 in a bundle exec env takes 59.8 ms on base and 59.5 ms on the fix (median of 80 interleaved runs), with 155 loaded features on both and bundler/setup loaded once. Worth a reply if asked: test_yjit's and test_zjit_cli's prelude_kernel_prepend tests are vacuous on base (BUNDLER_SETUP deleted) and exercise the prelude again with the fix. Text: every body sentence holds against the code and the repro; the commit message is accurate, and its unbracketed Bug and Feature references do not link the commit to those Redmine tickets. Nits: (1) the body has 166 words without the code block (DECISIONS: about 150); cutting 'first' and ', whose -ropenssl warning had stopped for the same reason' brings it to 156; (2) 'clears RUBYOPT' could be 'clears or replaces RUBYOPT', as #18218 put it; both cases are the same mechanism; (3) the commit message leaves out the child-process change that the body names; one sentence would help a git log reader; (4) the renamed test no longer checks that the decorators are autoloaded in its process; one assert would keep its name true; (5) after the merge, the note in lib/rubygems.rb (8268411788) is wrong and tells ruby/rubygems to drop the require this fix relies on, so open that follow-up soon after the merge."}
---

# Set up Bundler before command-line -r libraries again

On Ruby master, `bundle exec ruby -rGEM` no longer uses the locked version of GEM, which showed up in nokogiri's test suite. With rainbow 3.1.1 installed and 3.0.0 locked:

```sh
printf 'source "https://rubygems.org"\ngem "rainbow", "3.0.0"\n' > Gemfile
BUNDLE_PATH=vendor bundle install
BUNDLE_PATH=vendor bundle exec ruby -rrainbow -e 'puts Gem.loaded_specs["rainbow"].version'
```

Ruby 4.0.9 prints `3.0.0`. Master raises `Gem::LoadError: You have already activated rainbow 3.1.1, but your Gemfile requires rainbow 3.0.0.`

RubyGems sets Bundler up from `BUNDLER_SETUP` while it loads, which is before the command line's `-r` libraries. Since c3c0e280d0 (#18218, Bug #22123), gem_prelude.rb removes that variable first whenever error_highlight, did_you_mean and syntax_suggest are autoloaded, as they are by default since cadf8e7933 (Feature #21951). Bundler is then set up only by `-rbundler/setup` in `RUBYOPT`, which runs after `-rrainbow`.

Bug #22123 needs the skip only outside the main box, so this keeps that condition alone and reverts the spec change in #18400, whose `-ropenssl` warning had stopped for the same reason. The decorator gems stay autoloaded, and new boxes still don't set Bundler up again. As on 4.0, a child process that clears `RUBYOPT` but keeps `BUNDLER_SETUP` is bundled again.
