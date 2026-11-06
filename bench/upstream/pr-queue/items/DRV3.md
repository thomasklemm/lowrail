---
id: DRV3
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: fix
area: CI, sqlcipher on Windows
reviewer: flavorjones
branch: thomasklemm/sqlcipher-ucrt
head: "3966a52d0fd6ce1130f190b1d18dfcbab2eb1fa8"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Fixes the sqlcipher (windows, mingw) job, red on main and on every PR since MSYS2 dropped mingw-w64-x86_64-sqlcipher (msys2/MINGW-packages#32999); unblocks green CI for DRV1/DRV2."
rank: 20
risky: false
state: superseded
pr:
note: "One-line ci.yml change: the sqlcipher job's extra Windows entry uses ruby: ucrt (as the test job does) instead of ruby: mingw. sqlcipher (windows, ucrt) passed on the fork (run 42211717892, job 127872342777: mingw-w64-ucrt-x86_64-sqlcipher 4.19.0-1, :sqlcipher: true, 428 runs 0 failures). First failure on main is the 2026-11-04 schedule; the 2026-11-01 push still got 4.6.1 from the mirror."
passes:
  - {reviewer: claude-code, head: "f73b295adaabc5c275ac6cc8247aeb020c3ed00c", date: 2026-11-06, verdict: nits, open: "Body date wrong (job passed on 2026-11-01); 'current Ruby head' overstated; both applied."}
  - {reviewer: claude-code, head: "3966a52d0fd6ce1130f190b1d18dfcbab2eb1fa8", date: 2026-11-06, verdict: approve, open: "Separate Claude Code subagent review of head and body; tree identical to f73b295, message and body fixes confirmed, no trailers."}
  - {reviewer: sol, head: "3966a52d0fd6ce1130f190b1d18dfcbab2eb1fa8", date: 2026-11-06, verdict: approve, open: "No findings."}
---

# ci: test sqlcipher on the ucrt Ruby head instead of mingw

The `sqlcipher (windows, mingw)` job fails at setup with `error: target not found: mingw-w64-x86_64-sqlcipher`, on main as well since the 2026-11-04 [scheduled run 41797589777](https://github.com/sparklemotion/sqlite3-ruby/actions/runs/41797589777/job/126465995083). MSYS2 stopped building sqlcipher for the MINGW64 environment when it updated the package to 4.19.0 in msys2/MINGW-packages#32999; it now ships only for ucrt64, clang64 and clangarm64.

This changes that matrix entry to `ruby: ucrt`, as the `test` job already uses, so setup-ruby-pkgs installs `mingw-w64-ucrt-x86_64-sqlcipher` and the job still builds `--with-sqlcipher` against a Ruby head on Windows. The ruby-loco mingw build behind `ruby: mingw` hasn't been updated since 2025-11-18. Only the MSVCRT (x64-mingw32) platform loses sqlcipher coverage, since MSYS2 no longer packages it there.
