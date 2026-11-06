---
id: DRV1
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: perf
area: UTF-8 text parameter binding
reviewer: flavorjones
branch: thomasklemm/skip-utf8-bind-transcode
head: "c55ce350e32f4cf05ff7f7680120d011e84eba59"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Every UTF-8 SQLite text bind in Rails and direct-driver apps avoids a temporary String; a common 20-name lookup drops 162 to 142 objects and 0.82% interpreter query instructions. YJIT select_all drops 1.27% with passing A/A; the pluck instruction window rejects for compilation."
rank: 22
risky: true
state: in-review
note: "Test-only follow-up pushed; skeptic confirms the new head and body. Sol confirm is coordinator-owned; prior Sol/Astra nits are addressed. The public footer resolves. Fork has no CI checks; interpreter/YJIT suites pass."
passes:
  - {reviewer: skeptic, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-05, verdict: approve, open: "Publish the linked driver-cpu.md report before upstream use."}
  - {reviewer: sol, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-06, verdict: nits, open: "Add engine-independent invalid-UTF-8 and retained-binding tests; clarify String allocation and measurement scope."}
  - {reviewer: astra, head: "b2735e1a77898954b21d1cd4f2f8b0dc518200bb", date: 2026-11-06, verdict: nits, open: "No exactness finding; add behavioural coverage and clarify the body."}
  - {reviewer: skeptic, head: "c55ce350e32f4cf05ff7f7680120d011e84eba59", date: 2026-11-06, verdict: approve, open: "No must-fix; behavioural tests and body confirmed, public footer HTTP 200."}
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
