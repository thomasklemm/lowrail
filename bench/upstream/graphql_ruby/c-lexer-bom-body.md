Since #5849, the C lexer accepts byte order marks as part of `BLANK = ([, \t] | 0xEF 0xBB 0xBF)+`. Because a blank run might continue into a three-byte BOM, the generated scanner records a backtrack point on every blank character, even in documents without a BOM. That accounts for 1.66% more instructions in graphql-c_parser 1.2.0 than in 1.1.3 on ruby-bench's graphql-native document.

This gives the BOM its own rule with `BLANK`'s action: it advances the column and clears `preceeded_by_number`. Tokens, columns and errors stay the same, and `lexer.c` is regenerated as in #5877.

Instructions drop 1.33% on `negotiate.gql` (Cachegrind, Ruby 4.0.9, two runs agree within 0.03%). On 34 inputs with whole and truncated BOMs in and around tokens, numbers, strings and comments, the output matches master. Tests pass with `GRAPHQL_CPARSER=1`.

---

<sub>Found while measuring graphql-c_parser 1.2.0 for ruby/ruby-bench#568, recorded in [Lowrail](https://github.com/thomasklemm/lowrail/blob/4ed0d1fb97ff4cd4e7ecc49a7481cb6270c14cb5/docs/upstream/graphql-ruby.md#b-c-lexer-byte-order-marks-in-blank), my research project.</sub>
