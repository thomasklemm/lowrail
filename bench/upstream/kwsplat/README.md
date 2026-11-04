# Keyword splat after dynamic keywords (ruby/ruby#19670)

Status, 2026-11-04: Thomas pushed `9fd1f6f25d` to the PR. The PR branch
`thomasklemm/kwsplat-fit-merge` moved from `eb01818c3d` to `9fd1f6f25d`, and
the PR body was rewritten to match the commit message.

Two items stay out of this PR:
- **Follow-up fix:** prism zsuper with `**kwrest` still allocates one object
  more than 4.0. The fix is one token, `id_core_hash_merge_bang_ptr` instead of
  `id_core_hash_merge_ptr`, because the receiver is a fresh `kwrest.dup`.
- **Lead:** `X = {**H, a: v}` under
  `shareable_constant_value: experimental_everything` raises "undefined method
  'core#hash_merge_ptr'" on 4.0.7 and master. The shareable `PM_ASSOC_NODE`
  branch compiles into `ret` instead of `anchor` (prism_compile.c, around
  line 1588).

- [9fd1f6f25d.patch](9fd1f6f25d.patch) replaces the PR head `eb01818c3d`. It
  is a single commit on ruby/ruby master `6756292b31` and is also on the fork
  branch `thomasklemm/kwsplat-ar-room-3`. Before the rebase it was
  `bd53d14e1d` on `b51db981f6`; `git range-diff` shows only the round 3
  changes. It brings back Ruby 4.0's
  construction:
  - `core#hash_new_for_merge` builds the pairs in a hash with room for 8
    entries in its embedded table.
  - The existing `core#hash_merge_bang_kwd` then merges the splat into that
    hash in place. For a nil splat it now returns the hash as it is instead of
    copying it.
  - `core#hash_new_for_merge` fires the same DTrace hash-create probe as
    `newhash` (`RUBY_DTRACE_CREATE_HOOK(HASH, n)`). This orb has no DTrace,
    so the probe is untested.
  - The pairs are still hashed before the splat expression runs.
  - Prism compiles hash literals such as `{a: v, **h}` with the same code, so
    they change the same way.
- [5e81fc506a.patch](5e81fc506a.patch) is a reserve on top of the PR head; it
  is also on `thomasklemm/kwsplat-sized-hash`. It builds one hash sized for the
  pairs plus the splat. Under prism the pairs are then inserted after the
  splat expression and its `to_hash` have run, so it changes evaluation order.

## Key `#hash` calls: the same as 4.0.7

`scripts/hashcount.rb` counts the `#hash` calls on keys of a custom class for
`{k => v, **h}` and `m(k => v, **h)`, where `h` has n custom keys. Literals and
calls give the same counts on every build.

| Build | n=1 | 2 | 3 | 7 | 8 | 9 | 12 | `#hash` raising on its 2nd call |
|---|---|---|---|---|---|---|---|---|
| 4.0.7, prism and parse.y | 2 | 3 | 4 | 8 | 18 | 19 | 22 | raises from n=8 |
| master / PR, prism | 2 | 3 | 4 | 8 | 12 | 13 | 16 | never raises |
| master / PR / new, parse.y | 2 | 6 | 7 | 11 | 12 | 13 | 16 | never raises |
| `9fd1f6f25d`, prism | 2 | 3 | 4 | 8 | 18 | 19 | 22 | raises from n=8 |

- A 4.0-style hash starts with 8 embedded entries. When it outgrows them, it
  converts to an st_table and calls `#hash` again on every key it holds.
  Master copies the result into a hash allocated with the right size instead,
  so most keys are not hashed again.
- The script prints the full table, including two pairs before the splat.
- Every build from master on makes one more `#eql?` call per construction than
  4.0.7. That comes from a separate change to Hash: on master, plain
  `h = {k0 => 1}; h[k1] = 2` also calls `#eql?` once (`scripts/eql.rb`).

### A nil splat no longer copies

`scripts/nilsplat.rb` counts `k.hash` calls for
`m(k => v, **h, **n, z => v)` with `n = nil`, compared with leaving `**n`
out. Under parse.y, master calls it 3 times instead of 2 for `h` of 2, 3, 5
or 7 entries: `core#hash_merge_bang_kwd` copied the hash for the nil splat,
and the copy outgrew its table again. With `9fd1f6f25d`, both parsers give
the same count with and without `**n`. Under prism, `9fd1f6f25d` matches
4.0.7 at every size.

## Objects and bytes per call

`scripts/bytes.rb` measures objects, GC slot bytes (from `GC.stat_heap`), and
`ObjectSpace.memsize_of` of the result. GC is disabled while it measures.
Calls and literals give the same numbers.

