# CC1 objects per Ability.new, 2026-11-27

`objects.rb` is the body's script. Run from a cancancan checkout as `ruby [--yjit] -Ilib objects.rb` on Ruby 4.0.9:
base main `021b13cf76` twice (A/A) and head `cd1f37066b` (same `lib/` as `cb5768e493`, two of the five
specs dropped), interpreter and YJIT. Output in `output.txt`: 57, 57 / 52. Allocation counts are deterministic;
the Callgrind instruction counts in the body come from `../CC1-repair` (same `lib/` tree).
