---
id: TZ2
repo: tzinfo/tzinfo
fork: thomasklemm/tzinfo
kind: perf
area: ZoneinfoReader signed transition decoding
reviewer: philr
branch: thomasklemm/signed-zoneinfo-transitions-refresh
head: "57056ddd7f46f9c292e46687821636e812102c85"
base: master
built_on: "1207d6098d7f4a9f294a40801154990850f09bf1"
depends_on: []
stacked_on:
alternative_of:
impact: "whole synthetic TZif reads save 128 objects for 32 negative transitions and 12 for six signed boundaries; simpler decoder, no speed claim"
rank: 2
risky: false
state: ready
pr: 171
note: "prepared refresh only; live PR stays at 57c9c3ad35; Tests run 42121909175 passes 39/39 jobs, differential 42122136308 passes the current matrix, verified Windows x86 42122881130 passes; local 5597 named outcomes match; Ir cohort rejected at maximum A/A 0.1537%, no speed claim; Sol pending; coordinator applies the update"
passes:
  - {reviewer: skeptic, head: "57056ddd7f46f9c292e46687821636e812102c85", date: 2026-11-05, verdict: approve, open: "exact code and shortened body approved; no must-fix or body nit; recommends one update as a simpler file-load decoder, not an app-speed claim; record's skip wording corrected"}
---

# Decode signed 64-bit zoneinfo transition times directly

Reading TZif v2 and v3 files currently rebuilds each signed 64-bit timestamp from two unsigned words, allocating intermediate Integers for negative timestamps. This work happens when loading zoneinfo files, not on each timezone lookup.

This decodes the timestamp directly with `unpack('q>')[0]` and removes the unused private helper. Callers receive the same timestamps; the checked eight-byte read and the format-1 path are unchanged.

Objects allocated per complete synthetic-file read, Ruby 4.0.9 without a JIT:

| File | master | this PR |
|---|---:|---:|
| 32 negative transitions | 288 | 160 |
| Six signed boundaries | 72 | 60 |

This passes the fork's [CI on the current matrix](https://github.com/thomasklemm/tzinfo/actions/runs/42121909175).
