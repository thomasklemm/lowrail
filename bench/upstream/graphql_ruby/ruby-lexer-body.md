Parsing with the Ruby lexer takes about 24% more instructions on master than on 2.5.11 (Cachegrind, Ruby 4.0.9). Almost all of it comes from 2.6.1's change that counts comments toward `max_tokens`: `Lexer#advance` now skips comments in a `loop do … break end` block, and leaving that block with `break` goes through the VM's exception handler on every token. Every token also tries `COMMENT_REGEXP`, even when the next character isn't `#`.

This uses a `while` loop that first checks for `"#"` with a String pattern, then skips the comment body. Comments are counted the same way, and the overflow error has the same position.

| | master | this PR |
| --- | ---: | ---: |
| `rake bench:parse`, introspection | 4.3–4.4k i/s | 5.4k i/s |
| `rake bench:parse`, big query | 726–736 i/s | 923 i/s |

On 34 inputs (comments, BOMs, CR line endings, end of input) with five `max_tokens` values, tokens, positions and errors match master. Tests pass with and without `GRAPHQL_CPARSER=1`.

---

<sub>Found while measuring graphql-ruby's parsers for ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/4ed0d1fb97ff4cd4e7ecc49a7481cb6270c14cb5/docs/upstream/graphql-ruby.md#a-ruby-lexer-loop-in-advance), my research project.</sub>
