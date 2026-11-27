---
id: DUEL2
repo: sferik/duel-ruby
fork: thomasklemm/duel-ruby
kind: fix
area: Native::Linux#read (lib/duel/native.rb), its fake in test/native_test.rb
reviewer: sferik
branch: pread-perf-fd
head: "738d9ba605002b6383db3e6423dbb51c61cc9a91"
base: main
built_on: "a09111e"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Duel's instructions metric works wherever Linux offers the CPU's counters; before, every benchmark there errored with ESPIPE. Reproduced on GitHub ARM (4/4) and AWS Xeon (3/3) runners after the sysctl; with the fix, steady counts (52,204,137 per loop on ARM) and an end-to-end comparison of 0 errors."
evidence: [bench/upstream/duel_pread]
rank:
risky: false
state: in-review
pr:
note: "2026-11-27 built on sferik main a09111e as one commit 738d9ba (Thomas author and committer, no trailers), pushed to fork branch pread-perf-fd. Repro in bench/upstream/duel_pread. Coordinator delegated opening: open ready, maintainers can edit, once thermos-sol and Astra approve this head and body. Ownership check by hand 2026-11-27: Duel's 8 issues and PRs (all closed or merged) and history name no pread, ESPIPE or perf counter bug."
ownership: {date: 2026-11-27, checked: ["sferik/duel-ruby issues and PRs, open and closed, for pread, ESPIPE and perf_event"], hits: []}
passes: []
---

# Read the Linux counter with read(2), not pread(2)

Where Linux offers the CPU's counters, every benchmark errors with `Errno::ESPIPE: Illegal seek` at `native.rb:78:in 'IO#pread'`: a perf_event_open(2) file can't seek, so pread(2) always fails on it. I hit it on GitHub's ARM runners, and on the x86 ones that land on AWS, after `sudo sysctl kernel.perf_event_paranoid=2`. With read(2), a one-benchmark comparison there gives `instructions 1.000 [1.000, 1.000] same`, and a 100,000-iteration loop counts 52,204,137 instructions on every read.

The tests' fake counter is now a pipe, which can't seek either, so two of them fail without the fix. Tests, lint, typecheck and mutant on the changed subject are green.
