graphql-c_parser doesn't compile on Windows with RubyInstaller (MinGW). There, `ruby.h` includes `windows.h`, which declares `FLOAT`, `INT` and `INPUT` as types, defines `INTERFACE` as a macro and declares `TokenType` as an enumerator. The extension uses these names for its token constants, so 1.1.4 fails with errors such as `lexer.rl:161:2: error: 'FLOAT' redeclared as different kind of symbol`.

This adds `%define api.token.prefix {GRAPHQL_}` to `parser.y`, which renames only the generated C constants, so error messages such as `unexpected INT ("2")` stay the same. In the lexer, the four enumerators become `*_LITERAL`, like `TYPE_LITERAL`, and the enum becomes `GraphQLTokenType`. The emitted token symbols and numbers don't change.

`parser.c` is regenerated with Bison 3.8.2. My Ragel 7.0.4 build formats `lexer.c` differently from the committed file, so I applied only the lines Ragel changes, with `#line` numbers updated.

On Linux the test suite passes with and without `GRAPHQL_CPARSER=1`. On Windows, ruby-bench's graphql-native benchmark built from this branch compiles and runs on Ruby 4.0 and head: https://github.com/thomasklemm/ruby-bench/actions/runs/42034420178

---

<sub>Found while enabling more benchmarks on Windows in ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ruby-bench-improvements.md#round-3-rails-benchmarks-on-windows-2026-11-05), my research project.</sub>
