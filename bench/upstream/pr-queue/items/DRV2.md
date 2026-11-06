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
impact: "The original Ruby 4.0.9 head improves select_all, but grows native row buffers on Ruby 3.2/3.3. Held until a corrected head moves a whole model load or external benchmark beyond A/A; select_all alone does not satisfy the relevance gate."
rank: 23
risky: true
state: held
note: "Astra found supported-Ruby native-buffer growth. The rb_ary_store length-initialization replacement matches main's retained row memory at 18 widths on Ruby 3.2/3.3/3.4; a fresh whole-model-load cohort is running. No opening based only on select_all."
passes:
  - {reviewer: skeptic, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-05, verdict: approve, open: "Publish the linked driver-cpu.md report before upstream use."}
  - {reviewer: sol, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-06, verdict: nits, open: "Clarify seven-column query wording, SQLite version and the measured single-column scope."}
  - {reviewer: astra, head: "36d6e1a3bf8142b267cd1c1e405313ab4bbb8c0b", date: 2026-11-06, verdict: changes, open: "Ruby 3.2/3.3 rb_ary_resize grows exactly-sized buffers; initialize the length without growing capacity and remeasure."}
---

# Fill multi-column statement rows at their known size

Each cell in a SQLite row goes through `rb_ary_store`, although the final column count is already known. Fetching 20 seven-column rows repeats the Array length work for every column.

Set a multi-column row's length once without growing its capacity, then fill its cells. Single-column rows keep their existing path. Values and frozen result rows stay the same.

These measurements use SQLite 3.40.1.

---
<sub>Found through Lowrail, my performance research project: [driver CPU study](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/driver-cpu.md).</sub>
