---
id: TWZ1
repo: rails/rails
kind: perf
area: Active Support, TimeWithZone
reviewer: pixeltrix
branch: thomasklemm/twz-reuse-local-period
head: "ba1f3642141a85d94a926487ab359b455292013e"
base: main
built_on: "1e235cee11b0a7aecb189d8837534807626287aa"
depends_on: []
stacked_on:
alternative_of:
impact: one TZInfo lookup fewer per calendar operation that crosses a DST change; lobsters /threads −2.85% instructions per request on a crossing date (A/A 0.07%), none otherwise
rank:
risky: true
state: held
pr:
note: "parked idea (coordinator 2026-11-06, DECISIONS 6c1439e): exact after four review rounds, measurable per request only on DST-crossing dates; rails/rails at the open cap. Thomas may pick it up after the 8.2 beta; needs Sol/Astra on this head first. Record: docs/upstream/ruby-bench-dst.md"
passes:
  - {reviewer: sol, head: "4779066d80", date: 2026-11-05, verdict: changes, open: "Julian DateTime picks another period; fixed"}
  - {reviewer: astra, head: "4779066d80", date: 2026-11-05, verdict: changes, open: "same Julian DateTime finding; fixed"}
  - {reviewer: sol, head: "33226e90c8", date: 2026-11-06, verdict: changes, open: "right/UTC local Time; periods_for_local shortcut; both fixed"}
  - {reviewer: astra, head: "33226e90c8", date: 2026-11-06, verdict: changes, open: "same two findings; fixed"}
  - {reviewer: skeptic, head: "2fab681937", date: 2026-11-06, verdict: nits, open: "commit message wording, applied in ba1f364214 (same tree)"}
---

# Don't look the same local time up twice when a TimeWithZone crosses a DST change

When `70.days.ago`, `beginning_of_day`, `change` or another calendar method returns a time in a different period than the receiver, for example on the other side of a DST change, `TimeWithZone` asks TZInfo for the periods of the new local time and sees that the receiver's period isn't among them. It then passes nil to the constructor, which looks the same local time up in TZInfo again. Apps in a zone with DST pay this on every lookback that crosses a change, and a 70-day lookback crosses one on about 40% of days. In Ruby's lobsters benchmark, set to US Central time, a `/threads` page does 131 of these repeated lookups.

With this change, when the new time is a UTC `Time` with exactly one period, that period is passed on: the constructor would look up the same object in the same zone. Other values (`DateTime`s, times with an offset, zones without transitions) and gaps and overlaps keep the existing path, so callers get the same results.

| Ruby 4.0.9, Callgrind instructions | before | after |
| --- | ---: | ---: |
| lobsters `/threads` request, on 2026-11-05 | 106.6M | 103.5M (−2.9%) |
| `70.days.ago` across a DST change | 83,549 | 60,583 |
| `beginning_of_day` on the day clocks go back | 63,647 | 39,622 |
| `70.days.ago` without a DST change | 66,635 | 66,635 |
