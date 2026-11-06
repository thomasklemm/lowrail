---
id: DRV2
repo: sparklemotion/sqlite3-ruby
fork: thomasklemm/sqlite3-ruby
kind: perf
area: Multi-column result rows
reviewer: tenderlove
branch: thomasklemm/fill-multicolumn-rows
head: "10b25aa99e9c1778a6bfc35f661d5ab6f28ec42e"
base: main
built_on: "48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0"
depends_on: []
impact: "Every multi-column SQLite result row, including default Rails record loads. A complete 1,000-row seven-column model load (to_a, lazy attributes) uses 2.69% fewer YJIT instructions and 1.27% fewer interpreter instructions, with passing A/A and unchanged objects. Native row memory matches main on Ruby 3.2/3.3/3.4; no whole-request saving is established."
rank: 23
risky: true
state: in-review
note: "Corrected fork head passes the whole-model-load relevance gate in interpreter and YJIT. Skeptic confirmed native memory, correctness, final numbers and body; coordinator Sol/Astra pending. Single-column YJIT pluck has +0.0367% instruction overhead."
passes:
  - {reviewer: skeptic, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-05, verdict: approve, open: "Publish the linked driver-cpu.md report before upstream use."}
  - {reviewer: sol, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-06, verdict: nits, open: "Clarify seven-column query wording, SQLite version and the measured single-column scope."}
  - {reviewer: astra, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-06, verdict: changes, open: "Ruby 3.2/3.3 rb_ary_resize grows exactly-sized buffers; initialize the length without growing capacity and remeasure."}
  - {reviewer: skeptic, head: "10b25aa99e9c1778a6bfc35f661d5ab6f28ec42e", date: 2026-11-06, verdict: approve, open: "Correctness/native memory and final whole-model measurements/body confirmed; supporting evidence exported before handoff."}
---

# Fill multi-column statement rows at their known size

Each cell in a SQLite row goes through `rb_ary_store`, although the final column count is already known. Fetching 20 seven-column rows repeats the Array length work for every column.

Set a multi-column row's length once without growing its capacity, then fill its cells. Single-column rows keep their existing path. Values and frozen result rows stay the same.

Callgrind instructions per 1,000-row, seven-column Active Record load (`to_a`), Ruby 4.0.9:

| Mode | Before | After |
|---|---:|---:|
| Interpreter | 27,190,830 | 26,834,750 |
| YJIT | 13,019,464 | 12,667,677 |

These measurements use SQLite 3.40.1.

---
<sub>Found through Lowrail, my performance research project: [driver CPU study](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/driver-cpu.md).</sub>
