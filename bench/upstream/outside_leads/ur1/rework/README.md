# UR1 rework: shared decoder helper (ruby/uri d09ffb7, 2026-11-27)

Candidate d09ffb7376 (tree fc6c87085a) on ruby/uri master 48cda77031, fork branch
`thomasklemm/decode-uri-component-cgi-review` until it replaces the PR branch.

`_decode_uri_component(str, enc)` keeps the lone-% check, the `str.b` copy and `force_encoding(enc)`, and yields the
BINARY copy to a block. `decode_www_form_component` passes `CGI.unescape(bytes, BINARY)`. `decode_uri_component`
passes `CGI.unescapeURIComponent(bytes, BINARY)` when cgi/escape defines it natively (C since cgi 0.3.3 / Ruby
3.1.3, Java since 0.4.1; checked once at load: `respond_to?` and no `source_location`), else the old `gsub`.
Path taken (checked via source_location): 4.0.10, 3.4.12, master, JRuby 10.1 CGI; 2.5.9, 3.1.2, TruffleRuby 40,
JRuby 9.4.16 gsub. TruffleRuby's Ruby `unescapeURIComponent` keeps a String subclass (its `String#b` does), so the
native check also keeps the result class there.

`decode_www_form` is unchanged: it must keep a lone `%`, and on plain keys and values its `gsub!` allocates nothing
while CGI.unescape returns a new String (orb probe, 4.0.10: 19 vs 28 objects for `page=2&per=20&sort=name`, faster
only on escaped forms). Neither Rack 3.2.9 nor Rails calls `decode_www_form` or `decode_uri_component`.

## Differential (`diff/`, `run.sh`)

`diff.rb` (300,000 random + 142 fixed, SINGLETON_B=1) and `probe.rb` (thermos-sol's 42k independent cases), each
with METHOD = both changed methods, base inlined from 48cda77: **0 differences in every log**, on 4.0.10, master
0d399335b7, 3.4.12, 4.0.10 and 3.4.12 with `pure_cgi.rb`, JRuby 10.1.3.0, TruffleRuby 40.0.0 (915 unconstructible
inputs skipped there), and probe.rb on 2.5.9 and 3.1.2. JRuby 9.4.16.0 (not in CI): `decode_uri_component`
returns String for subclasses as before; `decode_www_form_component` keeps the accepted subclass-class difference.

## Tests (`tests/`)

`suite-d09ffb7.txt`: 94 tests, 0 failures on 4.0.10, 2.5.9, 3.1.2, 3.4.12, JRuby 10.1, TruffleRuby 40 and master,
also with `no_c_decoder.rb` (gsub fallback everywhere) and `ruby_decoder.rb` (a Ruby-defined
unescapeURIComponent). JRuby 9.4.16.0: one failure, the subclass assertion of decode_www_form_component (accepted).
`mutants_by_assert.txt` evaluates each assertion of the two decode tests alone against base and 13 mutants on
4.0.10, 4.0.10 without the C decoder, 2.5.9 and TruffleRuby: base passes all; every mutant fails at least one new
assertion wherever its code path runs. Fork CI on d09ffb7: run 46071505445, every job green.

## Final head d4ce0b0 (after the Fable round, 2026-11-27)

Fable (`../fable-b0f2bb7-2026-11-27.md`) found decode_www_form_component 2x to 15x slower on TruffleRuby, where
CGI.unescape is Ruby code starting with `tr`. d4ce0b0 (tree 3621b78834) puts both methods under the one load-time
check (Fable's v-native): without a native unescapeURIComponent both keep master's `gsub`. This also removes the JRuby
9.4 subclass difference (its cgi 0.3.x has no unescapeURIComponent): the full suite passes on JRuby 9.4.16.0 now.
Taken from Fable too: `Encoding::ASCII_8BIT` as lib/uri spells it, the reason on the `else`, the helper comment,
`assert_instance_of`, the `gsub` cost wording, a body that says uri now requires cgi/escape. Not taken: dropping the
GB18030 (the non-UTF-8 source case) and `%zz` assertions. Not changed: the top-level `require "cgi/escape"` that
Fable raised for RubyGems' vendored Gem::URI (read, not run); c43954f already had it and both reviewers accepted
cgi/escape loading with uri.

`diff/` now holds d4ce0b0's run: 0 differences in all 28 logs (both methods; diff.rb on 4.0.10, master, 3.4.12,
pure CGI, JRuby 10.1.3.0, TruffleRuby 40; probe.rb also on 2.5.9 and 3.1.2). `tests/suite-final.txt`: 21 suite runs
green (7 Rubies x native / no C decoder / Ruby decoder) plus JRuby 9.4.16.0 green. `tests/mutants_by_assert.txt`: base
passes every assertion; 14 mutants each caught wherever their path runs. Fork CI run 46082238611 green (the first
JRuby/ubuntu attempt failed in Bundler's jar dependency resolution before tests; rerun green).

Commit message amended to a04eb03 (same tree 3621b78834) after Astra: on TruffleRuby it is CGI.unescapeURIComponent, not CGI.unescape, that keeps the String subclass.
Amended again to e2d2e21 (same tree) after thermos-sol: dropped the unqualified "CGI.unescape is slower than the gsub" clause; Fable measured percent-dense input going the other way.
