---
id: DV1
repo: rails/rails
kind: perf
area: "Action Dispatch DebugView (debug exception and blocked host pages)"
reviewer: "byroot"
branch: thomasklemm/debug-view-cache-templates
head: "1a359ee5f90d1c06764f242918e43e4748f76f6e"
base: main
built_on: "088fc0cf61"
introduced_by: 58721
depends_on: []
stacked_on:
alternative_of:
impact: "DebugView#initialize builds ActionView::LookupContext.new(RESCUES_TEMPLATE_PATHS.dup), and PathSet typecasts a String path to a new FileSystemResolver, so every debug exception page and every HostAuthorization blocked-host page compiles all 8 rescue templates again and defines their methods on DebugView once more (800 methods per 100 pages on 8.1.4.1 and main). The generated test environment (show_exceptions :rescuable, consider_all_requests_local) renders that page for every rescuable exception in a request test. On main the 8.2 Herb default (#58721, unreleased) makes each compile heavier: with source extracts stubbed, 8,129 objects per page on 8.1.4.1, 15,834 on main, 4,518 with DV1. Found from the lowrail-profile field test's exception_wrapper lead. Reach (reach/SUMMARY.txt): 27 debug pages in 1,990 tests across nine census suites (thinkroom 13, campfire 10, writebook 3, fizzy 1, five apps 0), no blocked-host pages; well under a second per suite in total, so it does not move whole requests or suites."
evidence: [bench/upstream/rails_main_hotlines/field]
rank: 4
risky: false
pr:
state: held
note: "2026-11-27 (held, relevance): the coordinator asked for reach before review; suites render too few debug pages (27 in 1,990 tests) for the saving to show in suite time. Not reviewed, not opened; branch kept on the fork at 1a359ee5f9. Reopen if a suite is found that renders many debug pages (e.g. request specs asserting error pages) or if the DebugView method growth matters in long-running development processes. The upstream-bench body run was OOM-killed beside the suites and not rerun, since the item is held. 2026-11-27 (Rails 8.2 pre-beta round, field-test lead 3): built on main 088fc0cf61, 1 file +5/-2: DebugView.resolver memoizes one FileSystemResolver for RESCUES_TEMPLATE_PATHS.first and the lookup context uses it. Not PathRegistry.cast_file_system_resolvers: InfoController and MailersController prepend the same path into the controllers' compiled_method_container, and DebugView compiles into itself (PathSet#typecast's comment). Without template caching (development) Resolver#find_all skips the unbound-template map, so behaviour is unchanged there. No test: a perf change with no observable behaviour beyond method counts (DECISIONS: no internal-state assertions). Tests on head: actionpack debug_exceptions, host_authorization, exception_wrapper, show_exceptions 144 runs 0 failures; railties rails_info_controller_test 16, application/middleware/exceptions_test 17, 0 failures. Field-test leads 1 (CSP gsub, #59286) and 2 (Time#change Rational, #59323) are already fixed on main, unreleased: alloc_probe.rb, results.txt. Source extracts (error_highlight spot per frame, about 113k objects per page on both trees) not built: lazy extracts change the page; lead only. Body numbers: script/upstream-bench pending (pinned Valgrind building)."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #58721","open PRs naming resolver, initialize that change actionpack/lib/action_dispatch/middleware/debug_view.rb"], hits: []}
passes: []
---

# Compile the debug page's templates once

`ActionDispatch::DebugView` builds its lookup context from the rescue template path every time, so each debug exception page, and each page `HostAuthorization` renders for a blocked host, gets a new resolver with an empty template cache. Every such page compiles all its templates again and defines their methods on `DebugView` once more, so the class keeps growing. With the test environment's defaults this happens for every rescuable exception in a request test, and compiling through Herb makes each page more expensive than before.

This keeps one resolver for `DebugView`. It doesn't use the resolver `PathRegistry` shares with controllers for the same path, because those templates compile into a different class. Without template caching, as in development, templates are still looked up again for every page.
