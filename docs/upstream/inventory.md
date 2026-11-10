# Upstream inventory (snapshot 2026-11-10)

Snapshot of every Lowrail upstream PR, built from `script/pr-queue sync`/`status` and a GitHub search of
Thomas's PRs (Argos, Roundhouse and personal repos excluded). Per-PR detail stays in
[contributions](contributions.md) and `bench/upstream/pr-queue/items/`; this page is the overview and the
priority list. Replace it rather than append when it is redone.

## What happened since 2026-11-01

- About 70 Lowrail PRs merged (GitHub search, 2026-11-01 to 11-10). Most of them are rails/rails, 11-02 to
  11-05 (perf rounds, API restores, AR-4, SU1). Since 11-06: #59676 E4 (minitest, 11-07), #59629 AR-1
  (`find_template`, 11-09); ruby/ruby #19620 (3.4 backport), #19648; ruby-bench #564–#568; graphql-ruby
  #5877/#5880/#5881; ransack #1792 G1 and #1795 RA1, both released in ransack 6.1.0.
- Reverted or reworked by maintainers: #59584 (byroot reverted it in #59713: we only measured small documents,
  and the path is for Ruby ≤ 4.0); #59640 SU1 (byroot simplified the key in #59714).
- Closed without merging: #59660 OP3 (no case for a public `validation_context=`; heads-up posted on
  ancestry#770), #59667 DC1 (superseded by seanpdoyle's merged #50312), #59630 R1, #59663 ZM1, the PM1/PM3/CB2
  parked ideas.
- Issues: rubygems#10017 fixed by rubygems#10047; herb#2892 opened (blank line kept next to comment tags,
  compared with Erubi).

## Open PRs

### rails/rails: 13 non-draft (cap 15), 4 drafts

| PR | ID | State | Next |
| --- | --- | --- | --- |
| #59642 | CW1 | ready, option B at matthewd's request | wait for merge |
| #59671 | E2 | ready (stacked on E2b) | on merge, ping ransack#1799 (scarroll32 asked) |
| #59644 | CW2 | ready | wait |
| #59564 | PR59564 | ready, tenderlove objected | **close** (rework gain within noise, see rails-open-evidence) |
| #59565, #59569, #59609, #59611, #59617, #59621 | various | ready since 11-03/11-04 | wait |
| #59574, #59627, #59628 | deprecation/restore | ready since 11-03/11-04 | audit against the internal-API rule (matthewd, seanpdoyle) |
| #59662 | OP8 | draft, all gates green on 490fdf855b | **mark ready** (slot free) |
| #59668 | E2b | draft, base of E2 | claude-code pass, then ready |
| #59661 | OP1 | draft | claude-code pass |
| #59675 | UG82 | draft, five notes on 3428a0ee53 | claude-code pass on the new Herb note |

### ruby/ruby: 5 open (no room)

#19487 and #19492 approved, #19659, #19670, #19681. Wait; no nudge without Thomas.

### ruby-bench: 5 ready, 1 draft

#569, #570, #571, #572 (two fixed-clock options, both kept on purpose), #574 RB-PV, draft #575 RBW1 (blog
benchmark, question to maintainers). No maintainer reaction yet; all CI green.

### Drivers and central gems

| Repo | PRs | State |
| --- | --- | --- |
| sqlite3-ruby | #773 DRV6 (CI fixes), #769 DRV1, #770 DRV2 | ready; after #773 merges, rebase #769/#770 |
| ruby/bigdecimal | #562 | tompng asks to move the zero shortcut into `rb_inum_convert_to_BigDecimal`: rework |
| rack | #2550 K1 | ready since 11-04 |
| nokogiri | #3759 N1 | ready since 11-05 |
| ruby/date | #199 | ready since 11-04 |
| ruby-i18n/i18n | #763–#766 | ready since 11-03, over the no-response cap |
| tzinfo | #171 TZ2, #175 TZ1 | ready since 11-05, at the cap |
| rails/propshaft, rails/importmap-rails | #289, #336 | ready since 11-03/11-05 |
| inertia-rails | #435, #436, #437, #441, #442 | ready since 10-20/11-03 |
| rubocop-performance, rubocop-rails | #550, #551, #552; #1670 | ready since 10-22/11-03 |
| tapioca, rack-mini-profiler, rails_vite | #2748, #670, #57 | ready |
| cells-rails | #75 (NavigationHelper) | ready |
| discourse, scimitar, with_advisory_lock, lago-expression | #45658, draft #172, draft #150, #91 | as recorded |

Ping rule (DECISIONS): one short ping only after four weeks without any maintainer reaction. First due:
inertia-rails #435/#436 and tapioca #2748 (opened 10-20) on 11-17; rubocop-performance #551/#552 on 11-19.

## Priorities

1. **Decisions only, no tokens:** close #59564; mark OP8 ready.
2. **Small reworks a maintainer asked for, Medium orb:** bigdecimal #562 (tompng).
3. **Event-driven, no work until then:** E2 merge → ransack#1799 ping; #773 merge → rebase #769/#770;
   herb#2892 reply → answer only what is asked.
4. **Audit, Medium orb, read-only:** #59574, #59627, #59628 against "we don't deprecate internal APIs";
   close what fails it before a maintainer has to say so.
5. **Gates for the next slots:** claude-code passes for E2b (then ready, so E2 merges cleanly), UG82, OP1.
   Only when Claude Code tokens are available.
6. **Bets, later:** Rails main write path (+11% AR/AM/Arel calls on a POST, `schema_context` and the lazy
   query cache unjudged); Turbo/Solid Queue after-commit cost measured with the blog benchmark; ZJIT Z13/E2.

Lesson from #59584: string-scanning changes need a benchmark with inputs that don't fit in CPU caches, not
only small documents.
