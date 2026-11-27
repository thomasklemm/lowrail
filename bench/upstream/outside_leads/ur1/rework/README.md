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
