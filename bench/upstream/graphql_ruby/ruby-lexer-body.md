Title: Skip comments in the Ruby lexer without `loop`

Since 2.6.1, `Lexer#advance` skips comments in a `loop do … next … break end` block so they count toward `max_tokens`. `break` leaves `loop`'s block through the VM's exception handler, once per token, and every token also tries `COMMENT_REGEXP`. In Cachegrind on Ruby 4.0.9, that commit adds 22.7% instructions to parsing, nearly all of the 24% between 2.5.11 and master.

This keeps the counting, but uses `while` and checks for `"#"` with a String pattern before matching the comment body. A failed `skip` clears the match state either way. On 34 inputs (comments, byte order marks, CR line endings, end of input, the benchmark queries) with `max_tokens` nil, 3, 5, 12 and 40, tokens, positions and errors match master. Tests pass with and without `GRAPHQL_CPARSER=1`.

That takes back about 90%: 16.4% fewer instructions over four documents (two runs, within 0.01%). In `rake bench:parse`, introspection goes from 4.3–4.4k to 5.4k i/s, the big query from 726–736 to 923.

---

<sub>Found while measuring graphql-ruby's parsers for ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/4ed0d1fb97ff4cd4e7ecc49a7481cb6270c14cb5/docs/upstream/graphql-ruby.md#a-ruby-lexer-loop-in-advance), my research project.</sub>
