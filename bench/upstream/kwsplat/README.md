# Keyword splat after dynamic keywords (ruby/ruby#19670)

Patches for review. Neither is pushed to the PR.

- [e9440260c3.patch](e9440260c3.patch): a single commit on ruby/ruby master
  `b51db981f6` that replaces the PR head `eb01818c3d`. It builds the dynamic
  pairs with `core#hash_new_for_merge`, a hash with room for 8 embedded
  entries, and merges the splat into it in place with
  `core#hash_merge_fresh_kwd`. The pairs are still hashed before the splat
  expression runs, so evaluation order is unchanged.
- [5e81fc506a.patch](5e81fc506a.patch): kept in reserve, on top of the PR
  head. It builds one hash sized for the pairs and the splat in
  `core#hash_new_kwd`. It is faster, but under prism it inserts the pairs
  after the splat expression and its `to_hash` run, unlike parse.y.

## Allocations per call, `m(a: v, **h)`, |h| = 0..9

| Build | 0 | 1 | 2 | 3–9 |
|---|---|---|---|---|
| 4.0.7 | 1 | 1 | 1 | 1 |
| master `b51db981f6` | 2 | 2 | 2 | 2 |
| PR `eb01818c3d` | 1 | 1 | 2 | 2 |
| `e9440260c3` | 1 | 1 | 1 | 1 |
| `5e81fc506a` | 1 | 1 | 1 | 1 |

Single mutable keyword splat, `m(**h, &b)`, |h| = 0..9: master 3,2,2,…;
PR 2,1,1,2,2,…; `e9440260c3` 2,1,1,1,… (the same as 4.0.7).

## Callgrind Ir per call, GC disabled

Ir per call is the difference between runs of 120k and 20k calls, divided
by 100k.

`m(a: v, **h)`:

| Build | 0 | 1 | 2 | 3 | 5 | 8 | 9 |
|---|---|---|---|---|---|---|---|
| 4.0.7 | 1383 | 1918 | 2309 | 2712 | 3567 | 6272 | 6401 |
| master | 1982 | 2589 | 3021 | 3340 | 4103 | 7852 | 8267 |
| PR | 1645 | 2255 | 3006 | 3326 | 4083 | 7834 | 8257 |
| `e9440260c3` | 1900 | 2510 | 2927 | 3225 | 3956 | 6471 | 6884 |
| `e9440260c3` (A/A) | 1900 | 2505 | 2923 | 3230 | 3955 | 6477 | 6893 |
| `5e81fc506a` | 1602 | 2216 | 2651 | 2965 | 3826 | 5199 | 5617 |
| rejected: merge into `newhash` | 1620 | 2228 | 3408 | 3719 | 5329 | 7482 | 7904 |
| rejected: same, presized st_table | 1649 | 2259 | 3196 | 3506 | 4279 | 5510 | 5926 |

`m(**h, &b)`:

| Build | 0 | 1 | 2 | 3 | 5 | 8 | 9 |
|---|---|---|---|---|---|---|---|
| master | 1788 | 2432 | 2844 | 3166 | 3946 | 5075 | 8141 |
| PR | 1467 | 2116 | 2535 | 3155 | 3945 | 5087 | 8131 |
| `e9440260c3` | 1748 | 2392 | 2807 | 3113 | 3839 | 4934 | 6908 |

`e9440260c3` is below master at every size on both paths. At sizes 0–1 it
is about 250 Ir slower than the PR, because the pairs now take a C call
instead of the `newhash` instruction. The PR's `newhash` gets a 64-byte slot
whose embedded table holds 2 entries, so from 3 entries on the PR has to copy
the result into a second hash, and the two merge-into-`newhash` variants have
to convert it to an st_table.

With GC enabled (`m(a: v, **h)`, sizes 1/2/3/5/8): master
2879/3308/3616/4404/8447, PR 2503/3292/3599/4392/8429, `e9440260c3`
2694/3111/3409/4140/6935.

Memory: a small result now takes a 160-byte slot with an 8-entry embedded
table, against 64 bytes for master's second hash (a 21-entry result takes
992 bytes against 896). Both sizes match 4.0.7.

The review found no behaviour difference from master. Two follow-ups are left
out of the PR: prism zsuper with `**kwrest` still allocates one object more
than 4.0, and `core#hash_merge_fresh_kwd` could be folded into
`core#hash_merge_bang_kwd`.

## Scripts

[scripts/](scripts/) contains everything used above:

- `allocs.rb` and `allocs_s.rb` count allocations.
- `ir.sh ir.rb RUBY` and `ir.sh irs.rb RUBY` measure Ir.
- `sem.rb`, `order.rb` and `order9.rb` print semantics and evaluation order;
  compare their output across builds and with `--parser=parse.y`.

`e9440260c3` prints the same as master for all three scripts under both
parsers. `5e81fc506a` differs from master in `order.rb` and `order9.rb`
under prism.