| `m(a: v, **h)`, size | 0 | 1 | 2 | 3 | 8 |
|---|---|---|---|---|---|
| 4.0.7 | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 544 |
| master | 2 / 128 / 64 | 2 / 128 / 64 | 2 / 144 / 80 | 2 / 160 / 96 | 2 / 128 / 448 |
| PR | 1 / 64 / 64 | 1 / 64 / 64 | 2 / 144 / 80 | 2 / 160 / 96 | 2 / 128 / 448 |
| `9fd1f6f25d` | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 160 | 1 / 160 / 544 |

Each cell is objects / slot bytes / result memsize. The new commit matches
4.0.7 exactly. Compared with master it allocates 32 B more slot bytes at
sizes 0–1, 16 B more at 2, the same at 3, and 32 B more at 8. A result that
stays alive is 64–96 B larger. For the single mutable splat `m(**h, &b)`,
master allocates 128/128/128/144/224 slot bytes and `9fd1f6f25d` 160 at every
size.

## Callgrind Ir per call, GC disabled

The Ir and YJIT figures for the new commit were measured on `bd53d14e1d`,
before the rebase. Since then the only code change is the DTrace hook, which
compiles to nothing without DTrace.

Ir per call is the difference between runs of 120k and 20k calls, divided by
100k (`scripts/ir.sh`).

| `m(a: v, **h)` | 0 | 1 | 2 | 3 | 5 | 8 | 9 |
|---|---|---|---|---|---|---|---|
| 4.0.7 | 1383 | 1918 | 2309 | 2712 | 3567 | 6272 | 6401 |
| master | 1982 | 2589 | 3021 | 3340 | 4103 | 7852 | 8267 |
| PR | 1645 | 2255 | 3006 | 3326 | 4083 | 7834 | 8257 |
| `9fd1f6f25d` | 1895 | 2511 | 2923 | 3230 | 3960 | 6452 | 6892 |
| `9fd1f6f25d` A/A | 1895 | 2506 | 2923 | 3225 | 3960 | 6471 | 6899 |

| `m(**h, &b)` | 0 | 1 | 2 | 3 | 5 | 8 | 9 |
|---|---|---|---|---|---|---|---|
| master | 1788 | 2432 | 2844 | 3166 | 3946 | 5075 | 8141 |
| PR | 1467 | 2116 | 2535 | 3155 | 3945 | 5087 | 8131 |
| `9fd1f6f25d` | 1748 | 2389 | 2806 | 3110 | 3840 | 4937 | 6794 |

The new commit is below master at every size on both paths. At sizes 0–1 it
costs about 250 Ir more than the PR (on `m(**h, &b)` also at size 2). The
reason is that the pairs go through a C call instead of the `newhash`
instruction.

## YJIT elapsed time, GC enabled

`scripts/yt.rb` runs with `--yjit`. Each figure is ns per call, the best of 3
runs of 2M calls; the two figures are two separate runs.

| `m(a: v, **h)` | 0 | 1 | 2 | 3 | 8 |
|---|---|---|---|---|---|
| 4.0.7 | 138 / 134 | 190 / 184 | 220 / 212 | 270 / 241 | 633 / 588 |
| master | 192 / 183 | 263 / 246 | 297 / 278 | 328 / 304 | 1008 / 950 |
| PR | 130 / 136 | 197 / 208 | 285 / 295 | 312 / 311 | 969 / 973 |
| `9fd1f6f25d` | 149 / 147 | 215 / 223 | 251 / 249 | 277 / 275 | 800 / 716 |

The `9fd1f6f25d` runs overlapped with a `make test-all` run, which probably
explains the spread at size 8. A run of the same code before the fold, with no
other load, gave 155/219/254/280/732.

## Tests

- `test_keyword_splat_after_dynamic_keywords` in test_keyword.rb (35
  assertions) covers:
  - custom `#hash`/`#eql?` keys
  - the initial keys being hashed before the splat expression and its
    `to_hash` run
  - exactly one `to_hash` call, with the source isolated afterwards
  - at most two `#hash` calls per key when the hash grows to 9 entries
  - a runtime nil splat after accumulated keywords plus trailing pairs
  - an unflagged result from a ruby2_keywords-flagged source
  - a `to_hash` that raises or returns a non-Hash
  - multiple splats with trailing pairs
  - mutating the source or the result afterwards
  - defaults and compare_by_identity not being adopted
  - literals

  It passes on 4.0.7 and `9fd1f6f25d` under both parsers, and on master and
  the PR under prism. Under parse.y on master and the PR, only the nil-splat
  count assertion fails (3 calls instead of 2).
- The allocation assertions in test_allocation.rb fail on master and on the
  PR head.

## Scripts

[scripts/](scripts/): `allocs.rb`, `allocs_s.rb` and `bytes.rb` (objects and
bytes), `ir.sh` with `ir.rb`/`irs.rb` (Ir), `yt.rb` (YJIT time),
`hashcount.rb` and `eql.rb` (key callbacks), and `sem.rb`, `order.rb` and
`order9.rb` (semantics and evaluation order; compare the output across builds
and with `--parser=parse.y`).
