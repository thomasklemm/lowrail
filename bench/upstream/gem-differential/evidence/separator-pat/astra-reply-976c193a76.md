# SEP1: Astra review of the reply draft

Reviewed `reply-16909.md` at Lowrail `976c193a7624cc0b42e46171e0f4935beff0bc68`,
2026-11-27, personally in `T-01a21d5c-3bca-76ba-9b8d-c6960f5eabf9`.
**Verdict: changes.** The demonstrated behavior is correct. One etiquette fix is required.
The restore PR and Redmine plans remain dropped; nothing was posted upstream.

## Required wording change

Replace:

> @nobu, is turning off the autoswitch still planned for 4.1?

with:

> Is turning off the autoswitch still planned for Ruby 4.1?

DECISIONS forbids pings on PRs/issues. Removing the mention answers the live
discussion without directing a notification at a maintainer. Naming Ruby also
distinguishes its forthcoming 4.1 from Bundler 4.1, already released. The question
does not ask to restore the constant or reopen that decision. Thomas still decides
whether the reply should be posted. This review does not authorize posting.

## Independent execution

Built Ruby master `80343e1cf52997cbfcb0a279ee5c330cd630d029` with
`script/ruby-differential build`, rather than relying on the coordinator's run.
It ships Bundler 4.1.1. Created a nonempty `gemspec` fixture and generated its
lockfile with **actual Bundler 4.0.11** on the previously independently built
Ruby 4.0.10 (`a704b7cd95a42cc0cf5f307137bf3aac0285b915`); did not merely edit
`BUNDLED WITH`. Every case had an isolated gem home and no existing Bundler config.

Twenty fresh cases cover the launcher, whether 4.0.11 is initially installed,
normal/frozen mode, and `BUNDLE_VERSION=system` controls. Results below hold in
both normal mode and `BUNDLE_FROZEN=true`:

| Command | 4.0.11 initially absent | 4.0.11 initially installed |
| --- | --- | --- |
| `bundle install` | Announces 4.1.1 → 4.0.11, installs it, raises `SEPARATOR_PAT` NameError | Uses 4.0.11 directly, raises the same NameError, no installation announcement |
| `gem exec -g bundler bundle install` | Announces and installs 4.0.11, then errors with `Please specify at least one gem name` | Uses 4.0.11 and raises the separator NameError |
| `gem exec -g bundler -v 4.1.1 bundle install` | Announces and installs 4.0.11, then errors with `Please specify at least one gem name` | Restarts and gives the gem-name error, without an installation announcement |

All these failures exit 1 and leave the lockfile unchanged. The distinct
`gem exec` error is not evidence that autoswitching is disabled: its fresh log
explicitly announces the switch and installs 4.0.11. Source reading explains the
difference: `ExecCommand#load!` changes `$0` to `bundle`, but `SelfManager#restart_with`
falls back to `Process.argv0` when that is not an existing file, restarting the
`gem` executable with `install` as its remaining argument.

`BUNDLE_VERSION=system bundle install` succeeds with 4.1.1, with 4.0.11 both
installed and absent. The two `gem exec` forms also succeed with this setting
in fresh absent-4.0.11 controls. Normal-mode success updates `BUNDLED WITH` to
4.1.1; frozen-mode success preserves the original lockfile byte for byte. These
controls confirm configuration can disable switching; they do not change the default.

## Search and source checks

Fetched the permalink in the draft. Line 91 is exactly
`"BUNDLE_VERSION" => "lockfile",` and the fetched file matches the independently
built Ruby source. RubyGems master `fc37d0f953ddf1bae50d11670cd48eee2a588679`
(Bundler 4.2.0.dev) and release branch `4.1` at
`4f8f9553dcfcf6fbba05a9aff75e459c8ed6996e` both retain that default and the
switching code. The inspected CHANGELOG contains no default-disable entry.

Searched open RubyGems issues/PRs for autoswitch, auto-switch, BUNDLED WITH,
BUNDLE_VERSION, and switch/Bundler; read the relevant merge-proposal discussion.
There **is a proposal**, not an absence of plans:
[hsbt's June 19 plan](https://github.com/ruby/rubygems/issues/9236#issuecomment-4748470107)
leaves phases 4+ open, proposes warnings in late 4.x, then a 5.x cutoff or wrapper.
[Colby's June 22 reply](https://github.com/ruby/rubygems/issues/9236#issuecomment-4766435253)
approves phases 1–3 and calls for review before phase 4. Neither establishes a
Ruby/Bundler 4.1 deadline. Search absence does not prove no other plan exists.

Read the live closed restoration PR and its comments, including nobu's November 6
refusal and eregon's unanswered request for the autoswitch link. No renewed restore
request is warranted by this review. The draft supplies current execution evidence
relevant to that question; it does not claim to have disproved all future plans.

Currency: ruby/ruby was active, not archived, 23,870 stars, last push
2026-11-27T14:40:19Z; ruby/rubygems active, not archived, 3,997 stars, last push
2026-11-27T11:38:57Z. Rubygems.org reported Bundler 4.1.1 released November 25,
4,003,853,703 total downloads and 428,408 for that release at lookup. The draft
names only the runtime and its relevant package manager; no niche caller list.

## Sentence audit and evidence

* Internal preamble: correctly identifies the reply target and question. It is
  outside the `---`-delimited upstream body and must not be posted with it.
* First sentence: independently reproduced on the named master. Read with the
  last sentence's default qualification, it does not promise switching under
  `BUNDLE_VERSION=system`.
* Lockfile/gemspec example and both quoted output lines: reproduced verbatim by
  `bundle install`; output is an excerpt, not the complete error report. This
  example has a nonempty file list, not a claim about all possible gemspecs.
* Default/permalink sentence: fetched and checked against built source.
* Final question: factual uncertainty is appropriate; remove the forbidden ping.
* No internal IDs, measurements, reviewers, Lowrail links or process appear in
  the upstream body. No restoration request, argument, filler or extra headings.

Raw data: `astra-reply-976c193a76.tar.gz` beside this report. It contains
`probe.py`, `validate.py`, `fixture/`, the reviewed draft, source snapshots,
search responses and `logs/`. Decisive files:

* `logs/build-reply-master.log`, `logs/build-driver.log`, `logs/fixture.log`.
* `logs/bundle-False-False-False.log`, `logs/bundle-False-True-False.log`.
* `logs/gemexec-False-False-False.log`, `logs/gemexec-True-False-False.log`.
* `logs/gemexec-pinned-True-False-False.log`.
* `logs/results.jsonl`, `logs/gemexec-controls.jsonl`, `logs/validation.txt`.
* `logs/settings-permalink.rb`, `logs/release-4.1-settings.rb`, both CHANGELOGs,
  `logs/rubygems-pins.txt`, `search/comments-9236.json`, `logs/pr16909-comments.json`.

No runtime code changed. The full earlier Redmine/patch matrix remains in
`astra-2026-11-27.tar.gz`; this pass covers only the new reply draft.
