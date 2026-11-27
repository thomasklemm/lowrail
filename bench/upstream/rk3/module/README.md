# RK3: unescape in one module (jeremyevans's inline suggestion)

jeremyevans on lib/rack/query_parser.rb:282 (PR approved at e26338b40a): avoid the duplicated `unescape`; since
`utils` requires `query_parser`, move it into a module that both `Rack::Utils` and `Rack::QueryParser` include.

Built as a third commit on e26338b40a: fork branch `unescape-cgi-5`, head `0046982320094e11d80d2ec19bf0ab69f05ba41b`; after the review rounds the PR head is `3ca13466d5` (see the RK3 item note: docs kept as RDoc and YARD entries, the comment removed)
(Thomas as author and committer, no trailers). The PR branch `thomasklemm/unescape-cgi` stays at e26338b40a.

## The change

`Rack::QueryParser::Unescape` (`# :nodoc:`) is defined in query_parser.rb after the error classes and holds the one
`unescape`, private, with Utils' doc comment and parameter names. `QueryParser` includes it; `Utils` does
`include QueryParser::Unescape` and `module_function :unescape` where the method was. 2 files, +17/−15.

Why this shape:
* **In query_parser.rb, not a new file.** utils.rb already requires query_parser.rb, and query_parser.rb already
  requires `uri` and `cgi/escape`, so require order and what each entry point loads stay as they are, and
  rack.rb needs no new autoload. A new file would have needed its own requires and an autoload decision.
* **Nested in QueryParser, not `Rack::Unescape`.** Rack's top-level constants are mostly middleware
  (`Rack::Head`, `Rack::Lock`), so `Rack::Unescape` would read like one; it is internal, so `:nodoc:`.
* **Private in the module.** QueryParser#unescape was private; `module_function` makes Utils' copy private again
  and gives `Rack::Utils.unescape` its public singleton copy, as before.
* **Doc comment on the method.** It moved with the body.

## Results

Rubies: official ruby-builder binaries 2.7.3 (Rack's minimum), 3.0.7, 3.1.7, 3.2.9, 3.3.9, 3.4.6 (`get_rubies.sh`)
and mise 4.0.9. Rack's CI covers 2.7, 3.0–3.4, 4.0, ruby-head, JRuby/TruffleRuby head and macOS 4.0; the last
four were not run locally.

**Suite** (`suite.sh`, `CI=spec bundle exec rake`, clean and `RUBYOPT=-rcgi/util`), head and e26338b40a:

| Ruby | runs, assertions (head = base) | failures/errors/skips |
| --- | --- | --- |
| 2.7.3 | 1315, 5725 | 0/0/2 |
| 3.0.7, 3.1.7 | 1317, 5729 | 0/0/2 |
| 3.2.9, 3.3.9, 3.4.6, 4.0.9 | 1317, 6421 | 0/0/2 |

Every test file passed in all 28 runs (`All test files passed`).

**Differential** (`record.rb`, `replay.rb`, `compare.rb`, `replay_all.sh`). `record.rb` traced every argument the
suite passes to `Utils.escape`/`unescape` and `QueryParser#unescape` on 4.0.9 (631 distinct inputs under 2 KB,
`suite-inputs.rec`). `replay.rb` adds 20,000 seeded random mixes of `%`, `+`, invalid escapes and non-ASCII bytes in
UTF-8, BINARY, US-ASCII, Shift_JIS, ISO-8859-1 and EUC-JP with seven target encodings, plus fixed cases: invalid %
in every position, UTF-16/32 and UTF-7, frozen strings, String subclasses, strings with instance variables, nil,
Symbols, Integers, Floats, `to_s` ducks, Arrays, Hashes, bad encoding names, BasicObjects with and without
`to_str`/`b`, encodings that are stateful or mutate the input, and singleton `gsub`/`b`. It calls each one through
`Rack::Utils.unescape`, `QueryParser#unescape`, an object that includes `Rack::Utils`, and a QueryParser subclass
that overrides `unescape` and calls `super`; it also calls `escape` both ways, plus `parse_query`,
`parse_nested_query`, the subclass's `parse_query` and `parse_cookies_header`. Then it probes visibility, arity and
`module_function`. The run makes 204,073 calls per configuration on 2.7.3–4.0.9, clean and with cgi/util, and with
the Ruby CGI on 3.4.6/4.0.9 (16 configurations, `replay-summary.txt`; diffs in `replay-diffs/`).

Every difference is one of these:
1. **Utils.unescape's invalid-%-encoding message** (9,764 lines per configuration: `Utils.unescape` and the
   includer). utils.rb is a `# -*- encoding: binary -*-` file, so on e26338b40a the `ArgumentError` message for an
   ASCII-only string was BINARY. URI on main and `QueryParser#unescape` give UTF-8, and now Utils does too. For
   non-ASCII strings the message already took their encoding. Message bytes are unchanged.
2. `QueryParser#unescape`'s parameters are `[[:req, :s], [:opt, :encoding]]` instead of `:string` (1 probe line).
3. Harness noise: an object address inside the escaped `to_s` of an `Object` (2 lines), and on 3.1.7 only, 12
   error_highlight snippets of the BasicObject `NoMethodError` that quote the moved source line.

Unchanged: every result's class, encoding, bytes, frozenness, validity and instance variables; every exception
class and message bytes; `Rack::Utils.unescape` public on the singleton and private as an instance method
(`private_method_defined?` true, `public_method_defined?` false); `include Rack::Utils` callers get a private
`unescape`; the QueryParser subclass's override and `super` work; prepending to `Rack::Utils.singleton_class`
still overrides it.

Reflection that changes and is not in the probe's output: `Rack::Utils.instance_method(:unescape).owner` is
now the module, and `Rack::Utils.private_instance_methods(false)` no longer lists `:unescape`
(`modfunc_probe.rb`, same on 2.7.3, 3.0.7, 3.4.6 and 4.0.9).

**Loading** (`loading.rb`, 4.0.9): after `require "rack"`, `"rack/query_parser"`, `"rack/utils"`,
`"rack/request"` or `"rack/mock_request"`, head and base load the same files and leave the same autoloads.
`"rack/query_parser"` alone still works without Utils (`loading-4.0.9.txt`).

**RuboCop** (lib/rack/query_parser.rb and lib/rack/utils.rb): 5 offenses before and after.
