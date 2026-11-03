# rails#58427: `find_by_sql` binds and PostgreSQL typed literals

Lead from the [PG census](pg-census.md): since rails#58427 (`8c4ed25f0a`, merged 2026-08-09), array-form
`find_by_sql` and `count_by_sql` send their values as bind parameters, as `where` has done since #51139 (Rails 7.2).
Under PostgreSQL prepared statements, a placeholder that must be a literal now reaches the server as `$1`.

## Repro

[`bench/upstream/find_by_sql_typed_literals.rb`](../../bench/upstream/find_by_sql_typed_literals.rb) (bundler/inline;
`RAILS_PATH=…` for a checkout, otherwise Active Record 8.1.4). Active Record 8.1.4 against main `5810776eec`,
PostgreSQL 15, MySQL 8.4.10 (mysql2), SQLite 3, Ruby 4.0.7 (2026-11-03):

| Statement | PG prepared, 8.1.4 | PG prepared, main | PG unprepared, MySQL |
| --- | --- | --- | --- |
| `find_by_sql(["SELECT DATE :d", d:])`, `DATE ?` | works | `syntax error at or near "$1"` | unchanged |
| `TIMESTAMP :t`, `TIMESTAMPTZ :t`, `TIMESTAMP WITH TIME ZONE :t`, `TIME :t` | works | syntax error | unchanged |
| `INTERVAL :i`, `JSONB :j` | works | syntax error | unchanged (MySQL lacks them) |
| `count_by_sql([… WHERE day = DATE :d])`, `DATE ?` in a WHERE | works | syntax error | unchanged |
| `DATE '2026-01-02' + :n` | works | `operator is not unique: date + unknown` | unchanged |
| `(:x IS NULL)` | works | `could not determine data type of parameter $1` | unchanged |
| `:d::date`, `CAST(:d AS date)`, `:a = :b` | works | works | unchanged |
| `where("day = DATE :d", d:)`, `where("day = DATE ?", …)` | **syntax error already** | syntax error | unchanged |

PostgreSQL with `prepared_statements: false` substitutes the binds and keeps working. mysql2 and SQLite are unaffected:
mysql2 interpolates binds on the client, and SQLite has no typed-literal syntax (only the error text changes). mysql2
with `prepared_statements: true` crashed the mysql2 gem in this orb (`NoMemoryError`) under both versions and is not
covered.

## Prior decisions

The same limitation in `where` was reported after #51139 and closed as not planned: #52643 (`IS ?`), #52052
(`$1 IS NULL`), #52584 (an interval built from a bind, closed as a duplicate of #51617), #55439 (`IS ?`). byroot: "parsing the
query would be too unreliable", and no workaround keeps what bound values gained (#52643). In #55439 matthewd named the `TIMESTAMP 'x'` form as the same case, and byroot was open to "a few regexp" for
a nicer error message on common cases. No open issue or PR covers #58427's `find_by_sql` change (searched
2026-11-03), and #58427 has no review comments.

## Options

1. **Document it (recommended).** #58427's CHANGELOG entry says `find_by_sql` now matches `where`, but not what
   breaks. A short addition: with prepared statements on PostgreSQL, a placeholder used as a typed literal
   (`DATE :d`, `INTERVAL :i`) or one PostgreSQL can't type (`:x IS NULL`) needs `CAST(:x AS type)` or `:x::type`, or
   `sanitize_sql_array` for the previous interpolation. This matches the maintainers' position on `where`.
2. **A clearer error**, as byroot offered in #55439: when PostgreSQL reports a syntax error at `$n` right after a
   type name or `IS`, append that hint. It changes no semantics, but it is a heuristic over error text.
3. **Interpolate after a type keyword.** Not exact: PostgreSQL accepts `type 'literal'` for any type name (`JSONB`,
   `UUID`, user-defined types, `TIMESTAMP(3)`, `TIMESTAMP WITH TIME ZONE`), so a keyword list is incomplete. It also
   misses the type-inference failures, and it would have to apply to `where` too, which maintainers declined.
4. **Revert `find_by_sql` to interpolation.** This gives up #58427's parity with `where` and the bound values. One
   could argue that the raw-SQL escape hatch should stay literal, but that is kamipo's call, not a bug fix.

No Rails patch was written: the behavior follows a deliberate, repeatedly confirmed design, so options 1 and 2 are
maintainer decisions.
