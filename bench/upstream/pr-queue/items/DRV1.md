---
id: DRV1
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: perf
area: UTF-8 text parameter binding
reviewer: flavorjones
branch: thomasklemm/skip-utf8-bind-transcode
head: "f1709a4f539ddec0363b18daab0e0b057c0959b9"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Every UTF-8 SQLite text bind in Rails and direct-driver apps avoids a temporary String; a common 20-name lookup drops 162 to 142 objects and 0.82% interpreter query instructions. YJIT select_all drops 1.27% with passing A/A; the pluck instruction window rejects for compilation."
rank: 22
risky: true
state: draft
pr: 769
note: "Restacked 2026-11-06 into one commit, 16c9550b68, on 48091f4694; force-pushed. C change identical to b2735e1a77, so measurements stand. Allocation test dropped (DECISIONS e7dccb6: behaviour only, no GC.stat); retained-text mutation test dropped as covered by SQLITE_TRANSIENT and not at risk from this branch. Kept invalid/truncated UTF-8 bound as TEXT with exact bytes (catches a scrub/validate regression the suite misses) and invalid US-ASCII still raising (catches the `!UTF8_P && !USASCII_P` mutant). Reasoning and measurements now in the commit message. Skeptic nits on the restack applied (f9005a2 history, system SQLite 3.40.1). Body unchanged. Earlier passes name old heads. Claude Code final review 2026-11-06: f1709a4f53 = 16c9550b68 with an identical tree; the commit message drops its measurement paragraph (numbers stay in the body and driver-cpu.md) and rewords the tests paragraph (\"a change to this branch\" read as a git branch). Body unchanged; no CHANGELOG entry (flavorjones adds them at merge, as on #758)."
passes:
  - {reviewer: skeptic, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-05, verdict: approve, open: "Publish the linked driver-cpu.md report before upstream use."}
  - {reviewer: sol, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-06, verdict: nits, open: "Add engine-independent invalid-UTF-8 and retained-binding tests; clarify String allocation and measurement scope."}
  - {reviewer: astra, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-06, verdict: nits, open: "No exactness finding; add behavioural coverage and clarify the body."}
  - {reviewer: skeptic, head: "c55ce350e32f4cf05ff7f7680120d011e84eba59", date: 2026-11-06, verdict: approve, open: "No must-fix; behavioural tests and body confirmed, public footer HTTP 200."}
  - {reviewer: sol, head: "c55ce350e32f4cf05ff7f7680120d011e84eba59", date: 2026-11-06, verdict: nits, open: "No code or body fixes; asked that new tests pass on main and HEAD, which the skeptic already ran."}
  - {reviewer: astra, head: "c55ce350e32f4cf05ff7f7680120d011e84eba59", date: 2026-11-06, verdict: approve, open: "No source/body fixes."}
  - {reviewer: claude-code, head: "f1709a4f539ddec0363b18daab0e0b057c0959b9", date: 2026-11-06, verdict: approve, open: "Reviewed 16c9550b68; message-only fix applied. Bind matrix (33 kinds of string incl. broken/frozen/shared/subclass UTF-8, US-ASCII, Latin-1, SJIS, UTF-16/32, UTF8-MAC, CESU-8, binary, Blob; with and without default_internal ISO-8859-1; positional and named) identical to main on Ruby 3.2.11/3.3.13/3.4.12/4.0.9 (system SQLite 3.40.1): bytes, types, errors, caller string unchanged. New tests pass on main and kill 4 mutants (&& !USASCII_P, scrub, raise on broken, blob for broken). Suite 430/880 green on 4.0.9. Exact-head CI 133 pass, 2 fail: sqlcipher mingw (target not found) and Windows 3.3 collation, both failing on upstream main schedule run 41797589777; earlier busy_timeout flake fails on main in 5+ runs. Nothing open."}
  - {reviewer: sol, head: "f1709a4f539ddec0363b18daab0e0b057c0959b9", date: 2026-11-06, verdict: approve, open: "Final confirm on restacked head; no findings."}
  - {reviewer: astra, head: "f1709a4f539ddec0363b18daab0e0b057c0959b9", date: 2026-11-06, verdict: approve, open: "Final confirm on restacked head; no findings."}
---

# Avoid a redundant String when binding UTF-8 text

Binding a UTF-8 string currently allocates a redundant String through `rb_str_encode`: the condition `!UTF8_P(value) || !USASCII_P(value)` is always true. A lookup such as `where(name: names).pluck(:id)` makes one unnecessary String for every name.

Pass UTF-8 strings straight to SQLite, which still takes its own copy. Other encodings keep their existing conversion, including errors for invalid US-ASCII strings.

Objects and Callgrind instructions per 20-name Active Record lookup, Ruby 4.0.9, interpreter:

| | Before | After |
|---|---:|---:|
| Objects | 162 | 142 |
| Instructions | 1,092,175 | 1,083,184 |

These measurements use SQLite 3.40.1 and do not claim a request-level speedup.

---
<sub>Found through Lowrail, my performance research project: [driver CPU study](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/driver-cpu.md).</sub>
