# RK3 -3: `instance_of?(String) && ascii_compatible?` guard

Fork branch `unescape-cgi-3`, head `1f11617245` (decode `d8bfe684c1`, escape `1f11617245`) on rack main
`da90464e3f`. All three methods open with

    return URI.<same call as main> unless s.instance_of?(String) && s.encoding.ascii_compatible?

(`string` in `QueryParser#unescape`). String subclasses, ActiveSupport::SafeBuffer included, and strings in
encodings that are not ASCII-compatible go through URI as on main. A `BasicObject` has no `instance_of?` and now
raises `NoMethodError` instead of being converted through `to_s`/`to_str`.

* `suite/`: `CI=spec bundle exec rake` on 4.0.9, 3.4.12, 3.3.10 and 3.2.9, clean and `RUBYOPT=-rcgi/util`:
  1294 runs, 6272 assertions, 0 failures, 0 errors, 2 skips each.
* `diff_all.log` and `diff_*`/`review_exactness-*`: `bench/upstream/rk3/diff_all.sh` on 3.2–4.0 clean and util,
  pure Ruby CGI on 3.4/4.0. Every configuration: diff_unescape 4 differences (BasicObject to_str+b, to_str+b with
  a lone %, to_str only, plain BasicObject), diff_escape 3 (BasicObject to_s, to_s returning a subclass, plain
  BasicObject; also through build_nested_query), review_exactness 3 of 17,897 (`basicobject/escape`,
  `basicobject/unescape`, `basicobject/query_unescape`). In each case main converts or raises a different error and
  the branch raises `NoMethodError` for `instance_of?`. The `boundary` lines are the documented singleton `#b`
  overrides and are not counted. String subclasses, a subclass with an instance variable, a subclass `"~"`, `"*"`,
  `""` and `"a"`, and UTF-16 input to both decoders: same as URI. `review_exactness-2.7.8-*`: same 3 differences
  (2.7.8 loads cgi/util in both modes).
* `control-*`: the extended diff scripts (2,000 random cases plus the fixed ones) on 4.0.9 against `178bfa8392`
  (subclass `""`, `"~"` → subclass `"%7E"`, `"a"`, tagged `"a"` differ) and main `da90464e3f` (0).
* `safebuffer-*`: `guard_safebuffer.rb` with ActiveSupport 8.1.4.1 on 4.0.9, now including html-unsafe buffers
  (after `gsub!`). On `178bfa8392` unescape returns an html_safe SafeBuffer where URI returns a plain unsafe String,
  safe or unsafe input; on `1f11617245` every line matches URI.
* `callers-2.7.8-1f11617245.txt`: `guard_callers_27.rb`; identical to `02087583dc`, Rack's parsers return Strings.
* `mutants.txt`: `bench/upstream/rk3/guard_mutants.sh` on 4.0.9 and 3.4.12 over spec_utils and spec_query_parser.
  Killed: escape without guard, either decoder without guard (separately and together), `String ===` or `is_a?`
  instead of `instance_of?` in any method, escape without `ascii_compatible?` on 3.4.12. Old libs: `178bfa8392`
  fails the three subclass tests, `02087583dc` and main pass. Not killed: escape without `ascii_compatible?` on 4.0.9
  and the decoders without it on both, which are equivalent there: `mutant-no-ascii-review_exactness-*` shows only
  the BasicObject differences on 4.0.9 and 3,458 escape differences on 3.4.12 (ASCII-incompatible strings raise `NoMethodError` from CGI.escape without cgi/util).
* `rubocop-*`: the four touched files have the same 61 offenses as main.
