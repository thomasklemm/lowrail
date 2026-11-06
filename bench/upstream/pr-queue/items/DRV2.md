---
id: DRV2
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: perf
area: Multi-column result rows
reviewer: tenderlove
branch: thomasklemm/fill-multicolumn-rows
head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Every SQLite result row with two or more columns, including ordinary Rails record loads, avoids repeated Array length updates. A seven-column select_all takes 1.72% fewer interpreter instructions at 20 rows and 4.68% fewer YJIT instructions at 1,000 rows, with passing A/A and unchanged allocations. No whole-request saving is established."
rank: 23
risky: true
state: in-review
note: "Fork pushed; skeptic approved code/body. The linked driver-cpu.md accompanies this item. Sol and Astra are coordinator-owned. No upstream action authorized. Fork has no CI checks; local suite passed."
passes:
  - {reviewer: skeptic, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-05, verdict: approve, open: "Publish the linked driver-cpu.md report before upstream use."}
---

# Fill multi-column statement rows at their known size

Each cell in a SQLite row goes through `rb_ary_store`, although the final column count is already known. Loading 20 ordinary records repeats the Array length work for every column.

Set a multi-column row's length once, then fill its cells. Keep `rb_ary_store` for single-column rows, where resizing first costs more. Values and frozen result rows stay the same.

Callgrind instructions per seven-column Active Record `select_all`, Ruby 4.0.9:

| Mode / rows | Before | After |
|---|---:|---:|
| Interpreter / 20 | 428,852 | 421,570 |
| YJIT / 1,000 | 7,549,104 | 7,195,944 |

---
<sub>Found through Lowrail, my performance research project: [driver CPU study](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/driver-cpu.md).</sub>
