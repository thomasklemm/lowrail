---
id: DUEL2
repo: sferik/duel-ruby
fork: thomasklemm/duel-ruby
kind: fix
area: Native::Linux#read (lib/duel/native.rb), its fake in test/native_test.rb
reviewer: sferik
branch: pread-perf-fd
head: "90bf2a51884219cc29c59331cfc5afc9aa97fe9f"
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
state: reviewed
pr:
note: "2026-11-27 thermos-sol and Astra delta confirms approve 90bf2a5 and the body, reviewed. 2026-11-27 90bf2a5: both reviewers asked for changes on 738d9ba, applied with thermos-sol's text: the fake creates its pipe only when the syscall succeeds and closes the writer (Astra and thermos-sol showed 2 leaked fds per test_linux_unavailable run), body replaced (no numbers, sysctl or check list; 'every read' and 'every benchmark' were wrong), commit message replaced; suite 927/0, 100% coverage, mutant 16/16, lint and typecheck clean; delta confirms requested. 2026-11-27 built on sferik main a09111e as one commit 738d9ba (Thomas author and committer, no trailers), pushed to fork branch pread-perf-fd. Repro in bench/upstream/duel_pread. Coordinator delegated opening: open ready, maintainers can edit, once thermos-sol and Astra approve this head and body. Ownership check by hand 2026-11-27: Duel's 8 issues and PRs (all closed or merged) and history name no pread, ESPIPE or perf counter bug."
ownership: {date: 2026-11-27, checked: ["sferik/duel-ruby issues and PRs, open and closed, for pread, ESPIPE and perf_event"], hits: []}
passes:
  - {reviewer: thermos-sol, head: "738d9ba605002b6383db3e6423dbb51c61cc9a91", date: 2026-11-27, orb: T-01a21d03-adbc-762b-9390-f7a4798ad07d, verdict: changes, open: "R1 fixture leaks pipe fds; R2 body overclaims and carries numbers, a command and a check list"}
  - {reviewer: astra, head: "738d9ba605002b6383db3e6423dbb51c61cc9a91", date: 2026-11-27, orb: T-01a21d03-bd3a-722e-8760-5c9ccdf997bc, verdict: changes, open: "same two findings"}
  - {reviewer: astra, head: "90bf2a51884219cc29c59331cfc5afc9aa97fe9f", date: 2026-11-27, orb: T-01a21d03-bd3a-722e-8760-5c9ccdf997bc, verdict: approve, open: none}
  - {reviewer: thermos-sol, head: "90bf2a51884219cc29c59331cfc5afc9aa97fe9f", date: 2026-11-27, orb: T-01a21d03-adbc-762b-9390-f7a4798ad07d, verdict: approve, open: none}
---

# Read the Linux counter with read(2), not pread(2)

When Linux can open the instruction counter, Duel's default instruction metric raises `Errno::ESPIPE: Illegal seek` because `pread(2)` cannot read the non-seekable perf fd. This reproduces on GitHub's ARM runners and AWS-backed x86 runners when counter access is enabled.

Use `IO#sysread(8)` to read the current count without Ruby's IO buffering. The test fake is now a pipe, so the existing count assertions catch positional reads without requiring hardware counters.
