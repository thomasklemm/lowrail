# ZJIT: Symbol block arguments and Symbol block handlers (bet ZS1)

2026-11-15. `foo(&:sym)` under ZJIT: the send falls back to the generic `rb_vm_send`
(`send_fallback_send_block_arg_not_nil` for an ISEQ callee), and every `yield` to the Symbol handler goes through the
generic block invocation. ZS1 was to make ZJIT handle it and prepare one ruby/ruby PR
([DECISIONS](../DECISIONS.md), ruby/ruby exception of 2026-11-15).

**Status: reopened the same day and built.** The first round below measured Rails main with VB1
(rails/rails#59803) applied and closed ZS1 without building. skipkayhil then closed VB1 with "Let's fix this in
the JITs?", which changes the target, and ZS1 became a ruby/ruby PR on top of Rafael França's branch: see
[Reopened](#reopened-the-send-side-as-a-rubyruby-pr-2026-11-15). Everything from here to that section is the
first round's record, kept as written.

**First-round result: measured, not built, nothing opened.** Both halves already exist as unmerged branches of
Shopify's ZJIT contributors, without a PR, and the half that was ours to build is too small:

* The send to an ISEQ callee, which is what a change shaped like ruby/ruby#18180 covers, costs at most
  **0.12%** of instructions on railsbench, lobsters, shipit and a blog page, on Rails 8.1 and on Rails main with
  VB1, in every cell that passed the JIT-flat gate (the blog page on Rails 8.1 did not). That is below the 0.3% bar
  set for building it. The same send to a C callee costs at most 0.28%.
* The `yield` to a Symbol handler costs more: at most 0.69% from a Ruby-level `yield` (the part
  k0kubun's row 17 covers) and 0.43% from `rb_yield` in C methods (covered by nobody).
* These are ceilings: the whole generic dispatch, with nothing subtracted for what a specialized send still costs.

**First-round decision (2026-11-15, superseded): ZS1 is closed without building.** The send side is not built,
rows 17 and 56 are not ported, and the C-level yield is not taken up as a bet ([recommendation](#recommendation)).

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

## Reopened: the send side as a ruby/ruby PR (2026-11-15)

skipkayhil closed rails/rails#59803 (VB1) with ["Let's fix this in the
JITs?"](https://github.com/rails/rails/pull/59803#issuecomment-6895904455), so Rails main keeps
`cast_value(&:value!)` and `map(&:deep_dup)`, and the numbers above (Rails main with VB1) no longer describe the
target. Thomas: JITs should handle these patterns, so ZS1 becomes a ruby/ruby PR built on Rafael França's branch
([DECISIONS](../DECISIONS.md)). Queue item: [ZS1](../../bench/upstream/pr-queue/items/ZS1.md). Branch:
`thomasklemm/ruby` `thomasklemm/zjit-symbol-block-arg`, head `fbbb9cee7b` (earlier heads
`dcd4bd2b79`, `7eddd8bfce`, `09d8e5308e` and `89e2da1571`, which has the same tree), on master `3be2b028a7`.

### Rails main without VB1: counts and ceilings

Rails main `8217632cf8`, Ruby master `3be2b028a7` plus the measurement patch, ZJIT, 150 warmup iterations. Counts
per iteration:

| per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| `send_block_arg_not_nil` | 115,090 | 42,496 | 166,762 | 61,502 |
| Symbol block sends to an ISEQ callee | 32,467 | 17,343 | 34,810 | 12,000 |
| Symbol block sends to a C callee | 9,974 | 8,864 | 14,937 | 4,501 |
| yields to a Symbol handler | 15,248 | 19,066 | 30,737 | 12,501 |

VB1's `cast_value(&:value!)` is what moved: Symbol sends to ISEQ callees were 9,987 / 2,588 / 8,017 per iteration
with VB1 applied.

Callgrind ceilings, share of all instructions of an iteration (fixed heap, JIT-flat windows, run a; the whole
generic region, nothing subtracted for what a specialized path still costs):

| share of an iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| generic send, ISEQ callee | 0.304% | 0.213% | 0.435% | 0.178% |
| generic send, C callee | 0.091% | 0.107% | 0.172% | 0.071% |
| `yield` to a Symbol (invokeblock) | 0.116% | 0.225% | 0.375% | 0.101% |
| `rb_yield` to a Symbol from C | 0.149% | 0.204% | 0.311% | 0.271% |

The blog page failed the JIT-flat gate in run a. A generic Symbol send costs 360–392 instructions per send, a
yield to a Symbol 630–797. The send side together is 0.25–0.61% of an iteration, which clears the 0.3% bar on
railsbench, lobsters and shipit.

### Rafael's branch on current master

`Shopify/ruby:zjit-perf/blockarg-direct-send` has 11 commits and is 1,463 commits behind master. Ten of them
landed upstream as ruby/ruby#18725, so only `3f17d8950e` "ZJIT: Directly send non-nil block arguments" had to be
ported. It conflicts with master in `zjit/src/hir.rs` (19 hunks), `codegen.rs`, the snapshots and
`test/ruby/test_zjit.rb` (which master replaced by the Rust test harness). The port, `e353bbed96`, is local only
and keeps what the commit does: block arguments of every kind (Symbol, Proc, nil, forwarded block parameter) go
through `rb_vm_block_handler_from_blockarg()` to ISEQ and C callees. It is a port, not a rewrite: the mechanism and
most of the text survive.

What the port removes per iteration, counted on Rails main (`ZS1_SYMBOL_ONLY=1` restricts the same build to static
Symbols, as a proxy for the narrowed PR):

| per iteration | railsbench | lobsters | shipit | blog page |
| --- | ---: | ---: | ---: | ---: |
| `send_block_arg_not_nil`, master | 115,090 | 42,496 | 166,762 | 61,502 |
| Symbols only | 82,623 | 25,509 | 132,082 | 49,501 |
| full port | 0 | 0 | 54 | 0 |
| dynamic sends, master | 913,616 | 768,317 | 1,782,551 | 784,011 |
| Symbols only | 871,175 | 742,789 | 1,724,383 | 767,505 |
| full port | 715,516 | 707,846 | 1,587,949 | 694,505 |
| `invokeblock_not_specialized`, all three | 78,069 | 57,281 | 90,435 | 44,004 |

Neither variant reaches the `yield` in `cast_value`: `invokeblock_not_specialized` does not move, and that part
needs k0kubun's row 17. Row 17 (`ed1c0f97b2`) does not apply to master (20 conflict hunks in 4 files), so there is
no second PR, and rows 17 and 56 stay with him.

The forwarded block parameter (`foo(&block)` with the block param proxy) is most of what the full port removes
beyond Symbols. It is row 7 of Shopify/ruby#1039, assigned to k0kubun, and Proc and nil block arguments to C callees
are row 42. The PR leaves both out.

### The change

Scope: a send whose block argument is a static Symbol, to ISEQ and C callees. Three commits on master
`3be2b028a7`, head `fbbb9cee7b`:

1. `b7dfd487a6` "Extract rb_vm_symbol_block_handler() from vm_caller_setup_arg_block()" (+29 −22 in `vm_args.c`
   and `vm_core.h`, Thomas): the VM part alone, with no change in behaviour.
2. `8aedcce4ca` "ZJIT: Send Symbol block arguments directly" (+212 −55 in 9 files, Rafael França as author, Thomas
   as co-author).
3. `fbbb9cee7b` "ZJIT: Test sends with a Symbol block argument" (+354 in 3 files, Thomas).

Until the reviews were done this was two commits, head `89e2da1571`, with the VM extraction inside the ZJIT commit
(`656ae95dbc`). The coordinator had it split so that the VM change and the ZJIT change are separate commits of one
PR ([DECISIONS](../DECISIONS.md), one concern per PR). `git diff 89e2da1571 fbbb9cee7b` is empty, and so is
`git diff 656ae95dbc 8aedcce4ca`; only the commit boundaries and the wrapping of five lines in the ZJIT commit's
message changed. The extraction in its present form is Thomas's: Rafael's branch moved the whole block-argument
chain into `rb_vm_block_handler_from_blockarg()`.

* `type_specialize` accepts the block argument when its type is `StaticSymbol` (a literal) or when the profile says
  so, then behind `GuardType StaticSymbol` with recompilation. It does so only while `Symbol#to_proc` is basic
  and no box has been created with `Ruby::Box.new`, and for a C callee only when the call has no splat or
  keywords, so no guard is emitted in front of a send that stays dynamic. It strips the block argument from the
  argument list and records `BlockHandler::BlockArgSymbol(symbol)`.
* When the send commits to `SendDirect`, `CCallWithFrame` or `CCallVariadic`,
  `gen_patch_points_for_symbol_block_arg` puts `PatchPoint RootBoxOnly` and `PatchPoint MethodRedefined(Symbol,
  to_proc)` in front of the callee's own patch point.
* Codegen calls `rb_zjit_symbol_block_handler(cfp, symbol, to_proc_cme)` before the frame push and uses the result
  as the callee frame's block handler. The function returns `Qundef` when the basic flag of the watched
  `Symbol#to_proc` entry is cleared, and compiled code then side-exits on the frame state of the original send
  (`UnhandledBlockArg`). Otherwise it calls `rb_vm_symbol_block_handler(cfp, symbol)`, the body of the Symbol
  branch of `vm_caller_setup_arg_block`, extracted unchanged: without refinements in the caller's cref it returns
  the Symbol, with them the cached or a new refined lambda. It allocates but calls no Ruby code, so it is a leaf
  call with `gen_prepare_leaf_call_with_gc` on the frame state of the original send.
* The C-callee instructions get an `exit_state`, as `SendDirect` has: the stack overflow check before a C frame is
  pushed must exit with the block argument still on the stack.
* The general inliner skips a send with a Symbol block. The trivial inliner does not: a callee it inlines never
  uses its block.
* Left as on master: dynamic Symbols and every other block argument object (a Proc to an ISEQ callee is #18180),
  bmethod and other callee types, and the callee's `yield` to the Symbol.

Two earlier versions, for the history:

* The first called the whole block-argument chain, as Rafael's branch does. Callgrind showed 124 of that helper's
  176 instructions per call in `rb_method_basic_definition_p(rb_cSymbol, idTo_proc)`, which the patch point
  covers, so the extraction was narrowed to the Symbol branch (head `7eddd8bfce`).
* That head relied on the patch point alone for `Symbol#to_proc`. The reviews showed two cases it misses (below),
  so the conversion got the flag check and the specialization the box check (head `09d8e5308e`).

History: the ZJIT commit is narrowed from Rafael's `3f17d8950e` and keeps him as author with Thomas as co-author
(coordinator: the design is his). His two stats counters, benchmark yml, bootstraptest and forwarding tests are not
in it.

### Where the interpreter does more than pass the Symbol, and what covers it

The interpreter's rule (`vm_caller_setup_arg_block`): a Symbol block argument becomes the block handler as it is
when `Symbol#to_proc` is basic in the box of the running frame; with refinements in the caller's cref it becomes
a refined lambda, cached per Symbol in the cref's refinement table; otherwise `to_proc` is called.

| condition | what the compiled send does |
| --- | --- |
| `Symbol#to_proc` redefined before compilation | not specialized (`rb_method_basic_definition_p` at compile time) |
| redefined after compilation (`def`, `define_method`, `prepend`, `remove_method`, `undef_method`, `alias_method`, a refinement of `Symbol#to_proc`) | `PatchPoint MethodRedefined(Symbol, to_proc)` invalidates the code |
| redefined with its own definition (`Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))`): the VM clears the basic flag in place and invalidates nothing | the conversion checks the flag of the watched entry and side-exits |
| another box redefines `Symbol#to_proc` (`RUBY_BOX=1`) | not specialized once a box was created with `Ruby::Box.new`; `PatchPoint RootBoxOnly` for code compiled before |
| refinements in the caller's cref | the conversion is the interpreter's own code, run on the caller's frame, so it returns the same refined lambda |
| dynamic Symbols | not specialized: the type and the guard are `StaticSymbol`. Nothing is embedded in code except the `to_proc` method entry, as a GC-tracked operand |
| `&sym_variable` | profiled, behind `GuardType StaticSymbol`; another object side-exits and recompiles |
| a C callee with a splat or keywords | not specialized, and no guard is emitted |
| private and protected methods, `method_missing`, `respond_to_missing?`, a yield with no, several, splatted or keyword arguments, frozen and `BasicObject` receivers, `break`, exceptions | all happen in the callee's `yield` (`vm_invoke_symbol_block`, `vm_yield_with_symbol`), which gets the same block handler as in the interpreter and is not changed |
| `block_given?`, and `lambda?` and `arity` of a materialized `&block` | the callee frame holds the same handler value, so `getblockparam` builds the same Proc |
| backtraces and `caller_locations` | the same frames are pushed; the conversion pushes none |
| TracePoint | as before: every instruction a TracePoint can affect sits behind `PatchPoint NoTracePoint` |
| stack overflow while pushing the callee frame | exits on the frame state of the original send (`exit_state`), block argument on the stack |
| Ractors | the conversion reads only the running frame and its cref; a non-main Ractor running the sends under `GC.stress` matched (Fable pass) |

[`zs1_probe.rb`](../../bench/upstream/zs1_probe.rb) runs these cases N times at one call site and prints every
result or exception; the interpreter's output is compared with ZJIT's at four settings.

### Guards and the tests that fail without them

Each row was checked by removing the guard and running the tests (`.amp/in/orb-backup/zs1/mutate.py`, logs
orb-local): all rows on the tree of `09d8e5308e`, and the patch-point and flag-check rows again on `89e2da1571`,
whose tests for them changed.

| removed | failing behaviour test |
| --- | --- |
| `Symbol#to_proc` patch point, on the ISEQ, C or variadic C path alone | `test_send_symbol_block_arg_to_proc_redefined_after_compile`: `[4, [30], 30]`, `[300, [4], 30]`, `[300, [30], 4]` for `[300, [30], 30]` |
| compile-time `Symbol#to_proc` check | `test_send_symbol_block_arg_to_proc_redefined_before_compile` |
| basic-flag check in `rb_zjit_symbol_block_handler` | `test_send_symbol_block_arg_to_proc_redefined_with_itself`, on all three paths (`proc(&:double)` and `Proc.new(&:double)` are the C callees) |
| compile-time box check | `test_send_symbol_block_arg_in_box_with_redefined_to_proc` (test_zjit_cli.rb, `RUBY_BOX=1`) |
| `GuardType StaticSymbol` on a profiled block argument | `test_send_symbol_block_arg_guard_precedes_to_proc`, `test_send_symbol_block_arg_side_exit` |
| the conversion call | `test_send_symbol_block_arg_with_refinements` |
| complex-argument check for C callees | `test_send_to_cfunc_with_symbol_block_arg_and_splat_falls_back` (HIR snapshot: no guard in front of the `Send`) |
| `exit_state` in the C-callee overflow checks | `test_stack_overflow_exit_from_send_with_normalized_keywords` (`[1].sum(&:itself)`, `[1, nil].reject(&:nil?)`), each path confirmed alone |
| the general inliner's skip | seven codegen tests and two snapshots, and the same CLI test (`target(1, &:itself)`) |
| `PatchPoint RootBoxOnly` | none (HIR snapshots only) |
| `gen_prepare_leaf_call_with_gc` before the conversion | none |

Two pieces have no failing test:

* **`PatchPoint RootBoxOnly`.** The compile-time check covers code compiled after `Ruby::Box.new`; the patch point
  covers code compiled before. Two reviewers tried to build a program where such code later runs with another
  box's `Symbol#to_proc` (a main method or block called from a box, a method transplanted with
  `define_singleton_method`, `instance_exec` in the box) and found none: main's code keeps main's `Symbol`. It
  stays because upstream's `assume_root_box` pairs the same check with the same patch point.
* **The leaf-call preparation.** It is GC protocol: it writes the PC and SP the conversion's allocation needs.
  Uncached refinement Symbols under `GC.stress` and `GC.auto_compact` match with it; three reviewer programs
  written to fail without it pass too. A reviewer suggested an `ObjectSpace.allocation_sourceline` test (line 10
  in the interpreter, 9 without the preparation); not added.

A lesson for these tests: warm-up calls inside `2.times { }` compile the block, and the methods under test are
then first compiled after the redefinition, so the test passes without the guard. Rafael's redefinition test had
this, and so did ours on head `09d8e5308e`; the warm-up is now plain calls.

### Verification

Run on `89e2da1571`, whose tree is that of the final head `fbbb9cee7b`; the release build is of `656ae95dbc`, whose
tree is that of the ZJIT commit `8aedcce4ca`. x86-64 orb, dev build (`--enable-zjit=dev`), unless noted.

* **The VM commit alone** (`b7dfd487a6`): builds without a compiler warning; `test_proc`, `test_refinement`,
  `test_symbol`, `test_call`, `test_yield` and `test_method` (608 tests, 33,045 assertions, 0 failures) pass in the
  interpreter and with `--zjit-call-threshold=1`; `make btest` passes all 2,148.

* **`make zjit-test`:** 2007 run, 2006 passed. The one failure is
  `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames was not called from SIGPROF handler"). It
  failed here in a parallel and in a single-threaded run while other jobs were running, passes alone three times
  out of three, and fails the same way with base `3be2b028a7`'s `zjit/` (Opus and Fable passes). The claude-code
  pass ran the suite single-threaded in its orb: 2007 of 2007. The 61 block-argument tests pass.
* **`test/ruby/test_zjit_cli.rb`:** 34 tests, 7,903 assertions, 0 failures.
* **Core tests** (`test_proc`, `test_refinement`, `test_symbol`, `test_method`, `test_call`, `test_yield`,
  `test_lambda`, `test_array`, `test_enum`, `test_hash`, `test_settracefunc`, `test_backtrace`, `test_ractor`):
  1,753 tests, 67,382 assertions, 0 failures, 1 skip, in the interpreter and with `--zjit-call-threshold=1`.
* **`make btest`:** all 2,148 pass, in the interpreter and with `--zjit-call-threshold=1`.
* **Differential probe** ([`zs1_probe.rb`](../../bench/upstream/zs1_probe.rb)) on the release build:
  the interpreter's output against `--zjit-call-threshold=1`, against `--zjit-call-threshold=2
  --zjit-num-profiles=1`, against default thresholds (612 lines each) and against default thresholds with `N=40`
  (3,502 lines): four empty diffs. With `--zjit-stats-quiet` the `N=40` run counts 15,586 conversion calls from
  compiled code (`ccall_rb_zjit_symbol_block_handler`) and 1,344 `send_block_arg_not_nil` fallbacks (the Procs,
  dynamic Symbols and other objects the probe passes on purpose).
* **arm64** (ARM1 thread, M3): `make zjit-test` 2,249 of 2,249 in a YJIT+ZJIT build, the 61 block-argument tests,
  `test_zjit_cli.rb` 34 tests with 0 failures on dev and release builds, the probe's diffs empty at three
  settings with the same counters, and `make zjit-bindgen` leaves `cruby_bindings.inc.rs` unchanged. Active Model
  on Rails main with the release build of `09d8e5308e`: 1,272 runs with the same outcome without ZJIT, with
  `--zjit` and at thresholds 1 and 2 (one error in all four, a Ractor and minitest-mock problem).
* **Boxes:** under `RUBY_BOX=1` a send is specialized until the first `Ruby::Box.new` (271 conversion calls for
  300 sends); none of 600 later sends is, including sends in a method compiled before the box.
* **No CI on the fork:** `thomasklemm/ruby` runs no workflows for the branch.
* **Rails suites** (Rails main `8217632cf8`, release build of `656ae95dbc`, `SEED=1`, verbose, without ZJIT and with
  `RUBYOPT=--zjit`, compared per test with `rails_suites_cmp.rb`):
  * Active Model: 1,272 runs, 5,636 assertions, 0 failures, 1 error in both modes, and the same outcome for each
    of the 1,268 tests the verbose logs list. The error is the Ractor and minitest-mock problem that ARM1 sees with
    ZJIT off too.
  * Active Record on SQLite: 10,374 runs, 37,012 assertions, 0 failures, 5 errors, 52 skips in both modes, and the
    same outcome for each of the 10,367 tests the logs list. The errors are the orb's: no `sqlite3` command-line
    tool and no `pg` gem. `forked_child_recovers` is excluded: on the first head a run was killed there by the
    orb's memory limit, once under ZJIT and once in the interpreter.
  * Action View was not run.

### Numbers on the final code

Release builds (`--enable-yjit --enable-zjit`, GCC 14.2.0, rustc 1.100.0): master `3be2b028a7` and the branch
(`656ae95dbc` for the per-call counts and the stats, the final head `fbbb9cee7b` for `run_benchmarks.rb`; the two
differ only in tests). ruby-bench `73918b2` on Rails main `8217632cf8` without VB1, ZJIT with
default options. Two micros were added to the ruby-bench copy:
[`attr-read`](../../bench/upstream/zs1/attr_read_benchmark.rb) (the first attribute reads of rails/rails#59803: 10
records with 30 columns, every attribute read once) and
[`symbol-block`](../../bench/upstream/zs1/symbol_block_benchmark.rb) (`one(i, &:itself)` and
`[1, 2, 3].map(&:itself)`).

**Per call**, Callgrind instructions under ZJIT, from two run lengths
([`per_call.rb`](../../bench/upstream/zs1/per_call.rb)):

| call | master | branch | difference |
| --- | ---: | ---: | ---: |
| `one(i, &:itself)`, ISEQ callee | 1,094.8 | 751.8 | −343.0 (−31.3%) |
| `one(i) { _1 }` | 93.9 | 93.9 | −0.1 |
| `[1, 2, 3].map(&:itself)`, ISEQ callee under a JIT | 3,171.6 | 2,825.8 | −345.8 (−10.9%) |
| `[1, 2, 3].map { _1 }` | 1,043.0 | 1,042.7 | −0.3 |
| `[1, 2, 3].sum(&:itself)`, C callee | 2,343.2 | 2,049.7 | −293.5 (−12.5%) |
| `[1, 2, 3].sum { _1 }` | 1,565.7 | 1,566.1 | +0.5 |

The send gets about 343 instructions cheaper for an ISEQ callee and 294 for a C callee; a generic Symbol send
costs 360–392 on the apps. The flag check and the compare that the review fixes added cost 9 to 12 instructions per
call (743 and 2,814 on `7eddd8bfce` against 751.8 and 2,825.8 now). What separates `one(i, &:itself)` from the
literal block afterwards is mostly the `yield` to the Symbol (633–707 instructions per yield in the first round's
micro), which this change does not touch.

**ZJIT stats diff**, master against the branch, totals of 15 warmup and 10 measured iterations with `--zjit-stats`
([`stats_diff.rb`](../../bench/upstream/zs1/stats_diff.rb): a counter is printed when it changes by more than 1%,
by more than 1,000 and by more than three times the difference between two master runs; an entry missing from a
list that covers 100% of its total counts as 0):

```diff
# railsbench
 calls to C functions from JIT code:
-  rb_vm_send: 5,945,619
+  rb_vm_send: 4,879,037
-send fallback reasons (total): 23,062,604
+send fallback reasons (total): 21,996,028
 send fallback reasons:
-  send_block_arg_not_nil: 2,880,681
+  send_block_arg_not_nil: 2,068,088
-  one_or_more_complex_arg_pass: 2,631,868
+  one_or_more_complex_arg_pass: 2,377,877
-dynamic_send_count: 23,062,604
+dynamic_send_count: 21,996,028
-iseq_optimized_send_count: 78,334,168
+iseq_optimized_send_count: 79,584,504
-vm_write_stack_count: 72,548,064
+vm_write_stack_count: 71,735,501
# lobsters
 calls to C functions from JIT code:
-  rb_vm_send: 2,385,653
+  rb_vm_send: 1,664,764
-send fallback reasons (total): 21,240,260
+send fallback reasons (total): 20,527,432
 send fallback reasons:
-  send_block_arg_not_nil: 1,430,280
+  send_block_arg_not_nil: 951,550
-  one_or_more_complex_arg_pass: 987,312
+  one_or_more_complex_arg_pass: 745,157
-dynamic_send_count: 21,240,260
+dynamic_send_count: 20,527,432
-iseq_optimized_send_count: 46,404,245
+iseq_optimized_send_count: 46,915,275
-non_variadic_cfunc_optimized_send_count: 14,617,275
+non_variadic_cfunc_optimized_send_count: 14,795,608
-guard_type_count: 98,542,681
+guard_type_count: 99,553,608
# shipit
-not inlined C methods (total): 37,368,932
+not inlined C methods (total): 37,749,771
 not inlined C methods:
-  Enumerable#flat_map: 343,572
+  Enumerable#flat_map: 371,774
 calls to C functions from JIT code:
-  rb_vm_send: 5,364,592
+  rb_vm_send: 4,115,154
-send fallback reasons (total): 44,569,405
+send fallback reasons (total): 43,091,646
 send fallback reasons:
-  send_polymorphic_fallback: 21,397,981
+  send_polymorphic_fallback: 21,169,657
-  send_block_arg_not_nil: 4,163,172
+  send_block_arg_not_nil: 3,294,392
-  one_or_more_complex_arg_pass: 1,663,755
+  one_or_more_complex_arg_pass: 1,283,100
-dynamic_send_count: 44,569,405
+dynamic_send_count: 43,091,646
-iseq_optimized_send_count: 85,127,837
+iseq_optimized_send_count: 86,225,319
-non_variadic_cfunc_optimized_send_count: 19,246,354
+non_variadic_cfunc_optimized_send_count: 19,567,384
-vm_write_stack_count: 86,844,780
+vm_write_stack_count: 85,747,865
# attr-read
-most called JIT functions (total): 308,175,494
+most called JIT functions (total): 344,425,556
-send fallback reasons (total): 40,331,108
+send fallback reasons (total): 2,824,849
 send fallback reasons:
-  send_block_arg_not_nil: 37,504,066
+  send_block_arg_not_nil: 2,966
-  one_or_more_complex_arg_pass: 131,805
+  one_or_more_complex_arg_pass: 126,643
-dynamic_send_count: 40,331,108
+dynamic_send_count: 2,824,849
-optimized_send_count: 1,008,756,250
+optimized_send_count: 1,046,262,499
-iseq_optimized_send_count: 261,943,205
+iseq_optimized_send_count: 335,694,254
-inline_iseq_optimized_send_count: 157,873,940
+inline_iseq_optimized_send_count: 121,623,965
-vm_write_jit_frame_count: 500,218,335
+vm_write_jit_frame_count: 537,724,682
-vm_write_sp_count: 500,218,335
+vm_write_sp_count: 537,724,682
-vm_write_stack_count: 106,617,134
+vm_write_stack_count: 69,116,115
-guard_type_count: 754,984,671
+guard_type_count: 792,490,547
-load_field_count: 1,103,630,247
+load_field_count: 1,028,630,118
# symbol-block
 calls to C functions from JIT code:
-  rb_vm_send: 49,999,942
+  rb_vm_send: 0
-send fallback reasons (total): 150,000,221
+send fallback reasons (total): 100,000,265
 send fallback reasons:
-  send_block_arg_not_nil: 49,999,942
+  send_block_arg_not_nil: 0
-dynamic_send_count: 150,000,221
+dynamic_send_count: 100,000,265
-optimized_send_count: 250,019,226
+optimized_send_count: 300,019,136
-iseq_optimized_send_count: 85
+iseq_optimized_send_count: 50,000,025
-vm_write_jit_frame_count: 250,017,303
+vm_write_jit_frame_count: 300,017,231
-vm_write_sp_count: 250,017,303
+vm_write_sp_count: 300,017,231
-vm_write_stack_count: 150,016,241
+vm_write_stack_count: 100,016,301
-guard_type_count: 17,008
+guard_type_count: 50,016,958
-load_field_count: 175,047,242
+load_field_count: 150,047,288
 calls to C functions from JIT code:
-  rb_zjit_symbol_block_handler: 0
+  rb_zjit_symbol_block_handler: 49,999,942
```

* `send_block_arg_not_nil` is the ISEQ callees, `one_or_more_complex_arg_pass` the C callees, which master
  reports as complex argument passing.
* **attr-read under `--zjit-stats`:** `inline_iseq_optimized_send_count` falls because `name_at` is no longer
  inlined into `fetch_value_at!`. The counter instructions that `--zjit-stats` adds count toward the inliner's
  budget of 200 instructions per caller, and the two patch points of the Symbol send push `fetch_value_at!` over
  it. Without `--zjit-stats`, and with stats and `--zjit-inline-budget=260`, the HIR shows `name_at` inlined on the
  branch, so the timed runs are not affected.
* The yields do not move: `invokeblock_not_specialized` is unchanged on all three apps.
* symbol-block: the 50 million sends of 25 iterations leave `rb_vm_send` and go through the conversion; the 100
  million dynamic sends that remain are the yields to the Symbol.

**`run_benchmarks.rb`**, interleaved, 20 warmup and 20 measured iterations, master twice for the A/A, nothing else
running in the orb (a 4-core cloud sandbox, so the percentages after ± are wide):

```
master: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
master-again: ruby 4.1.0dev (2026-11-15T09:48:53Z HEAD 3be2b028a7) +ZJIT +PRISM [x86_64-linux]
symbol-block-arg: ruby 4.1.0dev (2026-11-15T19:16:23Z HEAD fbbb9cee7b) +ZJIT +PRISM [x86_64-linux]
ruby-bench: 73918b2fc1a84702fea63e06f64d179751d69df4-dirty

------------  -------------  -----------------  ---------------------  --------------------  ------------------------  -------------------  -----------------------
bench           master (ms)  master-again (ms)  symbol-block-arg (ms)  master-again 1st itr  symbol-block-arg 1st itr  master/master-again  master/symbol-block-arg
lobsters      1006.3 ± 9.5%       972.7 ± 5.3%          1009.8 ± 7.8%                 1.110                     1.122                1.035                    0.996
railsbench    1525.8 ± 8.3%      1511.5 ± 5.3%          1511.2 ± 7.1%                 1.205                     1.109                1.009                    1.010
shipit        1235.9 ± 6.8%      1339.7 ± 7.6%          1283.4 ± 6.4%                 0.943                     0.972                0.923                    0.963
attr-read      300.5 ± 3.3%       305.4 ± 6.6%           249.9 ± 4.8%                 1.112                     1.065                0.984                    1.202
symbol-block   370.6 ± 6.7%      431.4 ± 13.2%           306.0 ± 9.7%                 1.018                     1.072                0.859                    1.211
------------  -------------  -----------------  ---------------------  --------------------  ------------------------  -------------------  -----------------------

Legend:
- master-again 1st itr: ratio of master/master-again time for the first iteration.
- master/master-again: ratio of master/master-again time. Higher is better for master-again. Above 1 represents a speedup.
- symbol-block-arg 1st itr: ratio of master/symbol-block-arg time for the first iteration.
- master/symbol-block-arg: ratio of master/symbol-block-arg time. Higher is better for symbol-block-arg. Above 1 represents a speedup.
```

* **Apps:** no change beyond noise. railsbench 1.010 against an A/A of 1.009, lobsters 0.996 against 1.035, shipit
  0.963 against 0.923. No app is slower than master beyond its A/A. On shipit the second master column is 8% slower
  than the first in this run and in the one before it, so the order of the interleaved executables shows there.
* **Micros:** attr-read 1.202 against an A/A of 0.984; symbol-block 1.211 against an A/A of 0.859, whose second
  master column has ±13.2%.
* **The same tree as `656ae95dbc`, 25 minutes earlier:** lobsters 960.4 / 954.9 / 917.2 ms (A/A 1.006, branch
  1.047), railsbench 1531.6 / 1521.8 / 1524.6 (1.006, 1.005), shipit 1295.4 / 1411.5 / 1399.0 (0.918, 0.926),
  attr-read 308.4 / 303.4 / 270.6 (1.016, 1.139), symbol-block 380.6 / 367.9 / 310.2 (1.035, 1.227). The body
  shows the later run because its header names the head of the PR.
* **Earlier run on `7eddd8bfce`** (before the flag check, with the old `symbol-block`, whose loop sat in a method
  that is called once per iteration and so ran compiled only in the last ten iterations): lobsters 829.7 / 795.8 /
  794.9 ms, railsbench 1402.5 / 1394.7 / 1437.2, shipit 1198.3 / 1157.6 / 1221.2, attr-read 320.6 / 292.9 / 241.2
  (A/A 1.094, branch 1.329).
* The three runs agree on the apps. attr-read gains 14%, 20% and 33% in them: the orb's timing noise is that
  large, and the per-call instruction counts above are the precise figure.
* Per iteration the apps lose about 43,000 (railsbench), 29,000 (lobsters) and 59,000 (shipit) dynamic sends,
  from the stats diff over 25 iterations.

**App page via Callgrind.** Measured as whole programs on railsbench, lobsters, shipit and the blog page, on
master, on master again for the A/A, and on the branch (the release build of `141cdfde1f` plus the measurement
patch, whose generated code is that of the ZJIT commit `8aedcce4ca`, `656ae95dbc` before the split). In whole-program
instructions per iteration the branch is

* 0.49% below master on railsbench (0.55% below master again; the two master runs differ by 0.059%),
* 0.42% below master on lobsters (0.32% below master again; A/A 0.094%),
* 0.46% below the one master run with the same GC count on shipit, where the two master runs hold different
  numbers of GCs and give no usable A/A,
* and not measured on the blog page, whose three cells all fail the JIT-flat gate.

So the three benchmark apps have a result and the app page does not. These runs replace the earlier estimate of
0.2% to 0.5% from the ceilings; railsbench against master again is just above it.

**Whole-program runs** (Callgrind with `--zjit`, `RUBY_GC_HEAP_INIT_BYTES=33554432`, 150 warmup iterations, then
windows of 2 iterations; read with `zs1_report.rb cg`). A cell counts only when every window passes the JIT-flat
gate; a cell that fails is recorded as rejected and not rerun. Region columns are instructions per iteration
(regions entered per iteration × instructions each).

Data: `data/zs1/cg-{master,master2,branch}-{railsbench,lobsters,shipit,blog}.json`, one file per cell: the harness
output (gate result, compile counters of the warm windows, and per window the GC count, the JIT counters' change
and the regions entered) with the `totals:` line of each of the cell's six Callgrind dumps added as `totals` (1 the
empty window, 2 the whole program, 3 to 6 the region windows in the table's order). `zs1_report.rb cg FILE` reads
these files directly; its output for the twelve cells is [cg-summary.txt](data/zs1/cg-summary.txt). The Callgrind
dumps themselves are not kept.

| workload | cell | gate | whole program, Ir/itr | GCs | send, ISEQ callee | send, other callee | yield, invokeblock | yield, from C |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | master | **fail** | 2,646,691,384 | 1 | 4,704,373 (12,002 × 392) | 1,875,332 (4,506 × 416) | 2,678,606 (3,510 × 763) | 7,173,354 (9,000 × 797) |
| blog | master again | **fail** | 2,648,151,395 | 1 | 4,649,912 (12,002 × 387) | 1,911,776 (4,508 × 424) | 2,487,727 (3,506 × 710) | 7,108,113 (9,000 × 790) |
| blog | branch | **fail** | 2,638,941,365 | 1 | 192,320 (0) | 188,482 (0) | 2,481,050 (3,506 × 708) | 6,894,451 (9,000 × 766) |
| railsbench | master | pass | 3,937,287,334 | 1 | 11,961,311 (32,467 × 368) | 3,586,640 (9,974 × 360) | 4,579,774 (7,274 × 630) | 5,850,760 (7,974 × 734) |
| railsbench | master again | pass | 3,939,615,741 | 1 | 11,961,311 (32,467 × 368) | 3,586,640 (9,974 × 360) | 4,579,774 (7,274 × 630) | 5,852,124 (7,974 × 734) |
| railsbench | branch | pass | 3,918,065,982 | 1 | 0 (0) | 0 (0) | 4,579,774 (7,274 × 630) | 5,850,760 (7,974 × 734) |
| shipit | master | pass | 3,126,542,997 | 0 | 13,615,304 (34,810 × 391) | 5,372,590 (14,937 × 360) | 11,712,084 (16,571 × 707) | 9,738,826 (14,166 × 687) |
| shipit | master again | pass | 3,204,568,264 | 1 | 13,615,304 (34,810 × 391) | 5,372,590 (14,937 × 360) | 11,712,084 (16,571 × 707) | 9,740,069 (14,166 × 688) |
| shipit | branch | pass | 3,112,246,019 | 0 | 105,520 (130 × 812) | 0 (0) | 11,712,084 (16,571 × 707) | 9,740,070 (14,166 × 688) |
| lobsters | master | pass | 2,990,583,596 | 1 | 6,359,359 (17,343 × 367) | 3,188,198 (8,864 × 360) | 6,716,978 (9,579 × 701) | 6,106,371 (9,487 × 644) |
| lobsters | master again | pass | 2,987,781,225 | 1 | 6,360,723 (17,343 × 367) | 3,188,198 (8,864 × 360) | 6,716,978 (9,579 × 701) | 6,144,907 (9,487 × 648) |
| lobsters | branch | pass | 2,978,153,642 | 1 | 111,072 (356 × 312) | 0 (0) | 6,716,978 (9,579 × 701) | 6,144,907 (9,487 × 648) |

* **blog: rejected, all three cells.** Each cell has a window in which ZJIT compiled something (master: the
  yield-from-C window; master again: the whole-program window and both send windows; branch: the ISEQ-send window,
  2 ISEQs), so none of the three passes the gate and the row is not a result. For the record only: the branch is
  7,750,019 Ir/itr (0.29%) below master and 9,210,030 (0.35%) below master again, the two master runs differ by
  1,460,011 (0.055%), and every window holds 1 GC. The branch enters no send region (a region starts in
  `vm_caller_setup_arg_block`, which the specialized sends do not go through), and its yield regions are entered
  as often as on master.
* **railsbench: −0.49%.** All three cells pass the gate and every window holds 1 GC. The branch is 19,221,352
  Ir/itr (0.49%) below master and 21,549,759 (0.55%) below master again; the two master runs differ by 2,328,407
  (0.059%), so the difference is 8 to 9 times the A/A. The branch enters no send region, and both yield regions
  are identical to master's to the instruction. The saving is larger than the 15,547,951 Ir/itr that master spends
  inside the two send regions; a region leaves out the called method's body, and the remaining 3.7 million are not
  attributed.
* **shipit: −0.46% against the master run with the same GC count; no usable whole-program A/A.** All three cells
  pass the gate, but the whole-program windows hold different numbers of GCs: 0 on master, 1 on master again, 0 on
  the branch (the GC column is the whole-program window's). The two master runs differ by 78,025,267 Ir/itr
  (2.50%), so that pair says nothing about noise at 0 GCs. Against master, which has the same GC count, the branch
  is 14,296,978 Ir/itr (0.46%) lower; against master again it is 92,322,245 (2.88%) lower, which is the GC and not
  the change. What can be compared exactly are the regions: both master runs spend the same 13,615,304 and
  5,372,590 Ir/itr in the two send regions, and their yield regions differ by at most 1,243. On the branch 130
  sends to ISEQ callees per iteration still take the generic path (812 Ir each), no send to another callee does,
  and the yield regions match master's (11,712,084 exactly; 9,740,070 against 9,738,826 and 9,740,069).
* **lobsters: −0.42%.** All three cells pass the gate and every window holds 1 GC. The branch is 12,429,954 Ir/itr
  (0.42%) below master and 9,627,583 (0.32%) below master again; the two master runs differ by 2,802,371 (0.094%),
  so the difference is 3.4 to 4.4 times the A/A. Master spends 9,547,557 Ir/itr in the two send regions. On the
  branch 356 sends to ISEQ callees per iteration still take the generic path (312 Ir each), no send to another
  callee does, and the yield regions equal master again's to the instruction.

### Reviews

Three independent orbs, each rerunning the probe and trying to break a guard; passes are recorded in
[ZS1.md](../../bench/upstream/pr-queue/items/ZS1.md). Thermos is waived for ZS1 (coordinator, 2026-11-15).

**On `7eddd8bfce`: three times `changes`.** No reviewer found a difference in the cases of the brief; each found
one outside them.

* **claude-code:** `Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))`. `method_entry_set`
  (vm_method.c) clears the basic flag of the entry in place when a method is set again with its own definition,
  and invalidates nothing. The interpreter then calls `to_proc`, which gives a plain Proc that ignores the
  caller's refinements; compiled code kept the refined lambda (`[6, 6]` for `[NoMethodError, 6]`). The head before
  it, `dcd4bd2b79`, did not have this: it still checked at run time. Fix: the flag check in the conversion.
* **Fable:** with `RUBY_BOX=1`, a box that redefines `Symbol#to_proc`. The compile-time check and the patch point
  look at the box that is current when the caller is compiled; the callee's code runs in the other box. Base ZJIT
  resolves ordinary methods in the wrong box in the same program shape, so a maintainer may call it out of scope;
  it was still a difference this branch added. Fix: no specialization once a box exists.
* **Opus:** the body called `Array#map` a C method (under a JIT it is defined in Ruby) and quoted one fallback
  reason for both callee kinds; a profiled-Symbol guard was emitted in front of a C-callee send that stays
  dynamic (`a.each_slice(*args, &s)`), the shape #18180 removed. Fixed.

Their answers on the questions put to them: the conversion is rightly a leaf call (the refinement tables are
identity hashes, so no `hash` or `eql?` runs; `rb_vm_ifunc_new` cannot raise for these arities; only
`NoMemoryError` can leave it); no GC can run while only a register holds the handler (LIR between the call and
the store into the callee's specval slot is `Store`, `Lea`, `Mov`, `Cmp`, `Jbe`); nothing between the
`Symbol#to_proc` patch point and the callee frame calls Ruby or checks interrupts; the interpreter is unchanged
(`vm.o` has no call relocation to `rb_vm_symbol_block_handler` at -O3, and base and head interpreters print the
same on the probe and 28 scenario files).

**On `09d8e5308e`: Opus `nits`, claude-code `nits`.** Both confirmed the flag check against
`rb_method_basic_definition_p` (16 single changes at three moments, eight sequences with `GC.compact`, the same
under `RUBY_BOX=1`) and the exit after the leaf call. Their test points went into `89e2da1571`: the
self-redefinition test failed only on its ISEQ element (`reject` and `sum` resolve the refinement either way), and
the helper belongs in the bindgen allowlist.

**On `89e2da1571`: claude-code `approve`, Opus `approve`, Fable `nits`.** No must-fix. Each reran the tests,
the probe and its own break scripts on that head and confirmed by mutation that the two reworked tests fail
without their guard; `make zjit-bindgen` regenerates the binding file unchanged in all three orbs and on the Mac.
Fable ran 396 combinations of a `Symbol#to_proc` change, a setup and a moment, at four settings, and found the
only code that changes the basic bit of an existing entry (vm_method.c:1851), reachable in three ways, all handled.

**On `fbbb9cee7b`, the split head: claude-code `approve`, Opus `approve`, Fable `nits`.** Confirm passes limited
to what changed: the tree is the same object as on `89e2da1571` (`63d226b442`), the VM commit holds the whole VM
change and nothing of ZJIT, the ZJIT commit nothing of the VM, authors, committer and trailers are as intended,
and no message line is over 72 characters. Two optional points would need another head and are with the
coordinator: the ZJIT commit's "extracted unchanged" could say "in the previous commit" (claude-code and Fable
would leave it), and a `Co-authored-by` for Rafael on the VM commit, whose first version was his
`rb_vm_block_handler_from_blockarg()` (Opus; Thomas's call).

Decided by the coordinator on 2026-11-15:

* **One concern per PR:** the VM extraction is its own commit in the same PR (above).
* **Tracker rule:** the ZJIT commit is +212 −55, above the 150-line "ask on the tracker first" rule in DECISIONS.
  The coordinator asked Thomas, who decided to open the draft (ruby/ruby#19912) without a comment on
  Shopify/ruby#1014.
* **Disclosure:** the tip of Rafael's branch says the branch was produced by an agent (`ZJIT_PERF_TASK.md`,
  `ZJIT_PERF_SUMMARY.md`). No LLM disclosure is added and Rafael is not pinged separately; the body names him and
  links his branch.
* **Body length:** the prose before the table (187 words with the sentence on the first commit) is fine, as
  for ZNE1.
* **No further code change:** Fable's recompile on the flag-check exit stays out.

Not applied:

* If the team asks for a split: ISEQ callees first (mirrors #18180), then C callees with the `exit_state` on the
  C-call instructions.
* Carrying the `Symbol#to_proc` entry in `BlockArgSymbol` instead of looking it up again at code generation (the
  two lookups give the same entry, since nothing runs between HIR and codegen); one place that lowers
  `BlockArgSymbol`; parameter names in `rb_vm_symbol_block_handler` (the moved lines stay identical); the name
  of the CLI test that holds the overflow rows.
* A send whose `Symbol#to_proc` was redefined with itself exits on every call and does not recompile (Fable:
  2,000 exits per 1,000 iterations of a loop with two such sends; `side_exit_with_recompile` there brings it to 12).
* The general fix for the basic flag belongs in the VM (`method_entry_set` could invalidate the entry), as its own
  PR.

### Found on the way, present on master, not from this change

* **Interpreter crash, also on 4.0.9** (Fable): the cached refinement lambda keeps the `svar_lep` of the frame
  that created it. With `using` a refinement, `def sv = (y2("abc", /b/, &:match); $~)` called at two stack depths
  ends in a segfault on 4.0.9 and `[BUG] vm_svar_valid_p` on master (9 lines, `svar_bug.rb` in the reviewer's
  orb, thread T-01a1e02a-5156-7535-b82d-6fdecf19860d). The PR moves that code and does not change it.
* **`Array#map` under any JIT:** it reports `call`/`return` instead of `c_call`/`c_return` to a TracePoint, and
  a Symbol proc passed to it ignores the caller's refinements (YJIT on 4.0.9 does the same), because `map` is a
  Ruby method then. A comparison of interpreter against JIT has to use `--zjit --zjit-call-threshold=1000000` as
  its baseline where `map`, `each` or `select` is involved.
* **`RUBY_BOX=1`:** `[1, 2].sum(&:dbl)` with refinements raises `NoMethodError` with nothing compiled.
* **Compaction:** ZJIT with `GC.auto_compact` and `GC.stress` once printed `ToProc#to_proc gives ` with an empty
  class name, on base and in one of three head runs (Fable).
* **`test_profile_frames_during_direct_jit_to_jit_entry`** fails in a full `make zjit-test` in this orb
  ("rb_profile_frames was not called from SIGPROF handler"), on base as well, and passes alone.

### PR body and the #1014 comment

The body is in [ZS1.md](../../bench/upstream/pr-queue/items/ZS1.md), verbatim as posted. It references
Shopify/ruby#1014, #18180 and Shopify/ruby#1039, and has no footer and no Lowrail link. The coordinator
opened it as draft ruby/ruby#19912 on 2026-11-15 at `fbbb9cee7b` (three commits, maintainer edits on), after
Thomas's decision ([DECISIONS](../DECISIONS.md)).

Draft reply to tekknolagi's question on Shopify/ruby#1014 ("Is this done now that Alan added the PR?"), **not
posted**: Thomas decided to open the PR without a comment on that issue. It stays here as a draft only:

> Not all of it: ruby/ruby#18180 covers a profiled `Proc`, and ruby/ruby#19484 callees that declare `&block`. A
> Symbol block argument (`foo(&:sym)`) still fell back to a dynamic send; ruby/ruby#19912 sends it directly to
> ISEQ and C callees. Forwarded block parameters and the `yield` to a Symbol are not in it.

### Reproduce the second round

```sh
# Release builds: master 3be2b028a7 into ~/w/rm, the branch into ~/w/rp (build_rel.sh).
# ruby-bench 73918b2 copy on Rails main 8217632cf8 in ~/w/rb-rbm, with bench/upstream/zs1/*_benchmark.rb copied to
# benchmarks/attr-read/benchmark.rb and benchmarks/symbol-block/benchmark.rb.
ruby zs1_probe.rb > i.txt; ruby --zjit --zjit-call-threshold=1 zs1_probe.rb > z.txt; diff i.txt z.txt
./run_benchmarks.rb railsbench lobsters shipit attr-read symbol-block --no-sudo --interleave --warmup=20 --bench=20 \
  -e "master::$HOME/w/rm/bin/ruby --zjit" -e "master-again::$HOME/w/rm/bin/ruby --zjit" \
  -e "symbol-block-arg::$HOME/w/rp/bin/ruby --zjit"
WARMUP_ITRS=15 MIN_BENCH_ITRS=10 MIN_BENCH_TIME=0 ruby --zjit --zjit-stats benchmarks/railsbench/benchmark.rb 2> rm.stats
ruby bench/upstream/zs1/stats_diff.rb rm.stats rm2.stats rp.stats
valgrind --tool=callgrind ruby --disable-gems --zjit bench/upstream/zs1/per_call.rb iseq_symbol 20000   # and 120000
ruby bench/upstream/zs1/per_call_table.rb OUT
```

The orb-local scripts (`rbm.sh`, `stats.sh`, `per_call.sh`, `verify.sh`, `mutate.py`, `rails_suites.sh`) are in
`.amp/in/orb-backup/zs1/` of the ZS1 thread and are not committed.

**Rebase 2026-11-17.** Head `aa36fa0ea4` on master `b4ade67ba5`, for a conflict in the `Array#zip` snapshot of `test_optimize_send_variadic_with_block` after master's stack maps in side exits. `git range-diff`: commits 1 and 3 `=`, commit 2 changes only that snapshot; codegen, HIR and LIR unchanged. The passes and measurements above are on `fbbb9cee7b`, whose code this head keeps. arm64 dev build: `make zjit-test` 2,272 passed, test_zjit_cli 34 tests, `make btest` with `--zjit-call-threshold=2` all 2,148; the ZJIT-vs-interpreter probe is unchanged.

## Fix round for XrXr's review (2026-11-25)

XrXr requested changes on ruby/ruby#19912 on 2026-11-24: the `Symbol#to_proc` check should be a HIR speculation
([r4686073773](https://github.com/ruby/ruby/pull/19912#discussion_r4686073773)), and the refinements check should be
a guard that loads the cref, not a run-time branch
([r4686108643](https://github.com/ruby/ruby/pull/19912#discussion_r4686108643)).

New head `2e3108fc05` on master `f63048e942`, two commits: `f858d208e8` "ZJIT: Send Symbol block arguments directly"
(Rafael as author, Thomas as co-author) and `2e3108fc05` "ZJIT: Test sends with a Symbol block argument" (Thomas).
Meant for `thomasklemm/ruby` `thomasklemm/zjit-symbol-block-arg-2`; the push was refused (the token has no
`workflow` scope and master changed `.github/workflows` since the fork last synced). The patches are in
[`round2/`](../../bench/upstream/zs1/round2/), with the probes.
Until the fork has it, reviewers fetch the exact commits from
[`round2/zs1-2.bundle`](../../bench/upstream/zs1/round2/zs1-2.bundle): prerequisite
`f63048e94229b4bab276e01bac4902f9b6a74ace`, ref `refs/heads/zs1-2` at `2e3108fc0558f076a7acbbd1eaf2f5acd534f603`
(`git fetch zs1-2.bundle refs/heads/zs1-2:refs/heads/zs1-2` in a clone of ruby master). Checked with `git bundle
verify` in a fresh clone of ruby master (`bb27ff85cf`); the fetch gives the same commit and tree SHAs.

What changed against `aa36fa0ea4`:

* The VM commit is gone. `rb_vm_symbol_block_handler()` and `rb_zjit_symbol_block_handler()` are removed, and the PR
  implementation touches only `zjit.c` (one declaration) and `zjit/`, plus the CLI test in `test/ruby/`.
* The Symbol itself is the callee frame's block handler (`lir::BlockHandler::Value`, as for a guarded Proc); no
  conversion call before the frame push, no conversion leaf-call preparation, no `Qundef` exit. `GetCref` still
  calls the C helper `rb_vm_get_cref` before the send.
* `Symbol#to_proc`: `PatchPoint MethodRedefined(Symbol, to_proc)` and `PatchPoint RootBoxOnly`, as before, now with
  no run-time flag check. A same-definition redefinition (`Symbol.define_method(:to_proc,
  Symbol.instance_method(:to_proc))`) clears the basic flag without invalidating the entry, so compiled code keeps
  passing the Symbol while the interpreter calls `Symbol#to_proc`. The builder's `same_definition_probe.rb`
  matches without refinements, but does not establish equivalence: the review below finds different Proc identity
  when the callee evicts the Symbol Proc cache before reading its block parameter. With refinements the cref guard
  exits.
* Refinements: a new `GetCref` instruction (calls `rb_vm_get_cref(cfp->ep)`, which asserts `vm_env_cref()` is nonnull), then
  `LoadField :refinements` and `GuardBitEquals nil` with recompile. It is a per-call guard and not a compile-time
  check, because a top-level `using` adds refinements to a cref after the code is compiled. Not specialized when
  `policy.no_side_exits`.
* New test `test_send_symbol_block_arg_with_refinements_activated_after_compile` (two ISEQ callees and a variadic
  C callee: `Array#map` is Ruby-defined with ZJIT, not the claimed fixed-arity C case).
  Removing the guard fails it, `test_send_symbol_block_arg_with_refinements`,
  `test_send_symbol_block_arg_to_proc_redefined_with_itself` and the four snapshots.

The builder's NULL-cref question is settled by the source audit below: valid Ruby ISEQ frames reaching this HIR
instruction have a cref. The interpreter's nullable helper also serves environments that cannot execute it.

Verification (dev build, x86-64 orb): `make zjit-test` 2,050 of 2,051 (the failure is
`test_profile_frames_during_direct_jit_to_jit_entry`, SIGPROF, as on master in orbs); `make btest` with
`--zjit-call-threshold=1` and `=2` 2,148 of 2,148 each; `test_zjit_cli.rb` 34 tests, 0 failures; `test_proc`,
`test_refinement`, `test_symbol`, `test_method`, `test_call`, `test_yield`, `test_lambda`, `test_array`, `test_enum`,
`test_settracefunc`, `test_backtrace` at threshold 1: 1,380 tests, 0 failures; `zs1_probe.rb` diffs empty at
threshold 1, threshold 2 with one profile, default, and default with `N=40` (after normalizing Thread addresses on
stderr); the three round-2 probes identical in the interpreter and at thresholds 1 and 2.

railsbench (ruby-bench, Rails 8.1.4.1, 10 warmup and 10 measured iterations, release builds, `--zjit-stats`):

```diff
 calls to C functions from JIT code:
-  rb_vm_send: 4,732,653
+  rb_vm_send: 4,289,576
 send fallback reasons:
-  send_block_arg_not_nil: 2,440,814
+  send_block_arg_not_nil: 2,200,740
-  one_or_more_complex_arg_pass: 2,133,480
+  one_or_more_complex_arg_pass: 1,930,477
-dynamic_send_count: 17,521,001
+dynamic_send_count: 17,077,938
```

No `unhandled_block_arg` exit: the cref guard never fires there. Rails main's framework code has no `using`, and of
railsbench's gems only irb has one. The body's numbers (from `fbbb9cee7b`) still describe the same specialized sends.
The body's second and third paragraphs were rewritten for the new shape.

Reply drafts (for Thomas, **only after the basic-flag fix and review of the new head**):

> r4686073773: The C helper check is gone. `MethodRedefined` covers replacement of `Symbol#to_proc`, and a HIR
> basic-flag guard covers redefinition with its own definition. Both exits resume the original send; the Symbol is
> passed directly only when conversion can be skipped.

> r4686108643: Done: a `GetCref` instruction loads the cref from the frame's EP and `GuardBitEquals` checks that
> its refinements are nil, exiting with recompile otherwise. It stays a per-call guard because a top-level `using`
> can add refinements to the cref after the code is compiled (tested). With that, the `vm_args.c` extraction is
> gone and the PR touches only ZJIT.

### thermos-sol on `2e3108fc05`: changes (2026-11-25)

Review orb [T-01a211b5-8b72-7106-b650-4a78d8f8a461](https://ampcode.com/threads/T-01a211b5-8b72-7106-b650-4a78d8f8a461).
Both Thermos rubrics applied personally, without subagents or other threads as requested. Scope: the whole
`f63048e94229b4bab276e01bac4902f9b6a74ace..2e3108fc0558f076a7acbbd1eaf2f5acd534f603` PR, not just the fix delta.
Verified bundle SHA-256 `0ba360fe79737116d0045389190617b3a1e5143f8d1982dfabdd7ae91f6ff784`, prerequisite,
two-commit range and exact fetched head. Nothing pushed to Ruby or posted.

**Must fix — delayed conversion changes observable Proc identity.** `gen_guards_for_symbol_block_arg`
(`zjit/src/hir.rs:6688`) watches entry replacement but not the entry's basic bit. `method_entry_set`
(`vm_method.c:1574–1588`) reuses an equal definition and clears that bit without invalidation when visibility
does not change. The interpreter then calls `to_proc` before entering the callee, while the compiled caller
passes a Symbol and `gen_get_block_param` converts it only when `&b` is read. A callee can evict the 67-entry
Symbol Proc cache (`proc.c:2339–2366`) first. It then sees a new Proc instead of the one supplied by the caller.
This is a new regression against master, with no refinements involved, not the pre-existing JIT builtin issue.

[`proc_identity_probe.rb`](../../bench/upstream/zs1/round2/proc_identity_probe.rb) prints `true` in the interpreter
and with `--zjit --zjit-call-threshold=1000000`, but `false` on this head at thresholds 1 and 2 (one profile),
default options, and threshold 2 with inlining disabled. The callee evicts the cache after entry and before its
first read of `b`. A temporary behavior test asserting `true` fails this head, passes base Rust source linked
against the same C archive, and passes with the HIR guard below. The existing Symbol tests all pass the broken
head, so add this regression rather than relying on the existing self-redefinition/refinements test.

Smallest fix: keep the patch points and add a HIR guard on `METHOD_ENTRY_BASIC` for the watched entry, with the
original send snapshot and recompile. Use a GC-tracked constant for the entry and existing `load_rbasic_flags`
and `GuardAnyBitSet`; no C conversion helper or VM change is necessary. A temporary guard using the current
`IMEMO_FL_USER2` mask (`FL_USER7`, `method.h:72`, `internal/imemo.h:26`) made the new regression and all 12 existing
Symbol-block behavioral tests pass. Give that mask an appropriate source-derived name in the final fix. This
validates the remedy, not an approval of a new Ruby head; the temporary edits were removed afterward.

**Must fix — claims and comments.** The item's second body paragraph and the first commit message say the send
remains specialized only while `to_proc` is basic/not redefined; the same-definition case disproves that on this
head. The message's later claim of equivalent results without refinements and the original first reply's
"same Proc" claim are false. Repair the guard, update that message, and use the conditional replacement reply
above; do not post the original "Done". Under DECISIONS' comment rule, delete the new narration above
`block_arg_symbol` (`codegen.rs:1209`) and the two-line interpreter narration at `hir.rs:5238–5239`: the enum,
branch condition and tests already convey them. The one-line explanation of why refinements require fallback,
and the distinction between original-send and stripped-frame snapshots, do earn their place.

**NULL cref — not a defect in this scope.** `vm_env_cref` (`vm_insnhelper.c:897`) walks previous EPs and extracts
the lexical cref from a method entry. ISEQ method definitions synthesize a top-level cref if none was supplied
(`vm_method.c:1105–1126`); TOP/CLASS frames get explicit crefs (`vm.c:950–953`, `insns.def`'s `defineclass`);
BLOCK/BMETHOD/EVAL/RESCUE frames follow the captured/previous EP chain, and `env_clone` supplies a top-level cref
for a null replacement (`proc.c:4524–4526`). C/IFUNC environments can lack a cref (`proc.c:1425`), but do not execute
Ruby HIR; invoking a Ruby callback establishes its Ruby frame/captured EP. Inlining also pushes the callee's real
frame/EP; `GetCref`'s Memory read effect prevents reuse across that frame mutation. Thus `rb_vm_get_cref`'s nonnull
contract is appropriate here. A nullable wrapper would add an unnecessary layer.

**Maintainability and surviving guards.** The shared Symbol-guard helper belongs in HIR; lowering the block
handler as a VALUE reuses the existing Proc path; removing the VM extraction is a real simplification. No touched
file crosses from below 1,000 lines to above it. No further structural blocker or security/devex regression found.
Rust's match/enum changes and the CLI test do not benefit from Ruby `flog`/RuboCop metrics. The guards have these
specific purposes:

* Static-Symbol type/profile guard: an arbitrary object can run Ruby in `to_proc` and must keep the generic send.
* Compile-time basic check plus `MethodRedefined`: do not skip an overridden conversion; the basic-bit guard
  above is also needed because equal-definition replacement does not trigger this invalidation.
* No-created-box check plus `RootBoxOnly`: avoid resolving conversion in the wrong box; preserve the established
  conservative boundary rather than adding a new box-aware conversion here.
* Cref refinements nil guard with recompile: preserve the interpreter's refined lambda, including a later `using`.
* `no_side_exits` and existing argument-shape, callee and receiver guards: do not select a specialization that
  cannot restore the original send or whose direct-call frame/target is invalid. The C-call `exit_state` keeps the
  original block argument on the stack on overflow; the ordinary `state` describes the stripped frame.

Optional coverage nit: replace `map` with `flat_map` in the new using-after-compile test to exercise a real
fixed-arity C callee as advertised. Existing refinement tests and the differential matrix do exercise `flat_map`.

**Sentence audit.** Body paragraph 2, sentence 1: correct for accepted call shapes (`SendDirect`,
`CCallWithFrame`, `CCallVariadic`, Symbol block handler). Sentence 2: the basic-method promise is false on this
head; the box and refinements clauses are implemented. Sentence 3: correct, `yield` lowering is unchanged.
Body paragraph 3, both sentences: the Symbol portion is narrowed/ported from Rafael's branch; forwarded block
parameters remain outside this PR. Opened his source commit `3f17d8950e2ab9ccdc4b91df07bd18f419bef642` and read its
HIR/codegen changes. First original reply: removing the old helper and watching method replacement are facts;
the equal-definition/basic-bit explanation is correct, but the conclusion that the resulting Proc is identical
is disproved above. Second reply: all three sentences match `GetCref`, nil guard/recompile, the late-`using` test,
and removal of the VM extraction. The replacement first reply is true only after the recommended guard lands.
Old benchmark rows were not rerun in this correctness pass and are not new measurements of this head.

**Authorship.** Read the PR's existing commits through GitHub's API: old ZJIT commit `30e0ca73f6` has Rafael
Mendonça França `<rafael.franca@shopify.com>` as author, Thomas as committer, and
`Co-authored-by: Thomas Klemm <github@tklemm.eu>`. Proposed `f858d208e8` has exactly those identities/trailer;
the proposed test commit is Thomas's, as before. Author dates were refreshed to November 25, rather than preserved
from November 15. No Amp trailer. This matches the attribution already on the PR, not a new attribution choice.

**Executed evidence, dev build, x86-64 orb.** Configured `--enable-zjit=dev --disable-install-doc --disable-yjit`
and built with `make -j2`.

| Command/check | Result |
| --- | --- |
| `make zjit-test ZJIT_TESTS='--test-threads=2'` | 2,051 run; 2,050 pass, one SIGABRT, 15 skipped |
| Base Rust control, identical lockfile and C archive | Same SIGPROF test abort; new identity regression passes |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | 2,148/2,148 |
| Same btest at threshold 2 | 2,148/2,148 |
| `make test-all TESTS='test/ruby/test_zjit_cli.rb'` | 34 tests, 7,907 assertions, no failure/error/skip |
| Proc/refinement/symbol/method/call/yield/lambda/array/enum/settracefunc/backtrace, ZJIT threshold 1 | 1,380 tests, 64,214 assertions, no failure/error, one skip |
| Existing `zs1_probe.rb`, interpreter vs t1, t2p1, default | 612 stdout lines each, identical; stderr identical after normalizing Thread addresses |
| Same probe, `N=40`, interpreter vs default | 3,502 stdout lines, identical; normalized stderr identical |
| Three original round-2 probes, interpreter vs t1p1/t2p1 | All six comparisons identical |
| 12 method mutations × refined/plain × before/after compile × three ZJIT settings | 144/144 match the uncompiled ZJIT-enabled interpreter control |
| Wrong variant deleting only the cref guard | 20 run: seven fail (three behavioral tests and four HIR snapshots), 13 pass |
| New identity behavior regression | Fails this head; passes base Rust control and temporary HIR basic-bit guard |
| Temporary guard, existing Symbol behavioral tests | 12/12 |
| Restored exact head, `ZJIT_TESTS='symbol_block_arg --test-threads=2'` | 18/18; source diff empty |
| `make zjit-bindgen` | Regenerated bindings byte-identical after installing the missing toolchain rustfmt |

The full-suite abort is `test_profile_frames_during_direct_jit_to_jit_entry`:
"rb_profile_frames was not called from SIGPROF handler". The base control compiles master's Rust source with
this build's C archive (the sole C difference is a declaration) and the same copied lockfile; it is not a separate
full base-C build. The 144-case matrix uses `--zjit --zjit-call-threshold=1000000` for the uncompiled control
because JIT-enabled Ruby builtin selection itself changes refinement behavior independently of this PR. It
covers replacement, define_method, prepend, remove/undef, aliases, same-definition restore, visibility, refined
`to_proc` and restore, including `GC.compact`, ISEQ/fixed-C/variadic calls, `block_given?`, `yield` and block
materialization. The identity repro also differs against the plain interpreter, so has no such qualification.

Scratch harnesses, base sources, the temporary validation patch, API reads and copied logs are under
`.amp/in/orb-backup/zs1-review/` in the review orb. No arm64 build or new performance measurement in this pass.
XrXr is likely to accept the HIR-speculation shape with the basic-bit guard and corrected claims: it uses the
machinery he requested and drops the VM extraction. This exact head is not ready; acceptance remains his decision.

### Round 3 for thermos-sol (2026-11-25)

Head `bdcfceb5eecaa0b7060f2df13958308ea8690624` on master `f63048e942`: `05ae429a7b` "ZJIT: Send Symbol block
arguments directly" (Rafael as author, Thomas as co-author) and `bdcfceb5ee` "ZJIT: Test sends with a Symbol block
argument" (Thomas). Not on the fork (still no `workflow` scope). Bundle
[`round3/zs1-3.bundle`](../../bench/upstream/zs1/round3/zs1-3.bundle), SHA-256
`208954879c51b0c9202b9abefc99545f496f793a79b8e755e3b1eb8eb9ae7f2b`, prerequisite
`f63048e94229b4bab276e01bac4902f9b6a74ace`, ref `refs/heads/zs1-3`; `git bundle verify` passes in a fresh clone of
ruby master (`0988275a9b`), and the fetch gives the same commit and tree SHAs. Patches next to it.

Against `2e3108fc05` (+71 −31 in 5 files):

* `gen_guards_for_symbol_block_arg` adds, after the two patch points, a `Const` of the `Symbol#to_proc` CME
  (GC-tracked, typed `CallableMethodEntry`), `load_rbasic_flags` and `GuardAnyBitSet METHOD_ENTRY_BASIC_FLAG`, with
  the original send's snapshot and recompile. `METHOD_ENTRY_BASIC_FLAG` is `RUBY_FL_USER7` in `cruby.rs`, the
  `IMEMO_FL_USER2` that `METHOD_ENTRY_BASIC()` tests. One comment says why the guard sits next to the patch point.
* The comment above `block_arg_symbol` (codegen.rs) and the two interpreter lines in hir.rs are deleted.
* New test `test_send_symbol_block_arg_to_proc_redefined_with_itself_keeps_proc_identity`, the reviewer's probe in
  the `inspect` style. The using-after-compile test calls `flat_map` instead of `map`.
* The ZJIT commit message no longer says passing the Symbol gives the same result as `to_proc`; it describes both
  guards. The test commit message names the new case. Four HIR snapshots show the new guard.

Mutation: without the `GuardAnyBitSet` the new test and the four snapshots fail. The previous head printed `false`
for [`proc_identity_probe.rb`](../../bench/upstream/zs1/round2/proc_identity_probe.rb) at threshold 1; this one prints
`true` at thresholds 1 and 2 (one profile), default, `--zjit-inline-budget=0` and with `materialize,test` on the
inline deny list.

Verification (dev build, x86-64 orb): `make zjit-test` 2,051 of 2,052 (the SIGPROF test only); `make btest` at
`--zjit-call-threshold=1` and `=2` 2,148 of 2,148 each; `test_zjit_cli.rb` 34 tests, 0 failures; the same 11 core
files at threshold 1 1,380 tests, 0 failures, 1 skip; `zs1_probe.rb` identical to the interpreter at threshold 1,
threshold 2 with one profile, default, and default with `N=40` (Thread addresses normalized); the four round-2 probes
identical in the interpreter and at thresholds 1, 2 and default.

railsbench, same setup as round 2 (master is the release build of `f63048e942`):

```diff
 calls to C functions from JIT code:
-  rb_vm_send: 4,732,653
+  rb_vm_send: 4,289,569
 send fallback reasons:
-  send_block_arg_not_nil: 2,440,814
+  send_block_arg_not_nil: 2,200,733
-  one_or_more_complex_arg_pass: 2,133,480
+  one_or_more_complex_arg_pass: 1,930,477
-dynamic_send_count: 17,521,001
+dynamic_send_count: 17,077,924
```

No `unhandled_block_arg` exit. The body stays: its sentence that the send is specialized only while
`Symbol#to_proc` is basic is true with the guard. The reply drafts above (replacement first reply, unchanged
second reply) are true of this head.

#### thermos-sol confirm: approve (2026-11-25)

Exact fetched head `bdcfceb5eecaa0b7060f2df13958308ea8690624`, exactly two commits on
`f63048e94229b4bab276e01bac4902f9b6a74ace`. Independently checked the round-3 bundle hash and prerequisite with
`sha256sum` and `git bundle verify`. Both rubrics applied personally, without delegation, as a confirm pass of
the five-file delta against the full PR reviewed above. **All earlier must-fixes and the coverage nit are
resolved; no new must-fix or nit.**

* **Basic bit and state:** `METHOD_ENTRY_BASIC_FLAG` is `RUBY_FL_USER7`, and `method.h:72` tests exactly
  `IMEMO_FL_USER2`, mapped to `FL_USER7` by `internal/imemo.h:26`. Compiled C-header assertions independently
  confirm the mask is 524,288 (bit 19) and the callable entry's flags are at offset 0. `load_rbasic_flags` reads
  that word, and `GuardAnyBitSet` exits on a zero bit. All three specialized send paths pass the original send
  snapshot to the shared helper; the guard uses it and `Some(Recompile)`. The two patch points remain.
* **Lifetime and effects:** the CME is a `Const::Value`, inferred as `CallableMethodEntry`, not an untracked raw
  pointer. Codegen's VALUE operands enter the existing GC-offset marking, write-barrier and compaction-update
  machinery. The flags load reads Memory, so the normal memory effects of method redefinition prevent a stale
  cached read across it. Forced `GC.verify_compaction_references(expand_heap: true, toward: :empty)` before and
  after same-definition redefinition preserves `[block_given?, yield(3)] == [true, 4]` at thresholds 1 and 2.
* **Regression:** the new identity test covers the actual cache eviction, and the committed standalone probe
  now prints `true` in the interpreter, uncompiled JIT-enabled control, thresholds 1/2 with one profile, default,
  and threshold 2 with inlining disabled. Removing only the new guard makes the identity test and four HIR
  snapshots fail; restoring it passes all 19 `symbol_block_arg` tests. No Ruby source edits remain.
* **Readability and text:** both redundant comments are removed. The new one-line comments explain why a flag
  guard is necessary despite a method-redefinition patch point, and identify the otherwise non-obvious mask
  mapping; both are justified. `flat_map` fixes the claimed fixed-arity C coverage. The four snapshots contain
  only the guard/constant/flags load and consequent operand renumbering. The corrected commit messages describe
  the guard rather than claiming delayed conversion is equivalent. Author/co-author/committer identities remain
  Rafael/Thomas/Thomas for the ZJIT commit and Thomas for the tests, matching the existing PR.

The unchanged body's basic-method promise is now true; its other previously audited sentences remain true.
The previous NULL-cref conclusion is unaffected: the new guard does not change frame construction or EPs.
The first reply's C-helper statement refers to the removed Symbol conversion check, not to `GetCref`'s C call;
method replacement and same-definition redefinition are now both covered, with original-send recovery.
Every sentence of the unchanged second reply still matches the cref helper, nil guard/recompile and late-`using`
test. These are the final reviewed drafts, not posted:

> r4686073773: The C helper check is gone. `MethodRedefined` covers replacement of `Symbol#to_proc`, and a HIR
> basic-flag guard covers redefinition with its own definition. Both exits resume the original send; the Symbol is
> passed directly only when conversion can be skipped.

> r4686108643: Done: a `GetCref` instruction loads the cref from the frame's EP and `GuardBitEquals` checks that
> its refinements are nil, exiting with recompile otherwise. It stays a per-call guard because a top-level `using`
> can add refinements to the cref after the code is compiled (tested). With that, the `vm_args.c` extraction is
> gone and the PR touches only ZJIT.

Fresh execution on the dev build (`--enable-zjit=dev --disable-install-doc --disable-yjit`, `make -j2`), x86-64:

| Command/check | Confirm result |
| --- | --- |
| `make zjit-test ZJIT_TESTS='--test-threads=2'` | 2,052 run; 2,051 pass, one SIGABRT, 15 skipped |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | 2,148/2,148 |
| Same btest at threshold 2 | 2,148/2,148 |
| `make test-all TESTS='test/ruby/test_zjit_cli.rb'` | 34 tests, 7,907 assertions, no failure/error/skip |
| Same 11 core files, ZJIT threshold 1 | 1,380 tests, 64,214 assertions, no failure/error, one skip |
| Existing `zs1_probe.rb`: t1, t2p1, default, plus `N=40` default | Four interpreter comparisons identical (612/3,502 stdout lines); normalized stderr identical |
| Four round-2 probes: t1, t2p1, default | 12/12 interpreter comparisons identical |
| Same 144-case redefinition/refinements/GC matrix | 144/144 match the uncompiled JIT-enabled interpreter control |
| Forced compaction before/after same-definition redefinition | 2/2 interpreter comparisons identical |
| Delete only the basic-bit guard | 19 tests: 14 pass, identity regression and four snapshots fail |
| Restore exact head; Symbol-block filter | 19/19, Ruby source diff empty |
| `make zjit-bindgen` | Generated bindings byte-identical |

The only full-suite failure is the same `test_profile_frames_during_direct_jit_to_jit_entry` SIGPROF abort
("rb_profile_frames was not called from SIGPROF handler"), reproduced with base Rust source in the prior pass;
it is not reported as a passing test. Matrix controls retain the prior JIT-enabled builtin-selection qualification.
Logs and probe outputs are in `.amp/in/orb-backup/zs1-review/round3/` in the same review orb. No new benchmark or
arm64 run; no speed claim added. XrXr's requested HIR speculation shape now has no remaining blocker from this
review; acceptance remains his decision. Nothing pushed to Ruby or posted.

#### thermos-opus on `bdcfceb5ee`: changes (2026-11-25)

Review orb [T-01a211e6-8d3e-7275-8670-15f9b0547aa7](https://ampcode.com/threads/T-01a211e6-8d3e-7275-8670-15f9b0547aa7).
Both Thermos rubrics applied personally, without subagents or other threads, to the whole
`f63048e942..bdcfceb5ee` PR. Bundle SHA-256 `208954879c51b0c9202b9abefc99545f496f793a79b8e755e3b1eb8eb9ae7f2b`,
`git bundle verify` passes, the fetch gives `bdcfceb5eecaa0b7060f2df13958308ea8690624` with parent `05ae429a7b` on
`f63048e942`; authors, committer and the one `Co-authored-by` trailer as recorded; no message line over 72
characters. Nothing pushed to Ruby or posted.

**Shape against XrXr's two comments.** The `Symbol#to_proc` part is now what he asked for: `PatchPoint
MethodRedefined` and `RootBoxOnly` are the existing speculation machinery, and the old run-time helper
(`rb_zjit_symbol_block_handler` on `aa36fa0ea4`) is gone. The extra `GuardAnyBitSet` on the CME's flags is needed,
not a leftover run-time check: `method_entry_set` (`vm_method.c:1574–1588`) reuses an equal definition, clears the
basic bit and invalidates nothing, so no patch point can fire. Making that path invalidate would be a VM change and,
under one concern per PR, its own PR; the guard is a load and a test, and the commit message says why it is there.
For the cref, no existing HIR instruction loads one (the only `cref` use in HIR is `ic_cref` of a constant cache),
so a new `GetCref` is the direct reading of "a guard that loads cref and makes this nil check". Nit: `GetCref` is a
C call (`rb_vm_get_cref`) on every specialized send; for a local EP it is a load of `ep[VM_ENV_DATA_INDEX_ME_CREF]`
plus the method-entry case, so a reviewer may ask for an inline walk later. Not a blocker for "to start".

**Must fix — a caller that is already refined degrades the whole method.** "Once code runs under a cref, generally
the set of refinements active is stable" cuts both ways: code compiled under `using` keeps its refinements. On this
head such a caller is specialized anyway (the compile does not look at the cref), the guard exits with recompile,
the next version makes the same choice from the same profile, and after the version limit (4) ZJIT compiles a
`no_side_exits` version, which also drops every unrelated speculation in that method. On master the same send just
stays dynamic. [`refined_method_cost.rb`](../../bench/upstream/zs1/round3/opus/refined_method_cost.rb) (a method under
`using` with `box.v + a.sum(&:double) + box.v * 3`, 200,000 calls, dev build, `--zjit --zjit-stats`):

| | master `f63048e942` | head `bdcfceb5ee` |
| --- | --- | --- |
| `compiled_iseq_count` | 2 | 8 |
| `side_exit_count` (all `unhandled_block_arg`) | 0 | 30 |
| getivar fallback `no_side_exits` | 0 | 399,738 |
| `rb_vm_send` | 199,971 | 199,869 |
| wall, `N=3000000`, three runs | 3.74 / 3.60 / 3.59 s | 3.93 / 3.96 / 3.91 s |

The same file without `using` (`MOD=plain`) compiles once and specializes on the head. Wall times are a dev build
and only indicate the direction; no speed claim. Results are identical to the interpreter; this is a performance
regression against master for refined code, which a refinements-heavy gem or app hits on every such send site.

Smallest fix: once the cref guard has exited in an ISEQ, compile its next version without the Symbol
specialization (one bit in the ISEQ payload, set on that exit), and keep the guard for a `using` that arrives later.
Checking the entering frame's cref at compile time alone would not cover stub-compiled or inlined callees, whose
cref differs. The bit is new per-ISEQ state, so the tracker rule in DECISIONS may apply; that is the coordinator's
call. Reply 2's "It stays a per-call guard" sentence is then still true and needs one more: "A version compiled
after the guard has exited leaves the send dynamic, so code that runs under `using` is not recompiled again."

**Checked and found correct.** Interpreter against ZJIT at threshold 1, threshold 2 with one profile, default, and
threshold 1 with `--zjit-inline-budget=0`: 13 `Symbol#to_proc` mutations after compile (none, same definition,
`public`, `private`+`public`, empty and defining `prepend`, `include`, `alias_method :to_proc, :to_proc`, alias and
redefinition, a Symbol singleton attempt, an unused `refine(Symbol)`, `GC.verify_compaction_references`, same
definition plus `GC.compact`), each checking Proc identity after a cache eviction, `lambda?` and the result through
an ISEQ, a fixed-arity C and a variadic C callee: all identical. Ruby frames with unusual crefs (an ISEQ from
`InstructionSequence.compile`/`load_from_binary`, `define_method`, `instance_exec`, `instance_eval` string, a thread,
a fiber, `eval` with a binding, `class_eval` block, a Ractor, `Method#to_proc`): identical, no `rb_bug`. A refined
method inlined into an unrefined caller and the reverse keep their own cref (`GetCref` sits after
`PushInlineFrame`, reading the callee's EP): identical. `using` after compile and a later `refine` that redefines
the refined method: identical. Mutations: deleting the flag guard fails 5 of 21 `symbol_block` tests (the identity
test and four snapshots), deleting the cref guard fails 7 of 21, and passing `state` instead of `exit_state` to the
C-call stack-overflow check fails `test_stack_overflow_exit_from_send_with_normalized_keywords` (`no implicit
conversion of Array into Proc`), so each piece has a test. Restored head: 21/21, source diff empty.

**Text.** Body paragraph 2: true on this head (the specialized shapes, the Symbol as block handler, basic
`Symbol#to_proc`, no box, the refinements exit, `yield` unchanged). Paragraph 3: true. The benchmark table and stats
are from `fbbb9cee7b`; the railsbench rerun in round 3 moves the same counters, so they still describe the change,
but a reader may ask (nit: one line saying so, or rerun). Commit 1's message: every sentence matches the code,
including "Both guards exit to the original send and recompile"; with the fix it would need "and after an exit of
the cref guard the send stays dynamic". Commit 2's message: matches the tests. Reply 1: correct as is, sentence by
sentence ("C helper check" is the removed conversion helper, not `GetCref`'s call). Reply 2: correct for this head,
but without the fix XrXr can fairly answer that a per-call guard which recompiles forever under a stable
refinement is the case he meant; use the extended text above once the fix lands.

Fresh execution, dev build (`--enable-zjit=dev --disable-install-doc --disable-yjit`), x86-64:

| Command | Result |
| --- | --- |
| `make zjit-test ZJIT_TESTS='--test-threads=2'` | 2,052 run, 2,051 pass, 15 skipped; one SIGABRT `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames was not called from SIGPROF handler"), as in the earlier passes |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | 2,148/2,148 |
| Same at threshold 2 | 2,148/2,148 |
| `test_zjit_cli.rb` | 34 tests, 7,907 assertions, 0 failures |
| 11 core files at threshold 1 | 1,380 tests, 64,214 assertions, 0 failures, 1 skip |

Probes are in [`round3/opus/`](../../bench/upstream/zs1/round3/opus/). No arm64 run, no new benchmark.

### Round 4 for thermos-opus (2026-11-25)

Head `5b3e0d0be52c2d20b2dab51a82ee7868b57200a1` on master `a43519979c` (round 3 rebased cleanly), pushed as
`thomasklemm/ruby` `thomasklemm/zjit-symbol-block-arg-4`; the PR branch is untouched. `d43d039601` "ZJIT: Send
Symbol block arguments directly" (Rafael as author, Thomas as co-author), `5b3e0d0be5` "ZJIT: Test sends with a
Symbol block argument" (Thomas). Patches in [`round4/`](../../bench/upstream/zs1/round4/).

**Existing machinery checked first.** `exit_recompile` only counts exits per compiled unit
(`num_exits_until_invalidate`) and does not know which guard exited; the profile records operand types, not exits;
`CompilePolicy::no_side_exits` is all-or-nothing. The only "don't speculate this again" state is
`was_invalidated_for_singleton_class_creation` on `IseqPayload`, set by the `NoSingletonClass` patch point. So the fix
follows that pattern with one more payload bool; there is no flags field to reuse. This is new per-ISEQ state, for
XrXr to judge in the reply.

Change against `bdcfceb5ee` (+23 −2 in 5 files):

* The cref guard exits with a new `SideExitReason::BlockArgRefinements` (counter `exit_block_arg_refinements`).
* `SideExitRecompile` gets `refined_iseq`, set only for that reason to the frame state's ISEQ, so an inlined callee
  marks itself, not its caller. The exit calls `exit_block_arg_refinements` (a `c_callable`) before `exit_recompile`,
  which sets `IseqPayload::exited_for_block_arg_refinements`.
* `type_specialize` skips the Symbol specialization when that bit is set on the send's ISEQ; the send stays dynamic
  (`send_block_arg_not_nil`). The guard stays for a `using` that arrives after the code is compiled.
* Commit 1's message gains: "After the cref guard has exited in an ISEQ, its next version leaves these sends dynamic,
  so code that runs under `using` is not recompiled again."

[`refined_method_cost.rb`](../../bench/upstream/zs1/round3/opus/refined_method_cost.rb), dev build, `--zjit --zjit-stats`:

| | master `f63048e942` | `bdcfceb5ee` (rebased) | head `5b3e0d0be5` |
| --- | --- | --- | --- |
| `compiled_iseq_count` | 2 | 8 | 4 |
| `side_exit_count` | 0 | 30 (`unhandled_block_arg`) | 5 (`block_arg_refinements`) |
| getivar fallback `no_side_exits` | 0 | 399,738 | 0 |
| `rb_vm_send` | 199,971 | 199,869 | 199,966 |

`MOD=plain`: 1 compiled, 0 exits on the head, specialized. The five exits are the `exit_recompile` budget of the one
specialized version before it is invalidated.

Verification (dev build, x86-64): `make zjit-test` 2,051 of 2,052 (SIGPROF test only); `make btest` at thresholds 1
and 2 2,148 of 2,148; `test_zjit_cli.rb` 34 tests, 0 failures; 11 core files at threshold 1 1,380 tests, 0 failures,
1 skip; `zs1_probe.rb` identical at threshold 1, threshold 2 with one profile, default and `N=40`; the four round-2
probes and the six round-3 Opus probes identical in the interpreter and at thresholds 1, 2 and default. railsbench:
the same counters as round 3 (`send_block_arg_not_nil` 2,200,733, `rb_vm_send` 4,289,569), `no_side_exits` as master,
no `block_arg_refinements` exit.

`GetCref` as an inline walk: possible, since the EP level is known at compile time, but `vm_env_cref` dispatches on
the imemo type (cref, method entry with `def->body.iseq.cref`, svar at the local level) at every level, so it would be
several loads and branches plus offsets for the method definition. Not built; the C call keeps `vm_env_cref`'s exact
rules.

Reply drafts (for Thomas after review):

> r4686073773: The C helper check is gone. `MethodRedefined` covers replacement of `Symbol#to_proc`, and a HIR
> basic-flag guard covers redefinition with its own definition. Both exits resume the original send; the Symbol is
> passed directly only when conversion can be skipped.

> r4686108643: Done: a `GetCref` instruction loads the cref from the frame's EP and `GuardBitEquals` checks that its
> refinements are nil, exiting with recompile otherwise. It stays a per-call guard because a top-level `using` can add
> refinements to the cref after the code is compiled (tested). A version compiled after the guard has exited leaves
> the send dynamic, so code that runs under `using` is not recompiled again. With that, the `vm_args.c` extraction is
> gone and the PR touches only ZJIT.

#### thermos-astra on `bdcfceb5ee`: correctness approved (2026-11-25)

Review [thread](https://ampcode.com/threads/T-01a21206-053e-70de-a4ac-3bbadd53e8c0). Both Thermos rubrics applied
personally, without subagents or other threads, to the full two-commit range
`f63048e94229b4bab276e01bac4902f9b6a74ace..bdcfceb5eecaa0b7060f2df13958308ea8690624`. Fetched the exact fork branch
`thomasklemm/zjit-symbol-block-arg-3`, checked both parent links and read the complete implementation/test diff.
The existing review record was part of the brief; its conclusions were not used as evidence of correctness.

**No additional correctness or maintainability must-fix; no new nit.** This approves the correctness work on
this head, not submission of round 3: Opus's already-recorded recompilation/performance blocker remains open.
The coordinator explicitly assigned its fix to round 4 and asked this pass not to duplicate that investigation.
Round 4 needs its own confirm; this pass does not approve unseen changes.

**Why the direct handler is equivalent in the accepted case.**
[`vm_caller_setup_arg_block`](https://github.com/thomasklemm/ruby/blob/bdcfceb5eecaa0b7060f2df13958308ea8690624/vm_args.c#L1147-L1196)
already returns the Symbol itself when `Symbol#to_proc` is basic and the caller has no refinements. Delaying
materialization in the callee therefore preserves the interpreter's timing, cache eviction, Proc identity and
lambda-ness in precisely that case. The specialization does not substitute a Proc for a Symbol or change yield
dispatch. A non-basic conversion must run before the callee, even if its definition is the original C function;
the basic-bit guard now enforces that distinction.

Guard and lifetime audit:

* The static-Symbol type/profile guard excludes dynamic Symbols and arbitrary `to_proc` objects. Existing
  argument-shape and receiver/callee guards still control eligibility. The `no_side_exits` check avoids emitting
  new deoptimization guards in a version that forbids them.
* `MethodRedefined` protects replacement; the extra basic-bit load covers equal-definition replacement that
  clears the bit in place without invalidation (`vm_method.c:1574–1588`). The compile-time predicate and the
  HIR helper both use `rb_callable_method_entry(Symbol, to_proc)`, exactly the entry used by
  `rb_method_basic_definition_p` (`vm_method.c:3643–3648`). Neither the flag guard nor the patch point alone is
  sufficient. `RootBoxOnly` plus the compile-time box check preserves the conservative box boundary.
* Compiled C-header assertions confirm `METHOD_ENTRY_BASIC_FLAG`'s source mapping: `IMEMO_FL_USER2` is
  `RUBY_FL_USER7`, value 524288; callable-entry flags are at byte 0; cref refinements are at byte 8. The flags
  load is a memory read, and `GuardAnyBitSet` branches on zero, not on the opposite condition.
* The CME is `Const::Value`, inferred as `CallableMethodEntry`, not an unmanaged C pointer. The x86-64 backend
  emits it through `emit_load_gc_value`; `append_gc_offsets` applies the write barrier, marking visits every
  retained version, and compaction rewrites the embedded VALUE. The arm64 backend has the same tracked-value
  path, inspected but not executed here. Compaction before and after eight method mutations passed at three
  JIT settings, including the no-mutation control that keeps using the compiled entry.
* `GetCref` is a nonallocating walk of the current frame's EP. Its memory-read effect conflicts with inline
  frame changes and ordinary Ruby calls, so it is not incorrectly reused across them. The nil guard covers
  later `using`; refined `Symbol#to_proc` also keeps interpreter behavior. Valid executing Ruby frames have a
  cref: ISEQ methods supply one even when their input is null (`vm_method.c:1105–1126`), top-level frames install
  one (`vm.c:950–953`), and cloned environments synthesize one (`proc.c:4524–4526`). C-created IFUNC environments
  can have `Qfalse` there, but are not Ruby ISEQ frames executing this instruction.
* All three call forms give the guards the original-send snapshot. Their direct-call frame state omits the
  consumed block argument; their overflow exit must not. Operand traversal includes both snapshots and the
  Symbol operand. Mutation of both C-call overflow checks demonstrated that the CLI regression catches using
  the stripped state by mistake. Suspended fiber and Ractor frames retain their accepted Symbol handler when
  `Symbol#to_proc` is subsequently replaced; the next send observes the replacement.

**Maintainability.** The guard policy has one shared HIR helper, and the lower-level block handler reuses the
existing VALUE representation. The small `block_arg_symbol` helper removes the duplicated match at the two
C-call sites. `GetCref` belongs beside `GetEP`; no VM conversion wrapper or new per-ISEQ state was added by this
head. The two-state distinction is necessary, not accidental optionality. No touched file crosses the 1,000-line
threshold. New enum/field documentation explains representation and snapshot contracts; the two guard comments
explain otherwise non-obvious semantic exceptions. No additional comment deletion or structural change requested.
Ruby complexity metrics would not assess this Rust enum/match change meaningfully.

**Independent probes.** `probe.rb` has 20 scenarios, each warmed 100 times where applicable. It compares plain
interpreter output against uncompiled JIT-enabled execution (threshold 1,000,000), thresholds 1 and 2 (the latter
with one profile), default options and threshold 2 with inlining disabled: 100 comparisons. It covers reading,
storing and forwarding `&b`, `block_given?`, `yield`, `super`, `define_method`, `proc`, `Proc.new` and a Proc
subclass; cache eviction and identity; duck-typed receivers with `method_missing`/`respond_to_missing?`; private
methods, arity errors and exception backtrace labels/line numbers; asymmetric keywords; dynamic Symbols and
polymorphic block arguments; redefinition during argument evaluation and during the callee; late `using` and
refined conversion; suspended fibers, Ractors, TracePoint activation, binary-loaded ISEQs and eval bindings.
`compact.rb` adds eight mutation cases with forced compaction before and after the change, and
`ractor_suspend.rb` replaces conversion on the main Ractor while another Ractor is suspended inside the callee.
Those add 27 comparisons. All 127 match the plain interpreter, with no failed subprocess. No builtin-selection
normalization was needed for these probes. A HIR dump of the cache case confirms the compiled `SendDirect`,
tracked CME, basic-bit guard, `GetCref` and refinements guard; these were not merely cold-interpreter comparisons.

Fresh execution, x86-64, `--enable-zjit=dev --disable-install-doc --disable-yjit`, `make -j2`:

| Command/check | Result |
| --- | --- |
| `make zjit-test ZJIT_TESTS='--test-threads=2'` | 2,052 run: 2,051 pass, one SIGABRT, 15 skipped |
| Base Rust control, same lockfile and native archive | 2,034 run: 2,033 pass, the same SIGABRT, 15 skipped |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | 2,148/2,148 |
| Same btest at threshold 2 | 2,148/2,148 |
| `make test-all TESTS='test/ruby/test_zjit_cli.rb'` | 34 tests, 7,907 assertions, no failures/errors/skips |
| 11 core files, `RUN_OPTS='--zjit --zjit-call-threshold=1'` | 1,380 tests, 64,214 assertions, no failures/errors, one skip |
| Independent differential probes | 127/127 comparisons match; repeated after restoring exact head |
| Delete only `GuardAnyBitSet` in the Symbol helper | 5/19 Symbol tests fail: identity behavior plus four HIR snapshots |
| Delete only the cref `GuardBitEquals` | 7/19 fail: three behavioral tests plus four HIR snapshots |
| Use stripped `state` for both C-call overflow exits | CLI overflow regression fails with `TypeError: no implicit conversion of Array into Proc` |
| Restore exact head, rebuild, rerun Symbol filter | 19/19 pass; source diff empty |
| Restored overflow regression | One test, 26 assertions, no failures/errors/skips |

The full-suite failure on both head and base is `test_profile_frames_during_direct_jit_to_jit_entry`,
"rb_profile_frames was not called from SIGPROF handler". The base control builds the base's `zjit`, `jit` and
`yjit` Rust sources against this build's `libminiruby.a`; the only C change in the PR is a declaration. This is
not a separate base-C build. The 11 core files are proc, refinement, symbol, method, call, yield, lambda, array,
enum, settracefunc and backtrace. btest prints its existing `Fiber count: 10000 (skipping)` diagnostic; both
runs conclude `PASS all 2148 tests`. No arm64 execution or new benchmark in this review.

**Wrong-variant controls are behavioral, not only snapshot checks.** With the basic-bit guard deleted,
`CASE=cache` prints `[true, true, true, 8]` in the interpreter but `[false, true, true, 8]` at thresholds 1, 2 and
default. With the cref guard deleted, `CASE=late_using` prints `[107, [107], 107]` in the interpreter but
`[8, [8], 107]` in all three JIT modes. The restored head gives the interpreter result in every mode. The
variadic element in the latter mutation remains correct; the ISEQ and fixed-C elements distinguish the bug.

Reproduction material is retained in `.amp/in/orb-backup/zs1-astra/` in the review thread: `probe.rb`,
`compare.py`, `compact.rb`, `ractor_suspend.rb`, `supplement.py`, `layout.c`, the three `wrong-*.patch` files,
outputs and `logs/`. Steps: clone the pinned fork branch into that directory's `ruby/`; run `autogen.sh`, configure
with the flags above and build; run `python3 compare.py` and `python3 supplement.py`; apply one wrong patch at a
time, rebuild and run the named case/filter; restore the changed source from the pinned head, rebuild and repeat
the comparisons. The overflow filter is
`TESTS='test/ruby/test_zjit_cli.rb -n /test_stack_overflow_exit_from_send_with_normalized_keywords/'`.
No Ruby source change, push or public comment was retained or made.

After the independent audit, read XrXr's two actual review comments via GitHub's API. The new HIR speculation and
cref/nil guard match the requested shape. The body and commit messages accurately describe the accepted call
forms and guards; historical benchmark rows explicitly name an older head and were not remeasured or certified
by this correctness pass. Acceptance of the final revision remains the maintainer's decision.

#### thermos-astra confirm on `5b3e0d0be5`: changes (2026-11-25)

Same [review thread](https://ampcode.com/threads/T-01a21206-053e-70de-a4ac-3bbadd53e8c0), both rubrics personally,
no delegation. Exact fork head `5b3e0d0be52c2d20b2dab51a82ee7868b57200a1`, two commits on
`a43519979c7a8fbb9c5bbcf8d7b1daf739a60c4f`. Compared old and new base trees separately: their changes are outside
ZJIT; the review delta is the stated +23 −2 in five Rust files. Rebuilt with the same dev configuration.

**Must fix — the new payload update is unsynchronized across Ractors.**
[`exit_block_arg_refinements`](https://github.com/thomasklemm/ruby/blob/5b3e0d0be52c2d20b2dab51a82ee7868b57200a1/zjit/src/codegen.rs#L4013-L4019)
calls `get_or_create_iseq_payload` and stores into a plain `bool` without acquiring the VM lock.
`c_callable!` selects the calling convention; it does not lock. The payload is shared by executions of the
same ISEQ in different Ractors, and
[`payload_ptr_as_mut`](https://github.com/thomasklemm/ruby/blob/5b3e0d0be52c2d20b2dab51a82ee7868b57200a1/zjit/src/payload.rs#L143-L151)
explicitly requires exclusive access under the VM lock. Two unsynchronized stores of `true` are still a Rust
data race; writing the same value is not a synchronization mechanism.

**Direct evidence on the unmodified head:** `r4_ractors.rb` starts four Ractors that repeatedly call one refined
method. GDB stopped at the new callback and inspected its ISEQ argument and `rb_vm_locked_p()`. Twelve captured
entries alternated between native threads 3 and 4, all with ISEQ `0x7fffde888dc0` and lock result `0`. The ordinary
run returns `[28000, 28000, 28000, 28000]`, matching the interpreter. This is evidence of a reachable unlocked
shared write, not a claim that this run produced a wrong Ruby result or crashed. The diagnostic uses
`--zjit-num-exits-until-invalidate=1000000` to keep the same compiled guard live for repeated observations; a
separate run with the default exit budget also reaches the callback unlocked. The high budget is not required
for the defect.

Smallest fix: wrap this callback's payload update in `with_vm_lock(src_loc!(), || { ... })`. A temporary local
patch did that: GDB at the assignment then returned lock result `1`, all 19 Symbol tests passed, and the
four-Ractor and inline/compaction/churn probes retained their interpreter results. The existing
`exit_recompile` fast path also accesses payload state outside its later lock; that code predates this delta
and is not charged to this PR. It is not a justification for introducing another unprotected write. Combining
the callbacks under a single properly scoped lock would also be reasonable, but is a larger change than the
validated wrapper. The patch was removed and the exact head rebuilt; no Ruby change was committed or pushed.

**Inlining and lifetime otherwise check out.**

* `refined_iseq` is the side-exit frame's ISEQ, while `compiled_iseq` remains the outer compiled unit. The two
  roles are correct: remember the refusal on the leaf, invalidate the unit that actually contains the guard.
  `type_specialize` queries the same frame-state ISEQ. The new field participates in `SideExitRecompile`'s
  equality/hash, so exit deduplication does not discard this distinction.
* `r4_lifetime.rb` actually inlines the refined leaf. After the exit, its HIR shows
  `PushInlineFrame :leaf_refined` followed by a dynamic Symbol send, then `PopInlineFrame`, while the unrefined
  parent's `Array#sum(&:succ)` remains a guarded `CCallVariadic`. This checks the ownership decision rather than
  only the final number. The script then forces compaction, calls that code again, and creates/removes 20 fresh
  refined modules with collection/compaction between them; results stay `22` and `:lifetime_ok`.
* The new ISEQ operand is `Opnd::Value`, so the existing embedded-VALUE marking/compaction path retains and
  updates it even when the refined method is inlined. The flag has no Ruby reference to mark, defaults to false
  on a fresh payload, and is freed with that payload by `rb_zjit_iseq_free`; there is no separate address-keyed
  flag table that could survive ISEQ address reuse. It is conservative across call sites and Ractors: a marked
  ISEQ can lose specialization, but never skips the interpreter conversion.
* GDB reports `sizeof(IseqPayload) == 152` on both the base control and round 4, so this compiler uses existing
  padding for the extra bool. The lifetime/churn run with default JIT options reports `zjit_alloc_bytes=82075`
  at exit. That is an absolute diagnostic, not a whole-program memory or performance comparison.

Fresh exact-head results: `make zjit-test` 2,051/2,052, 15 skipped, the same SIGPROF abort; btest at thresholds
1 and 2 each 2,148/2,148; CLI 34 tests/7,907 assertions, no failures/errors/skips. The original 127 differential
comparisons still match, as do six additional interpreter comparisons of the Ractor and lifetime probes at
thresholds 1/2/default. After removing the temporary locking patch, the Symbol filter passes 19/19 and the
Ruby source diff is empty. No arm64 run and no new speed claim.

**No additional nit.** Apart from the synchronization defect, using existing side-exit machinery and one
monotonic payload bit is a small, understandable fix; the original correctness guards remain intact. The tests
exercise the old guards but ordinary output comparisons cannot detect this race, as the passing Ractor output
demonstrates. A lock-invariant check or sanitizer coverage is needed to verify that part of a future fix.

Additional reproduction files in the same scratch directory: `r4_ractors.rb`, `r4_lifetime.rb`, `lock.gdb`,
`r4-lock-threads.txt`, `r4-fixed-lock-gdb.txt`, `r4-lock-fix.patch`, `r4-lifetime-hir.out` and round-4 logs. Run
`gdb -q -batch -x ../lock.gdb ./ruby` from the Ruby build for the unlocked-entry diagnostic. The debugger locks
scheduling only during its call to the read-only lock query, then resumes all threads. This report's two
verdicts are therefore: round 3 correctness approved with its previously known performance blocker; round 4
changes required for the newly introduced shared-state write.

#### thermos-opus confirm on `5b3e0d0be5`: changes, the VM lock only (2026-11-25)

Same review orb as the round-3 pass, both rubrics personally. Fetched `thomasklemm/zjit-symbol-block-arg-4`: exactly
`5b3e0d0be52c2d20b2dab51a82ee7868b57200a1`, two commits on `a43519979c`, authors, committer and the one
`Co-authored-by` as before, no message line over 72 characters. Nothing pushed to Ruby or posted.

**Rebase.** `git range-diff f63048e942..bdcfceb5ee a43519979c..5b3e0d0be5`: the test commit is `=`, and the ZJIT
commit differs only in the fix (payload bool, `SideExitReason::BlockArgRefinements` and its counter,
`SideExitRecompile::refined_iseq`, `exit_block_arg_refinements`, the `type_specialize` check, one message sentence).
No other hunk moved.

**My round-3 must-fix is resolved.** `refined_method_cost.rb`: 4 compiles, 5 exits (`block_arg_refinements`), no
`no_side_exits` fallback; `MOD=plain` 1 compile, 0 exits. New probe
[`inlined_refined_cost.rb`](../../bench/upstream/zs1/round3/opus/inlined_refined_cost.rb) (the refined method inlined
into an unrefined caller with its own ivar speculation): 4 compiles, 5 exits, the HIR of the last version keeps the
caller's ivar loads and leaves only the inlined `sum(&:double)` dynamic. So marking the frame state's ISEQ is right
and the caller does not keep recompiling. Mutations: marking `jit.iseq()` instead gives 4/10 and 5/15
(compiles/exits), and dropping the `type_specialize` check brings back 8/30 and 11/44; no test fails for either
(21/21), which is expected under DECISIONS' no-internal-state rule, since only compile and exit counts change.

**Must fix — agree with Astra's finding.** `exit_block_arg_refinements` calls `get_or_create_iseq_payload` and
writes the bool without the VM lock, from generated code that any Ractor can run. `payload_ptr_as_mut`'s own SAFETY
note (`payload.rs:146`) assumes the VM lock; without it two threads hold `&mut IseqPayload` at once (UB in Rust), and
on an ISEQ with no payload yet two threads could both allocate and set one. The `with_vm_lock` fix in `-5` is the
right one and matches `exit_recompile`'s slow path. (`exit_recompile`'s fast path also decrements its counter before
taking the lock; that is master's code, not this PR's.) My Ractor probe
[`ractor_gc_refined.rb`](../../bench/upstream/zs1/round3/opus/ractor_gc_refined.rb) matched the interpreter 9/9
times, which does not disprove a race.

**GC and ISEQ free.** `refined_iseq` is an `Opnd::Value` of the ISEQ in exit code, so it goes through the same GC
offset marking and compaction update as `compiled_iseq`; the bool is plain data freed with the payload in
`rb_zjit_iseq_free`. Forced compaction in the Ractor probe: identical.

**Reply 2.** The coordinator's text is true on this head and on `-5`. Put the question last so the answer the PR
gives comes first:

> r4686108643: Done: a `GetCref` instruction loads the cref from the frame's EP and `GuardBitEquals` checks that its
> refinements are nil, exiting with recompile otherwise. It stays a per-call guard because a top-level `using` can add
> refinements to the cref after the code is compiled (tested). After that guard exits, the ISEQ's next version leaves
> the send dynamic, so code that runs under `using` isn't recompiled again. With that, the `vm_args.c` extraction is
> gone and the PR touches only ZJIT. Leaving the send dynamic needed one new bool on `IseqPayload`, next to
> `was_invalidated_for_singleton_class_creation`; would you rather track that differently?

Reply 1 unchanged and correct.

| Command | Result |
| --- | --- |
| `make zjit-test ZJIT_TESTS='--test-threads=2'` | 2,052 run, 2,051 pass, 15 skipped; the SIGPROF abort only |
| `make btest` at `--zjit-call-threshold=1` and `=2` | 2,148/2,148 each |
| `test_zjit_cli.rb` | 34 tests, 7,907 assertions, 0 failures |
| Opus probes (7 files × 4 settings) | 28/28 identical to the interpreter |
| 13 `Symbol#to_proc` mutations × 3 settings | 39/39 identical |
| Ractor and compaction probe × 3 settings × 3 runs | 9/9 identical |
| Restored head after mutations | source diff empty |
