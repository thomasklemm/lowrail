Title: Match byte order marks with their own rule in the C lexer

Since #5849, the C lexer accepts byte order marks through `BLANK = ([, \t] | 0xEF 0xBB 0xBF)+`. Inside that repetition, the three-byte alternative makes every blank character a point the scanner may have to back up to, so it stores the token end and rule on each one. On ruby-bench's graphql-native document (`negotiate.gql`, 100 parses), that commit adds 1.66% instructions, most of the 2.1% between graphql-c_parser 1.1.3 and 1.2.0.

This gives the byte order mark its own scanner rule with `BLANK`'s action: it adds its width to the column and clears the number flag. Tokens, columns and errors stay the same. On 34 inputs with whole and truncated byte order marks in and around tokens, numbers, strings and comments, the output is identical to master.

Instructions drop 1.33% (Cachegrind, Ruby 4.0.9, two runs each, within 0.03%). `lexer.c` is regenerated as in #5877. Tests pass with `GRAPHQL_CPARSER=1`.

---

<sub>Found while measuring graphql-c_parser 1.2.0 for ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/4ed0d1fb97ff4cd4e7ecc49a7481cb6270c14cb5/docs/upstream/graphql-ruby.md#b-c-lexer-byte-order-marks-in-blank), my research project.</sub>
