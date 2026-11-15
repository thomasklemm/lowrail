# ZJIT: Symbol block arguments and Symbol block handlers (bet ZS1)

2026-11-15. `foo(&:sym)` under ZJIT: the send falls back to the generic `rb_vm_send`
(`send_fallback_send_block_arg_not_nil` for an ISEQ callee), and every `yield` to the Symbol handler goes through the
generic block invocation. ZS1 was to make ZJIT handle it and prepare one ruby/ruby PR
([DECISIONS](../DECISIONS.md), ruby/ruby exception of 2026-11-15).

**Result: measured, not built, nothing opened.** Both halves already exist as unmerged branches of Shopify's ZJIT
contributors, without a PR, and the half that was ours to build is too small:

* The send to an ISEQ callee, which is what a change shaped like ruby/ruby#18180 covers, costs at most
  **0.12%** of instructions on railsbench, lobsters, shipit and a blog page, on Rails 8.1 and on Rails main with
  VB1, in every cell that passed the JIT-flat gate (the blog page on Rails 8.1 did not). That is below the 0.3% bar
  set for building it. The same send to a C callee costs at most 0.28%.
* The `yield` to a Symbol handler costs more: at most 0.69% from a Ruby-level `yield` (the part
  k0kubun's row 17 covers) and 0.43% from `rb_yield` in C methods (covered by nobody).
* These are ceilings: the whole generic dispatch, with nothing subtracted for what a specialized send still costs.

**Decision (2026-11-15): ZS1 is closed without building.** The send side is not built, rows 17 and 56 are not
ported, and the C-level yield is not taken up as a bet ([recommendation](#recommendation)).

## Existing work (checked 2026-11-15)

* [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014) "ZJIT: Specialize send with non-nil block arg":
  open, no assignee. dak2's comment lists "Symbol block args (&:foo)" as a later step. tekknolagi asked on
  2026-11-06 "Is this done now that Alan added the PR?"; that refers to ruby/ruby#18180 itself, which
  alanwu-shopify-inc connected to the issue on 2026-09-23. Nobody answered.
* Merged: [ruby/ruby#18180](https://github.com/ruby/ruby/pull/18180) (dak2, a profiled exact `Proc` block argument
  becomes the callee's specval in a `SendDirect`), [#19077](https://github.com/ruby/ruby/pull/19077) (dak2, inlining
  with a `&proc` argument), [#19484](https://github.com/ruby/ruby/pull/19484) (ours, callees with `&block`).
* [ruby/ruby#17852](https://github.com/ruby/ruby/pull/17852) (tekknolagi, merged 2026-11-09) only removed the
  `invokeblock_handler_*` and blockparamproxy profile counters. k0kubun wrote there: "I think we're pretty much done
  with handling different block handler types in invokeblock and getblockparamproxy today".
* **Yield side, unmerged:** `k0kubun/ruby:zjit-lobsters7`, the branch behind
  [Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039) (83 commits on master `2db3072cfb`, tip
  `896164e413`, 2026-09-02). Both rows have an empty assignee column, and k0kubun's only open PR is #19617.
  * Row 17, `ed1c0f97b2` "Compile a `yield` to a Symbol block as the send it stands for" (+418 −50): compares the
    block handler with the profiled static Symbols, emits an ordinary `Send` of the Symbol's method on the first
    yielded value and lets `type_specialize` resolve it; what does not resolve turns back into `invokeblock`. His
    lobsters delta: +0.05%. His message counts 540K of 1.22M `rb_vm_invokeblock` calls per lobsters run with a Symbol
    handler.
  * Row 56, `c6347abcc4` "Dispatch a Symbol block's send through the megamorphic class table" (+676 −61, touches
    `vm_insnhelper.c`): for receivers the profile cannot resolve. It also fixes row 17 letting a protected method
    through. His lobsters delta: −0.77%, listed among the largest regressions.
* **Send side, unmerged:** `Shopify/ruby:zjit-perf/blockarg-direct-send` (Rafael França, `3f17d8950e` "ZJIT:
  Directly send non-nil block arguments", 2026-09-11, +574 −201, on master `b39c8f70d9`; the Z13 thread found it). A
  static Symbol block argument, statically known or profiled and guarded, becomes a direct send to ISEQ and C
  callees. A new `rb_vm_block_handler_from_blockarg()` does the conversion at run time, refinements included, behind
  a `Symbol#to_proc` patch point. Its summary file says the yields stay `invokeblock_not_specialized`. No PR was
  opened from it; Rafael's ruby/ruby PRs since are on other topics.
* No open ruby/ruby or Shopify/ruby PR mentions Symbol block arguments or Symbol block handlers (searched symbol
  block, Symbol block arg, sym to_proc zjit, SendBlockArgNotNil, invokeblock symbol, block arg zjit).
* YJIT falls back at the same sends (`exit_if_unsupported_block_arg_type`, counter `send_iseq_block_arg_type`), so
  this is not part of the ZJIT−YJIT gap ([zjit-yjit-gap](zjit-yjit-gap.md)).

## The paths in the VM (master `3be2b028a7`)

* **(a) The send.** `vm_caller_setup_arg_block` keeps a Symbol as the block handler when `Symbol#to_proc` is not
  redefined; with refinements in the caller's cref it builds or looks up a lambda instead. ZJIT's `type_specialize`
  handles a nil and a profiled Proc block argument; a Symbol to an ISEQ callee gets `SendBlockArgNotNil`, and to a C
  callee the send stays generic as well. Either way the JIT code calls `rb_vm_send`: block handler setup and method
  search, and for an ISEQ callee an interpreter frame and `vm_exec` with its `setjmp`.
* **(b) A Ruby-level `yield`.** `invokeblock` reaches `vm_invoke_symbol_block`, which calls `vm_call_symbol` with a
  call info and call cache built on the stack, so the method is looked up on every yield. ZJIT calls
  `rb_vm_invokeblock` for it.
* **(c) A C method's `rb_yield`.** `vm_yield_with_symbol` calls `rb_sym_proc_call`, which is
  `rb_funcall_with_block_kw` on the first yielded value: again a lookup per element.
* **(d) A callee with `&block`.** `getblockparamproxy` on a Symbol handler calls `rb_sym_to_proc` (cached per
  Symbol) and memoizes the Proc in the frame. ZJIT already compiles this (`gen_getblockparam`, `known_symbol`).

With a JIT enabled, `Array#each`, `map`, `select` and `find` are defined in Ruby (`with_jit` in `array.rb`), and
`Kernel#tap` and `then` always are. So under ZJIT `ids.map(&:to_s)` is a send to an ISEQ callee, path (a), followed
by one path (b) yield per element. `reject`, `any?`, `uniq`, `flat_map`, `Hash#transform_values` and the rest stay C
methods: a generic send to a C callee and one path (c) yield per element.

## Method and pins

* **Ruby** master `3be2b028a7` (2026-11-15), `--enable-yjit --enable-zjit --disable-install-doc`, GCC 14.2.0, rustc
  1.100.0, release build, `--zjit` with default options. Measurement build: the same commit plus
  [`zs1_symbol_block.patch`](../../bench/upstream/zs1_symbol_block.patch) (below).
* **ruby-bench** `73918b2` with `reaping_frequency: 0` and `verify_timeout: 1000000` in the three apps'
  `database.yml`, as in [zjit-yjit-gap](zjit-yjit-gap.md). Iteration = 2,000 requests (railsbench) or one pass over
  the generated routes (lobsters, shipit).
* **Rails 8.1:** what ruby-bench bundles, 8.1.1 for railsbench and lobsters, 8.1.2 for shipit.
* **Rails main + VB1:** `thomasklemm/rails` `5796a82a82` (rails/rails#59803's head, one commit on main
  `8217632cf8`, 8.2.0.alpha) by path. The copy needs what the Z13 thread found: `gem "prism"`, `load_defaults "8.1"`
  (the 8.2 defaults turn on Herb, which rejects two templates), a shipit-engine 0.45.0 copy whose `ReviewStack` no
  longer reopens the frozen `model_name`, and the typedstore initializer
  [`census_typedstore_rails_main.rb`](../../fixtures/corpus/ruby-master-round-2/census_typedstore_rails_main.rb)
  for lobsters.
* **App page:** `GET /articles/1` of the corpus blog (`.corpus/real-blog-r4`: an article with two comments, a
  form and Turbo tags) in production mode, logging to a file, 500 requests per iteration; Rails 8.1.4 and Rails
  main + VB1.
* **Counts:** 150 warmup iterations, then 10 counted, per iteration. The patch counts at run time, in the
  interpreter and in the functions ZJIT's fallbacks call, so interpreted and compiled code are both covered:
  * a send whose block handler is a Symbol, in `vm_sendish` after the method is resolved, keyed by callee type,
    callee, Symbol and call site, and by whether the Symbol came from a `&sym` argument or was forwarded;
  * a block invocation with a Symbol handler, in `vm_invoke_symbol_block` (a Ruby-level `yield`) and
    `vm_yield_with_symbol` (C), keyed by the yielding method, the method the Symbol resolves to and the call site.
* **Ceilings:** Callgrind (the pinned 3.19.0 of `script/bench-valgrind`), `--instr-atstart=no
  --smc-check=all-non-file`, `RUBY_GC_HEAP_INIT_BYTES=33554432`, GC counted. After 150 warmup iterations and the
  JIT-flat gate ([bench.md](../bench.md): compile and invalidation counters unchanged over two consecutive warm
  windows and over every measured window), one process measures an empty window, a whole-program window and four
  region windows of 2 iterations each. In a region window `CALLGRIND_TOGGLE_COLLECT` keeps collection on only
  * from the start of a send with a Symbol block argument (`vm_caller_setup_arg_block`) until the send returns, or
  * from the start of a Symbol-handler block invocation until it returns,

  and turns it off while the called method's body runs (`vm_exec` and the C function invokers). What is left is the
  dispatch: block handler setup, method search, argument and frame setup, `vm_exec`'s `setjmp`. Regions left by a
  non-local jump are counted; there were none.
* **Check of the regions:** on railsbench, lobsters and shipit the number of regions entered per iteration equals
  the runtime count for that class in every run; on the blog page it is 2 to 8 higher. On
  a micro (10,000 calls) a send with `&:sym` to an ISEQ callee is 331 Ir interpreted and 400 Ir from ZJIT code, a
  Ruby-level yield to a Symbol 633 / 707 Ir, and an `rb_yield` to a Symbol 715 Ir. That agrees with
  [lead 7c](zjit-leads.md#lead-7-block-arguments-other-than-nil-or-a-proc) (384–426 Ir per `&:value!` call saved
  by a block literal) and with the Z13 micro (about 400 Ir per send, about 700 per yield).
* **A/A:** every Callgrind cell ran twice in separate processes. The whole iteration repeats within 0.1% and every
  share within 0.006 percentage points, except where a GC falls into one run's window and not the other's (shipit
  on Rails main + VB1: 2.4% and 0.009 points).

## Counts

Per iteration, ZJIT. No Symbol handler was forwarded (`&blk`, `super`), and no callee was a bmethod.

**Rails 8.1**

| per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| all sends | 15,196,422 | 7,124,461 | 14,696,002 | 10,198,026 |
| dynamic sends | 1,075,941 | 786,523 | 1,871,769 | 659,504 |
| `send_block_arg_not_nil` | 119,999 | 94,975 | 207,915 | 80,001 |
| **Symbol block sends** | 18,043 | 18,166 | 38,798 | 12,500 |
| to an ISEQ callee | 10,013 | 4,022 | 9,141 | 7,500 |
| of those, a core iterator written in Ruby | 10,013 | 4,022 | 7,627 | 7,500 |
| to a C callee | 8,030 | 14,144 | 29,657 | 5,000 |
| share of all sends | 0.12% | 0.25% | 0.26% | 0.12% |
| share of dynamic sends | 1.68% | 2.31% | 2.07% | 1.90% |
| ISEQ callees as a share of `send_block_arg_not_nil` | 8.34% | 4.23% | 4.40% | 9.38% |
| **Symbol handler yields** | 21,300 | 34,601 | 67,553 | 17,000 |
| from a Ruby `yield` (`invokeblock`) | 15,300 | 19,809 | 41,401 | 9,000 |
| from C (`rb_yield`) | 6,000 | 14,792 | 26,152 | 8,000 |
| `rb_vm_invokeblock` calls from ZJIT code | 344,998 | 166,824 | 411,684 | 198,002 |
| Symbol yields as a share of them | 4.43% | 11.87% | 10.06% | 4.55% |

**Rails main + VB1**

| per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| all sends | 15,234,208 | 7,344,049 | 14,956,753 | 11,097,005 |
| dynamic sends | 891,136 | 754,077 | 1,747,257 | 778,501 |
| `send_block_arg_not_nil` | 92,610 | 28,159 | 140,099 | 56,000 |
| **Symbol block sends** | 19,961 | 11,870 | 23,084 | 11,000 |
| to an ISEQ callee | 9,987 | 3,006 | 8,147 | 6,500 |
| of those, a core iterator written in Ruby | 9,987 | 2,984 | 6,229 | 6,500 |
| to a C callee | 9,974 | 8,864 | 14,937 | 4,500 |
| share of all sends | 0.13% | 0.16% | 0.15% | 0.10% |
| share of dynamic sends | 2.24% | 1.57% | 1.32% | 1.41% |
| ISEQ callees as a share of `send_block_arg_not_nil` | 10.78% | 10.68% | 5.82% | 11.61% |
| **Symbol handler yields** | 15,248 | 18,984 | 30,737 | 12,500 |
| from a Ruby `yield` (`invokeblock`) | 7,274 | 9,497 | 16,571 | 3,500 |
| from C (`rb_yield`) | 7,974 | 9,487 | 14,166 | 9,000 |
| `rb_vm_invokeblock` calls from ZJIT code | 228,125 | 137,743 | 232,147 | 125,501 |
| Symbol yields as a share of them | 3.19% | 6.89% | 7.14% | 2.79% |

The Rails main + VB1 numbers agree with the Z13 thread's static count
([zjit-yjit-gap](zjit-yjit-gap.md#symbol-block-arguments-on-rails-main-after-vb1)) where they overlap: Symbol sends
to ISEQ callees 9,987 / 3,006 / 8,147 here against 9,987 / 2,588 + 458 mixed / 8,017 + 1,602 mixed there, and
yields in the Ruby-level iterators 7,274 / 9,475 / 14,653 against 7,274 / 9,475 / 12,200 (its probe covered six
methods).

Rails main has already removed the two largest Rails 8.1 sites: `ActiveRecord::Result#initialize`'s
`each(&:-@)` (result.rb:110: 12,000 yields per iteration on railsbench, 10,126 on lobsters, 30,512 on shipit) and
`resolve_attribute_name`'s `fetch(name, &:itself)` (attribute_methods.rb:397: 4,484 on lobsters, 10,798 on shipit).

### Top call sites, Rails main + VB1

Sends per iteration; file names are Rails' unless a gem is named.

| | sends to an ISEQ callee | sends to a C callee |
| --- | --- | --- |
| railsbench | `tap(&:start_session)` asynchronous_queries_tracker.rb:37, `each(&:call)` execution_context.rb:80 and `each(&:close!)` rack tempfile_reaper.rb:27, 2,000 each; `map(&:strip)` request_forgery_protection.rb:576 and rendering.rb:231, 1,987 each | `reject!(&:blank?)` tagged_logging.rb:91, `none?(&:dirty?)` transaction.rb:611 and `filter_map(&:ref)` rendering.rb:201, 2,000 each; `reject(&:blank?)` at the two `map(&:strip)` sites, 1,987 each |
| lobsters | `select(&:has_default?)` activerecord-typedstore typed_hash.rb:16, 359; `map(&:klass)`, `map(&:table_name)` and `each(&:run)` preloader/batch.rb:21–28, 233 / 223 / 223; `map(&:to_s)` relation.rb:1560, 210 | `none?(&:dirty?)` transaction.rb:611, 1,030; `reject(&:persisted?)` preloader/association.rb:264, 766; `delete_if(&:blank?)` enumerable.rb:309, 686 |
| shipit | `then(&:first)` singular_association.rb:52, 2,424; `with_connection(&:default_timezone)` integration.rb:208, 1,918 (the one sizeable callee that is not a core iterator); `map(&:to_param)` to_query.rb:57, 971; `map(&:to_s)` shipit github_app.rb:137, 787 | `reject(&:blank?)` enumerable.rb:209, 3,159; `delete_if(&:blank?)` enumerable.rb:309, 3,150; `none?(&:dirty?)` transaction.rb:611, 1,970; `transform_values!(&:to_param)` journey/formatter.rb:138, 1,420 |
| blog page | `map(&:message)` errors.rb:520 and `tap(&:compact!)` form_tag_helper.rb:123, 2,000 each (4 per request); `each(&:close!)`, `each(&:call)` and the two `map(&:strip)`, 500 each | `none?(&:dirty?)` transaction.rb:611, 1,000; `transform_keys(&:to_sym)` event_reporter.rb:680, `any?(&:present?)` turbo-rails streams_helper.rb:57, `filter_map(&:ref)` and the two `reject(&:blank?)`, 500 each |

Yields per iteration:

| | from a Ruby-level `yield` | from C |
| --- | --- | --- |
| railsbench | `map(&:strip)` request_forgery_protection.rb:576, 3,974; `tap(&:start_session)`, 2,000; `map(&:body)` jbuilder collection_renderer.rb:28, 1,300 | `reject(&:blank?)` request_forgery_protection.rb:576, 3,974; `reject!(&:blank?)` tagged_logging.rb:91, 2,000; `filter_map(&:ref)` rendering.rb:201, 2,000 |
| lobsters | `select(&:has_default?)` typed_hash.rb:16, 6,821; `map(&:id)` lobsters stories_paginator.rb:31–36, 3 × 280 | `uniq(&:__id__)` preloader/association.rb:109, 3,280; `reject(&:run?)` preloader/branch.rb:77, 466 |
| shipit | `map(&:to_s)` github_app.rb:137, 3,094; `then(&:first)`, 2,424; `map(&:to_param)` to_query.rb:57, 2,384; `with_connection(&:default_timezone)`, 1,918; `map(&:last)` indexed_row.rb:241, 1,504 | `reject(&:blank?)` enumerable.rb:209, 2,480; `delete_if(&:blank?)` enumerable.rb:309, 3,006; `sort_by!(&:first)`, 1,504; `transform_values!(&:to_param)` journey/formatter.rb:138, 2,264 |
| blog page | `tap(&:compact!)` form_tag_helper.rb:123, 2,000; `map(&:strip)`, 1,000; `tap(&:start_session)`, 500 | `transform_keys(&:to_sym)` event_reporter.rb:677 and :680, 6,500; `reject(&:blank?)`, 1,000 |

## Ceilings

Callgrind instructions per iteration spent in the generic dispatch, and their share of the whole iteration.

**Rails 8.1**

| Ir per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| whole iteration | 4,858,745,928 | 3,268,646,021 | 3,775,535,762 | rejected |
| send with `&:sym`, ISEQ callee | 3,704,849 (**0.076%**) | 1,470,943 (**0.045%**) | 4,026,240 (**0.107%**) | rejected |
| send with `&:sym`, C callee | 2,886,800 (**0.059%**) | 5,084,539 (**0.156%**) | 10,650,194 (**0.282%**) | rejected |
| yield to a Symbol, Ruby-level `yield` | 9,481,400 (**0.195%**) | 12,890,436 (**0.394%**) | 26,121,010 (**0.692%**) | rejected |
| yield to a Symbol, from C | 4,290,000 (**0.088%**) | 9,102,345 (**0.278%**) | 16,342,796 (**0.433%**) | rejected |
| both sends | 0.136% | 0.201% | 0.389% | rejected |
| both yields | 0.283% | 0.673% | 1.125% | rejected |
| Ir per send, ISEQ / C callee | 370 / 360 | 366 / 359 | 440 / 359 | rejected |
| Ir per yield, Ruby / C | 620 / 715 | 651 / 615 | 631 / 625 | rejected |
| regions per iteration (masks 1 / 2 / 4 / 8) | 10,013 / 8,030 / 15,300 / 6,000 | 4,022 / 14,144 / 19,809 / 14,792 | 9,141 / 29,657 / 41,401 / 26,152 | rejected |
| A/A, whole iteration | −0.006% | −0.026% | +0.091% | rejected |
| A/A, largest difference of a region's Ir | 0.422% | 0.005% | 1.359% | rejected |
| A/A, largest difference in share (points) | 0.0008 | 0.0001 | 0.0055 | rejected |
| JIT-flat gate, run a / b | pass / pass | pass / pass | pass / pass | fail / fail |
| GCs per window, run a / b | 2 / 2 | 1 / 1 | 1 / 1 | rejected |

**Rails main + VB1**

| Ir per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| whole iteration | 3,930,768,489 | 2,986,340,840 | 3,194,838,799 | 2,643,771,900 |
| send with `&:sym`, ISEQ callee | 3,711,151 (**0.094%**) | 1,096,894 (**0.037%**) | 3,829,983 (**0.120%**) | 2,621,444 (**0.099%**) |
| send with `&:sym`, C callee | 3,586,640 (**0.091%**) | 3,188,198 (**0.107%**) | 5,372,590 (**0.168%**) | 1,810,852 (**0.068%**) |
| yield to a Symbol, Ruby-level `yield` | 4,619,774 (**0.118%**) | 6,648,488 (**0.223%**) | 11,758,800 (**0.368%**) | 2,485,410 (**0.094%**) |
| yield to a Symbol, from C | 5,850,760 (**0.149%**) | 6,114,863 (**0.205%**) | 9,741,584 (**0.305%**) | 6,799,636 (**0.257%**) |
| both sends | 0.186% | 0.143% | 0.288% | 0.168% |
| both yields | 0.266% | 0.427% | 0.673% | 0.351% |
| Ir per send, ISEQ / C callee | 372 / 360 | 365 / 360 | 470 / 360 | 403 / 402 |
| Ir per yield, Ruby / C | 635 / 734 | 700 / 645 | 710 / 688 | 709 / 756 |
| regions per iteration (masks 1 / 2 / 4 / 8) | 9,987 / 9,974 / 7,274 / 7,974 | 3,006 / 8,864 / 9,497 / 9,487 | 8,147 / 14,937 / 16,571 / 14,166 | 6,502 / 4,505 / 3,506 / 9,000 |
| A/A, whole iteration | +0.060% | −0.026% | −2.425% | +0.021% |
| A/A, largest difference of a region's Ir | 0.866% | 0.109% | 0.457% | 1.595% |
| A/A, largest difference in share (points) | 0.0011 | 0.0003 | 0.0090 | 0.0025 |
| JIT-flat gate, run a / b | pass / pass | pass / pass | pass / pass | pass / pass |
| GCs per window, run a / b | 1 / 1 | 1 / 1 | 0–1 / 0–1 | 1 / 1 |

* The table shows run a; the A/A rows compare it with run b. "Regions per iteration" equals the runtime counts
  above on the three ruby-bench apps.
* GCs are counted. The windows of one cell contain the same number of GCs in both runs, except shipit on Rails
  main + VB1: run a's whole-program window has one GC and run b's none. That is the 2.4% there; run b's shares are
  0.123% / 0.172% / 0.376% / 0.314%.
* The blog page on Rails 8.1 is a rejected cohort ([below](#reading)).

## Reading

* **Send to an ISEQ callee: 0.04–0.12%.** This is all a change shaped like #18180 would touch (guard the Symbol,
  check `Symbol#to_proc` and the cref's refinements, pass the Symbol as the callee's specval). It is below 0.3% in
  all seven gated cells, and it is a ceiling: each send costs 365–470 Ir in the generic path, and a direct send
  still pays for its frame. Nearly all of these callees are the core iterators written in Ruby (`each`, `map`,
  `select`, `tap`, `then`; `with_connection` on shipit is the exception). Their `yield` stays generic afterwards,
  so the send alone would speed up the smaller half of `ids.map(&:to_s)`.
* **Send to a C callee: 0.06–0.28%.** Master has no block-argument path to a C callee at all, not for a Proc
  either (`BlockArgProc is only built for ISEQ callees`). k0kubun's branch adds one (`fd713176a1` "Pass a `&blk`
  argument through to a direct C call"), and Rafael's branch sends Symbols to C callees directly. So this is not
  the small first step. Both sends together reach 0.39% on shipit with Rails 8.1 and 0.29% with Rails main; every
  other cell is at or below 0.2%.
* **Yield from a Ruby-level `yield`: 0.09–0.69%.** This is what row 17 compiles and row 56 extends. It clears 0.3%
  on lobsters and shipit with Rails 8.1 and on shipit with Rails main. Each yield costs 620–710 Ir, mostly the
  method lookup `vm_call_symbol` repeats. k0kubun measured +0.05% (row 17) and −0.77% (row 56) on lobsters on his
  branch, where this ceiling is 0.39% on Rails 8.1.
* **Yield from C: 0.09–0.43%.** No branch covers it, and the JIT does not see it: the cost is inside the C
  method's `rb_yield`, in `vm_yield_with_symbol` and `rb_funcall_with_block_kw`, 615–756 Ir per element with a full
  method lookup each time. A fix would be in the VM and would help the interpreter and YJIT as well. Only the
  ceiling is measured here.
* **Rails main halves the yields.** It dropped the two largest Rails 8.1 sites, so on Rails main the yields from C
  are as large as the ones from Ruby.
* **Rejected cohort.** The blog page on Rails 8.1 failed the JIT-flat gate in both runs: after 150 warmup
  iterations and two flat warm windows, ZJIT compiled one more ISEQ and 12–28 side exits inside one or two of the
  five windows (run b; run a failed in two windows before the harness recorded which counter moved). Its shares, in
  the table's row order, were 0.096% / 0.063% / 0.188% / 0.182% and 0.095% / 0.064% / 0.187% / 0.189%. They are
  listed for the record and are not a result. Not rerun.

## Recommendation

Accepted on 2026-11-15; no queue item was created for ZS1.

1. **Do not build the send side.** Its ISEQ part is at most 0.12% as a ceiling, under the 0.3% bar in every gated
   cell. With C callees it reaches the bar only on shipit with Rails 8.1 (0.39%, ceiling), needs the C-callee block
   path master lacks, and is what Rafael França's `zjit-perf/blockarg-direct-send` already does.
2. **Rows 17 and 56 stay with k0kubun.** The Ruby-level yield ceiling is 0.09–0.38% on Rails main (0.20–0.69%
   on Rails 8.1), his own lobsters deltas are +0.05% and −0.77%, and the rows have no assignee and no PR.
3. **The C-level yields are not a bet.** Only their ceiling is measured (0.15–0.31% on Rails main).
4. **Close ZS1 with this record.** The ruby/ruby exception in DECISIONS stays unused. Nothing was opened or
   posted upstream, and no branch exists on `thomasklemm/ruby`.

An optional reply to tekknolagi's question on #1014, **not posted**; it answers a question asked there
([etiquette](../DECISIONS.md#upstream-etiquette)), Thomas decides:

> Not all of it: #18180 covers a profiled `Proc` and #19484 callees that declare `&block`. A Symbol block
> argument (`foo(&:sym)`) still falls back. On Rails main it is 6–11% of `send_block_arg_not_nil` on railsbench,
> lobsters and shipit, and the whole generic send costs 0.04–0.12% of instructions there (Callgrind), so it is a
> small item; the yields to the Symbol cost more than the sends.

## Reproduce

```sh
script/bench-valgrind ~/w/vg319brk
# Ruby master 3be2b028a7 into ~/w/rm; the same commit plus the patch into ~/w/rs, sharing ~/w/rm's gems
git apply bench/upstream/zs1_symbol_block.patch
../configure --prefix=$HOME/w/rs --enable-yjit --enable-zjit --disable-install-doc cppflags=-I$HOME/w/vg319brk/include
# bench/callgrind.c built as lowrail_callgrind.so in ~/w/cgext; a ruby-bench 73918b2 copy with
# harness/zs1.rb = bench/upstream/zs1_harness.rb
WARMUP_ITRS=150 MIN_BENCH_ITRS=10 bench/upstream/zs1_run.sh count lobsters zjit-lobsters ~/w/cnt81 --zjit --zjit-stats-quiet
WARMUP_ITRS=150 MEASURE_ITRS=2 FLAT_MAX_WINDOWS=20 bench/upstream/zs1_run.sh cg lobsters a-lobsters ~/w/cg81 --zjit
ruby bench/upstream/zs1_report.rb count ~/w/cnt81/zjit-lobsters.json
ruby bench/upstream/zs1_report.rb cg ~/w/cg81/a-lobsters.json
```
