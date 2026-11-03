# Action View CPU time (bet V1)

Bet R2 ([framework census](rails-framework-census.md)) found that Action View's remaining allocations are required
output. This bet looks at **CPU time** instead: where rendering spends it in real apps and on ruby-bench, and
whether exact Rails changes make it measurably faster.

**Result: one candidate, C1, and one held variant, C2. Both remove the same overhead: the way every HTML escape
reaches erb's C escape.** `ERB::Util.unwrapped_html_escape` is an alias of a method that calls erb's
`ERB::Escape.html_escape` through `super` from a module prepended to `ERB::Util`'s singleton class. That costs an
alias dispatch and a `super` lookup per call in the interpreter. Under YJIT it is worse: YJIT does not specialize
`super` in a method defined on a singleton class (`invokesuper` fallback reason `singleton_class`, 97% of all
`super` calls on erubi-rails), so every escape is a dynamic send.

| # | Branch | Commit | Change | Per `<%= %>` (ns, main → branch) | ruby-bench Ir per iteration (A/A) |
| --- | --- | --- | --- | --- | --- |
| C1 | [`thomasklemm/output-buffer-escape`](https://github.com/thomasklemm/rails/tree/thomasklemm/output-buffer-escape) | [`3fdf00ef79`](https://github.com/thomasklemm/rails/commit/3fdf00ef7960c58c5a81166d6b10e21556134e01) | `OutputBuffer#<<` calls `ERB::Escape.html_escape` for a value it already knows is an unsafe String | interp 146 → **89**, YJIT 66 → **51** | erubi-rails interp **−9.9%** (+0.1%), YJIT **−5.0%** (+0.1%); 4.1dev **−10.0%** (−0.1%) / **−7.8%** (−0.3%); railsbench interp **−0.9%** (+0.2%) |
| C2 (held) | [`thomasklemm/erb-util-escape-direct`](https://github.com/thomasklemm/rails/tree/thomasklemm/erb-util-escape-direct) | [`157be38ca0`](https://github.com/thomasklemm/rails/commit/157be38ca0acb901bbfa86acfe8588ee68c5496f) | `unwrapped_html_escape` calls `ERB::Escape.html_escape` instead of `super` | `unwrapped_html_escape` of an unsafe String: interp 78 → **71**, YJIT 55 → **43** | erubi-rails interp **−5.2%**, YJIT **−4.8%**; 4.1dev **−1.4%** / **−6.5%**; railsbench interp **−0.8%** |

Ir = instructions counted by Valgrind (pinned `script/bench-valgrind` build). Wall time on this orb has A/A swings
of up to ±30% per run, so instruction counts are the primary evidence; wall time is reported alongside.

**Decision needed (C1 and C2):** both bypass `super`, which #46573 (k0kubun) chose deliberately so that escaping stays
"permissive about other monkey patches using `Module#prepend`". A module prepended to `ERB::Util` *before* Active
Support loads would no longer see the bypassed calls (C1: template appends only; C2: every escape). Modules prepended
after Active Support never saw them. C1 is the narrow form and is recommended; C2 is held because it reverses that
design for all escapes.

## Pins and method

* **Rails:** canonical `rails/rails` main [`e64b660612`](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76)
  (merge of #59552, 2026-11-03). Both branches are one commit on it.
* **Ruby:** 4.0.7 (mise) and 4.1.0dev master [`64d821e685`](https://github.com/ruby/ruby/commit/64d821e685) (built
  with `--enable-yjit`). Interpreter and `--yjit`.
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2), `erubi-rails` and `railsbench`,
  bundled against local Rails worktrees through a `Gemfile.VARIANT` per variant (`gem RAILS_GEM, path:`) plus `prism`;
  the lock differs between variants only in the worktree paths. Rails main's 8.2 defaults compile ERB with Herb, so
  "erubi-rails" renders through Herb's compiler; `<%= %>` compiles to `@output_buffer.append=(…)`, an alias of
  `OutputBuffer#<<`, in both.
* **Census apps:** `script/census setup --rails e64b660612…` for Blog, Campfire, Writebook, Fizzy (SQLite) and Lobsters;
  every workload passed `list`.
* **Profiler:** stackprof 0.2.28 (raw stacks), wall mode, 250 µs; it builds and runs on 4.0.7 and 4.1dev (vernier
  1.12.0 also builds on both; stackprof was used because its raw stacks give self and total per frame directly).
  "self + C" charges C functions to the nearest Ruby caller (`String#gsub` inside `html_escape` counts for
  `html_escape`); GC frames stay separate.
* **Workloads profiled:** ruby-bench's own loop (10 warmup iterations, then 10 profiled), and each census app's page
  workloads (GET pages and Turbo stream POSTs: 50 warmup rounds, then 100 profiled rounds), interleaved per round.
* **Tooling** (`bench/upstream/actionview_cpu/`):
  [`profile.rb`](../../bench/upstream/actionview_cpu/profile.rb) (stackprof → frames and per-stack counts),
  [`rank.rb`](../../bench/upstream/actionview_cpu/rank.rb) (rankings and area tables),
  [`ruby_bench_harness.rb`](../../bench/upstream/actionview_cpu/ruby_bench_harness.rb),
  [`census_profile.rb`](../../bench/upstream/actionview_cpu/census_profile.rb),
  [`census_counts.rb`](../../bench/upstream/actionview_cpu/census_counts.rb) (calls per page),
  [`ruby_bench_ab.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ab.rb) (interleaved wall time with A/A),
  [`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb) and
  [`census_ir.rb`](../../bench/upstream/actionview_cpu/census_ir.rb) /
  [`census_ir_run.rb`](../../bench/upstream/actionview_cpu/census_ir_run.rb) (Valgrind instruction counts),
  [`erubi_paired.rb`](../../bench/upstream/actionview_cpu/erubi_paired.rb) (paired in-process wall time),
  [`micro_output_buffer.rb`](../../bench/upstream/actionview_cpu/micro_output_buffer.rb).
  Raw profiles, Ir logs and wall-time JSON are in `.lowrail/private/actionview-cpu/` (not checked in).

## Where the time goes

Share of samples by area (self + C), Ruby 4.0.7. Action View is 6–17% of a page in the apps and 38% of erubi-rails;
Action Pack's share is mostly routing, URL generation and controller dispatch.

**Interpreter**

| Area (self + C) | blog-interpreter | campfire-interpreter | fizzy-interpreter | lobsters-interpreter | writebook-interpreter | railsbench-interpreter | erubi-rails-interpreter |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| activerecord | 18.4% | 34.9% | 44.8% | 29.9% | 45.3% | 16.6% | 0.0% |
| activesupport | 16.4% | 13.1% | 15.7% | 18.6% | 15.0% | 16.8% | 16.7% |
| gems | 21.9% | 21.3% | 14.2% | 13.7% | 12.2% | 16.1% | 5.1% |
| actionview | 16.5% | 8.7% | 8.8% | 11.5% | 6.6% | 11.3% | 38.0% |
| actionpack | 17.4% | 6.4% | 3.8% | 11.3% | 6.5% | 26.4% | 13.7% |
| GC (marking, sweeping) | 3.4% | 3.7% | 2.6% | 2.7% | 3.8% | 5.6% | 12.3% |
| activemodel | 2.4% | 4.2% | 3.9% | 5.6% | 5.2% | 2.9% | 0.0% |
| Ruby stdlib/other | 2.4% | 2.5% | 2.1% | 1.7% | 3.4% | 1.9% | 2.0% |
| templates (compiled) | 0.6% | 0.5% | 0.6% | 1.5% | 0.6% | 0.6% | 10.7% |
| app | 0.0% | 3.2% | 2.7% | 3.3% | 1.3% | 0.2% | 1.5% |
| railties | 0.7% | 0.2% | 0.1% | 0.2% | 0.0% | 1.4% | 0.0% |
| actiontext | 0.1% | 0.7% | 0.4% | 0.0% | 0.0% | 0.1% | 0.0% |
| activejob | 0.0% | 0.3% | 0.2% | 0.0% | 0.0% | 0.0% | 0.0% |
| activestorage | 0.0% | 0.2% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| actioncable | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| C with no Ruby caller | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |

**YJIT**

| Area (self + C) | blog-yjit | campfire-yjit | fizzy-yjit | lobsters-yjit | writebook-yjit | railsbench-yjit | erubi-rails-yjit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| activerecord | 12.2% | 24.3% | 40.2% | 24.8% | 38.5% | 9.3% | 0.0% |
| gems | 24.0% | 23.5% | 17.2% | 16.3% | 16.8% | 24.0% | 5.4% |
| activesupport | 16.8% | 11.0% | 13.8% | 18.2% | 14.3% | 17.0% | 15.7% |
| actionview | 16.0% | 8.5% | 8.3% | 11.2% | 6.0% | 9.5% | 29.1% |
| actionpack | 15.7% | 4.8% | 2.8% | 9.5% | 6.1% | 20.1% | 11.4% |
| GC (marking, sweeping) | 6.3% | 12.6% | 4.8% | 5.2% | 5.7% | 10.9% | 23.8% |
| Ruby stdlib/other | 5.9% | 5.2% | 4.6% | 4.4% | 6.2% | 4.0% | 3.9% |
| activemodel | 1.9% | 2.9% | 3.4% | 4.6% | 3.8% | 2.4% | 0.0% |
| templates (compiled) | 0.7% | 1.9% | 1.0% | 2.3% | 0.6% | 1.1% | 9.2% |
| app | 0.1% | 4.1% | 3.3% | 3.3% | 1.9% | 0.2% | 1.5% |
| railties | 0.5% | 0.2% | 0.1% | 0.3% | 0.0% | 1.6% | 0.0% |
| actiontext | 0.0% | 0.7% | 0.4% | 0.0% | 0.0% | 0.0% | 0.0% |
| activejob | 0.0% | 0.1% | 0.2% | 0.0% | 0.0% | 0.0% | 0.0% |
| activestorage | 0.0% | 0.2% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| actioncable | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| C with no Ruby caller | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |

**Ruby 4.1dev** (ruby-bench only; the census apps were profiled on 4.0.7)

| Area (self + C) | erubi-rails-interpreter-r41 | railsbench-interpreter-r41 | erubi-rails-yjit-r41 | railsbench-yjit-r41 |
| --- | ---: | ---: | ---: | ---: |
| actionview | 38.9% | 11.8% | 33.5% | 10.1% |
| actionpack | 15.7% | 26.7% | 12.5% | 20.7% |
| activesupport | 17.9% | 17.8% | 18.5% | 17.7% |
| gems | 6.4% | 17.0% | 7.4% | 24.8% |
| GC (marking, sweeping) | 5.5% | 2.6% | 12.4% | 7.3% |
| activerecord | 0.0% | 16.5% | 0.0% | 10.0% |
| templates (compiled) | 11.8% | 0.6% | 10.1% | 1.1% |
| Ruby stdlib/other | 2.2% | 2.0% | 4.2% | 3.7% |
| activemodel | 0.0% | 3.1% | 0.0% | 2.7% |
| app | 1.5% | 0.2% | 1.3% | 0.2% |
| railties | 0.0% | 1.5% | 0.0% | 1.7% |
| actiontext | 0.0% | 0.1% | 0.0% | 0.1% |

## Ranking: Action View and the rendering path

Frames in `actionview/`, Action Pack's routing/URL/rendering files and Active Support's SafeBuffer/ERB::Util, ranked
by mean self + C share over seven profiles (each profile weighs the same). Total = share of samples with the frame
on the stack. Reach = profiles where the frame has ≥ 0.1% self + C or ≥ 0.5% total.

### Interpreter, Ruby 4.0.7

| Frame | self % | self+C % | total % | reach | blog-interpreter | campfire-interpreter | fizzy-interpreter | lobsters-interpreter | writebook-interpreter | railsbench-interpreter | erubi-rails-interpreter |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ActionView::OutputBuffer#<< (actionview/lib/action_view/buffers.rb:44)` | 1.44 | 1.54 | 2.5 | 7/7 | 0.6 | 0.4 | 0.4 | 0.6 | 0.5 | 0.6 | 7.7 |
| `ActionView::OutputBuffer#safe_concat (actionview/lib/action_view/buffers.rb:58)` | 1.06 | 1.06 | 1.1 | 7/7 | 0.3 | 0.2 | 0.2 | 0.4 | 0.2 | 0.2 | 6.1 |
| `ActiveSupport::CoreExt::ERBUtil#html_escape (activesupport/lib/active_support/core_ext/erb/util.rb:11)` | 0.63 | 0.97 | 1.1 | 7/7 | 0.5 | 0.3 | 0.4 | 0.6 | 0.3 | 0.4 | 4.4 |
| `ActionView::Helpers::TagHelper::TagBuilder#tag_options (actionview/lib/action_view/helpers/tag_helper.rb:1543)` | 0.65 | 0.94 | 2.9 | 6/7 | 1.5 | 1.0 | 1.0 | 1.8 | 0.8 | 0.4 | 0.0 |
| `ActionView::Helpers::TagHelper::TagBuilder#append_tag_option (actionview/lib/action_view/helpers/tag_helper.rb:1630)` | 0.74 | 0.86 | 1.6 | 6/7 | 1.4 | 0.9 | 1.0 | 1.7 | 0.6 | 0.3 | 0.0 |
| `ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper::OptimizedUrlHelper#call (actionpack/lib/action_dispatch/routing/route_set.rb:227)` | 0.30 | 0.43 | 3.6 | 6/7 | 0.7 | 0.3 | 0.2 | 0.8 | 0.4 | 0.6 | 0.0 |
| `String#html_safe (activesupport/lib/active_support/core_ext/string/output_safety.rb:244)` | 0.22 | 0.41 | 0.7 | 7/7 | 0.5 | 0.2 | 0.2 | 0.4 | 0.2 | 0.2 | 1.3 |
| `ActionDispatch::Journey::Format#add_to (actionpack/lib/action_dispatch/journey/visitors.rb:48)` | 0.26 | 0.38 | 0.6 | 6/7 | 0.4 | 0.2 | 0.2 | 0.8 | 0.5 | 0.6 | 0.0 |
| `ERB::Util.xml_name_escape (activesupport/lib/active_support/core_ext/erb/util.rb:157)` | 0.11 | 0.35 | 0.5 | 6/7 | 0.5 | 0.3 | 0.5 | 0.7 | 0.3 | 0.2 | 0.0 |
| `ActionView::Helpers::AssetUrlHelper#asset_path (actionview/lib/action_view/helpers/asset_url_helper.rb:189)` | 0.16 | 0.33 | 0.8 | 5/7 | 0.3 | 0.7 | 0.3 | 0.7 | 0.4 | 0.0 | 0.0 |
| `AbstractController::Rendering#view_assigns (actionpack/lib/abstract_controller/rendering.rb:60)` | 0.12 | 0.33 | 0.3 | 4/7 | 0.2 | 0.1 | 0.1 | 0.1 | 0.0 | 0.5 | 1.3 |
| `ActionView::AbstractRenderer#prepend_formats (actionview/lib/action_view/renderer/abstract_renderer.rb:175)` | 0.05 | 0.32 | 1.0 | 2/7 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 2.1 |
| `ActiveSupport::SafeBuffer#initialize (activesupport/lib/active_support/core_ext/string/output_safety.rb:72)` | 0.09 | 0.32 | 0.3 | 7/7 | 0.4 | 0.2 | 0.2 | 0.2 | 0.1 | 0.1 | 1.0 |
| `ActionView::LookupContext#formats= (actionview/lib/action_view/lookup_context.rb:280)` | 0.07 | 0.31 | 0.7 | 2/7 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.2 | 1.9 |
| `ActionView::Helpers::TagHelper::TagBuilder#content_tag_string (actionview/lib/action_view/helpers/tag_helper.rb:1532)` | 0.29 | 0.31 | 2.2 | 6/7 | 0.4 | 0.2 | 0.3 | 0.6 | 0.3 | 0.3 | 0.0 |
| `ActionView::Template#render (actionview/lib/action_view/template.rb:325)` | 0.23 | 0.23 | 54.8 | 7/7 | 0.3 | 0.1 | 0.1 | 0.0 | 0.1 | 0.3 | 0.7 |
| `ActionView::Base#assign (actionview/lib/action_view/base.rb:315)` | 0.09 | 0.22 | 0.2 | 3/7 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 1.2 |
| `ActionView::Base#_run (actionview/lib/action_view/base.rb:351)` | 0.09 | 0.22 | 54.3 | 7/7 | 0.4 | 0.1 | 0.2 | 0.1 | 0.1 | 0.3 | 0.4 |
| `ActionView::OutputBuffer#initialize (actionview/lib/action_view/buffers.rb:24)` | 0.06 | 0.19 | 0.2 | 4/7 | 0.2 | 0.1 | 0.1 | 0.0 | 0.0 | 0.2 | 0.7 |
| `ActionView::Helpers::CaptureHelper#capture (actionview/lib/action_view/helpers/capture_helper.rb:56)` | 0.17 | 0.19 | 26.9 | 6/7 | 0.0 | 0.1 | 0.1 | 0.1 | 0.1 | 0.0 | 0.9 |
| `ActionView::PathSet#search_combinations (actionview/lib/action_view/path_set.rb:68)` | 0.11 | 0.18 | 0.8 | 5/7 | 0.2 | 0.1 | 0.1 | 0.0 | 0.0 | 0.3 | 0.5 |
| `ActionView::Helpers::TagHelper#ensure_valid_html5_tag_name (actionview/lib/action_view/helpers/tag_helper.rb:1862)` | 0.02 | 0.18 | 0.2 | 4/7 | 0.2 | 0.1 | 0.1 | 0.4 | 0.2 | 0.3 | 0.0 |
| `ActionController::UrlFor#url_options (actionpack/lib/action_controller/metal/url_for.rb:36)` | 0.16 | 0.17 | 0.5 | 4/7 | 0.3 | 0.1 | 0.1 | 0.2 | 0.1 | 0.4 | 0.0 |
| `ActionDispatch::Http::URL.path_for (actionpack/lib/action_dispatch/http/url.rb:168)` | 0.10 | 0.15 | 0.2 | 5/7 | 0.2 | 0.1 | 0.1 | 0.3 | 0.1 | 0.2 | 0.0 |
| `ActionView::LookupContext#initialize_details (actionview/lib/action_view/lookup_context.rb:270)` | 0.13 | 0.15 | 0.6 | 2/7 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.2 | 0.7 |

### YJIT, Ruby 4.0.7

| Frame | self % | self+C % | total % | reach | blog-yjit | campfire-yjit | fizzy-yjit | lobsters-yjit | writebook-yjit | railsbench-yjit | erubi-rails-yjit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ActionView::OutputBuffer#safe_concat (actionview/lib/action_view/buffers.rb:58)` | 1.32 | 1.32 | 1.3 | 7/7 | 0.3 | 0.2 | 0.2 | 0.8 | 0.3 | 0.3 | 7.1 |
| `ActiveSupport::CoreExt::ERBUtil#html_escape (activesupport/lib/active_support/core_ext/erb/util.rb:11)` | 0.67 | 1.23 | 1.3 | 7/7 | 0.5 | 0.3 | 0.4 | 0.7 | 0.3 | 0.7 | 5.9 |
| `ActionView::OutputBuffer#<< (actionview/lib/action_view/buffers.rb:44)` | 0.85 | 0.96 | 2.0 | 7/7 | 0.5 | 0.4 | 0.4 | 0.5 | 0.5 | 0.7 | 3.6 |
| `ActionView::Helpers::TagHelper::TagBuilder#tag_options (actionview/lib/action_view/helpers/tag_helper.rb:1543)` | 0.35 | 0.89 | 2.6 | 6/7 | 1.4 | 1.1 | 0.9 | 1.6 | 0.8 | 0.5 | 0.0 |
| `ActionView::Helpers::TagHelper::TagBuilder#append_tag_option (actionview/lib/action_view/helpers/tag_helper.rb:1630)` | 0.71 | 0.81 | 1.5 | 6/7 | 1.5 | 0.8 | 0.8 | 1.6 | 0.5 | 0.3 | 0.0 |
| `ActionView::AbstractRenderer#prepend_formats (actionview/lib/action_view/renderer/abstract_renderer.rb:175)` | 0.01 | 0.50 | 1.3 | 2/7 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.1 | 3.3 |
| `String#html_safe (activesupport/lib/active_support/core_ext/string/output_safety.rb:244)` | 0.02 | 0.49 | 0.8 | 7/7 | 0.8 | 0.2 | 0.3 | 0.4 | 0.2 | 0.3 | 1.2 |
| `ActionView::Helpers::AssetUrlHelper#asset_path (actionview/lib/action_view/helpers/asset_url_helper.rb:189)` | 0.18 | 0.44 | 1.0 | 5/7 | 0.4 | 0.8 | 0.4 | 1.1 | 0.4 | 0.0 | 0.0 |
| `AbstractController::Rendering#view_assigns (actionpack/lib/abstract_controller/rendering.rb:60)` | 0.08 | 0.43 | 0.5 | 4/7 | 0.2 | 0.2 | 0.1 | 0.1 | 0.0 | 0.7 | 1.7 |
| `ActionView::LookupContext#formats= (actionview/lib/action_view/lookup_context.rb:280)` | 0.01 | 0.43 | 0.9 | 2/7 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 | 0.2 | 2.7 |
| `ActionView::Helpers::TagHelper::TagBuilder#content_tag_string (actionview/lib/action_view/helpers/tag_helper.rb:1532)` | 0.36 | 0.40 | 2.0 | 6/7 | 0.8 | 0.3 | 0.4 | 0.7 | 0.4 | 0.4 | 0.0 |
| `ERB::Util.xml_name_escape (activesupport/lib/active_support/core_ext/erb/util.rb:157)` | 0.02 | 0.40 | 0.4 | 6/7 | 0.6 | 0.4 | 0.5 | 0.7 | 0.3 | 0.3 | 0.0 |
| `ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper::OptimizedUrlHelper#call (actionpack/lib/action_dispatch/routing/route_set.rb:227)` | 0.14 | 0.34 | 2.6 | 6/7 | 0.4 | 0.2 | 0.1 | 0.7 | 0.3 | 0.7 | 0.0 |
| `ActiveSupport::SafeBuffer#initialize (activesupport/lib/active_support/core_ext/string/output_safety.rb:72)` | 0.04 | 0.34 | 0.3 | 7/7 | 0.3 | 0.2 | 0.2 | 0.3 | 0.1 | 0.2 | 1.1 |
| `ActionView::Base#assign (actionview/lib/action_view/base.rb:315)` | 0.10 | 0.30 | 0.3 | 2/7 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.2 | 1.7 |
| `ActionDispatch::Journey::Format#add_to (actionpack/lib/action_dispatch/journey/visitors.rb:48)` | 0.28 | 0.28 | 0.6 | 6/7 | 0.3 | 0.2 | 0.1 | 0.5 | 0.4 | 0.4 | 0.0 |
| `ActionView::Helpers::TagHelper#ensure_valid_html5_tag_name (actionview/lib/action_view/helpers/tag_helper.rb:1862)` | 0.01 | 0.26 | 0.3 | 6/7 | 0.4 | 0.1 | 0.1 | 0.5 | 0.3 | 0.4 | 0.0 |
| `ActionView::Base#_run (actionview/lib/action_view/base.rb:351)` | 0.04 | 0.25 | 51.6 | 7/7 | 0.3 | 0.2 | 0.3 | 0.1 | 0.1 | 0.4 | 0.4 |

### Ruby 4.1dev (erubi-rails, railsbench; interpreter and YJIT)

| Frame | self % | self+C % | total % | reach | erubi-rails-interpreter-r41 | railsbench-interpreter-r41 | erubi-rails-yjit-r41 | railsbench-yjit-r41 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `ActionView::OutputBuffer#safe_concat (actionview/lib/action_view/buffers.rb:58)` | 3.88 | 3.88 | 3.9 | 4/4 | 6.0 | 0.2 | 8.9 | 0.4 |
| `ActionView::OutputBuffer#<< (actionview/lib/action_view/buffers.rb:44)` | 3.25 | 3.61 | 6.8 | 4/4 | 8.3 | 0.7 | 4.6 | 0.8 |
| `ActiveSupport::CoreExt::ERBUtil#html_escape (activesupport/lib/active_support/core_ext/erb/util.rb:11)` | 1.94 | 3.11 | 3.2 | 4/4 | 4.7 | 0.3 | 6.7 | 0.7 |
| `ActionView::AbstractRenderer#prepend_formats (actionview/lib/action_view/renderer/abstract_renderer.rb:175)` | 0.11 | 1.14 | 3.7 | 4/4 | 1.5 | 0.1 | 2.8 | 0.2 |
| `ActionView::LookupContext#formats= (actionview/lib/action_view/lookup_context.rb:280)` | 0.14 | 1.01 | 2.8 | 4/4 | 1.3 | 0.2 | 2.4 | 0.1 |
| `AbstractController::Rendering#view_assigns (actionpack/lib/abstract_controller/rendering.rb:60)` | 0.28 | 0.96 | 1.0 | 4/4 | 1.2 | 0.4 | 1.5 | 0.7 |
| `ActionView::Base#assign (actionview/lib/action_view/base.rb:315)` | 0.38 | 0.90 | 0.9 | 4/4 | 1.2 | 0.1 | 2.1 | 0.2 |
| `String#html_safe (activesupport/lib/active_support/core_ext/string/output_safety.rb:244)` | 0.18 | 0.76 | 1.3 | 4/4 | 1.2 | 0.2 | 1.4 | 0.3 |
| `ActionController::Renderers::All#_all_renderers (actionpack/lib/action_controller/metal/renderers.rb:66)` | 0.07 | 0.73 | 0.9 | 4/4 | 0.9 | 0.3 | 1.3 | 0.4 |
| `ActiveSupport::SafeBuffer#initialize (activesupport/lib/active_support/core_ext/string/output_safety.rb:72)` | 0.13 | 0.62 | 0.6 | 4/4 | 0.9 | 0.1 | 1.2 | 0.2 |
| `ActionView::LookupContext#initialize_details (actionview/lib/action_view/lookup_context.rb:270)` | 0.53 | 0.57 | 1.9 | 4/4 | 0.9 | 0.2 | 0.9 | 0.3 |
| `ActionView::OutputBuffer#initialize (actionview/lib/action_view/buffers.rb:24)` | 0.11 | 0.52 | 0.5 | 4/4 | 0.7 | 0.3 | 0.8 | 0.4 |
| `block in <class:LookupContext> (actionview/lib/action_view/lookup_context.rb:45)` | 0.18 | 0.51 | 1.2 | 4/4 | 0.7 | 0.3 | 0.7 | 0.3 |
| `ActionView::Base#_run (actionview/lib/action_view/base.rb:351)` | 0.15 | 0.45 | 32.1 | 4/4 | 0.6 | 0.3 | 0.4 | 0.5 |
| `ActionController::Renderers#_render_to_body_with_renderer (actionpack/lib/action_controller/metal/renderers.rb:173)` | 0.14 | 0.41 | 1.3 | 4/4 | 0.6 | 0.2 | 0.7 | 0.2 |

**Reading.** No Action View frame takes more than 1.8% of any app's samples; the time is spread over the append
path (`OutputBuffer#<<`, `safe_concat`, `ERBUtil#html_escape`, `String#html_safe`, `SafeBuffer#initialize`: 1.5–3%
per app, ~20% of erubi-rails) and tag attributes (`tag_options`, `append_tag_option`, `xml_name_escape`,
`content_tag_string`: 2–4.5% in Blog, Fizzy and Lobsters). Route generation is next (`OptimizedUrlHelper#call`,
`Journey::Format#add_to`), then per-render setup that matters only on erubi-rails (`prepend_formats`/`formats=`,
`view_assigns`/`assign`, `_all_renderers`). Compiled template methods themselves are 0.5–1.5% in apps and 10–12% of
erubi-rails.

### Calls per page

From [`census_counts.rb`](../../bench/upstream/actionview_cpu/census_counts.rb) (interpreter, after warmup, mean of 3
operations). `ERBUtil#html_escape` counts every `unwrapped_html_escape`/`html_escape` call;
`OutputBuffer#<<` every `<%= %>` (safe or not).

| App | Page | `OutputBuffer#<<` | `ERBUtil#html_escape` | `safe_concat` | `xml_name_escape` | `ensure_valid_html5_tag_name` |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Blog | GET articles | 34 | 133 | 45 | 87 | 27 |
| Blog | GET article | 30 | 133 | 39 | 95 | 26 |
| Campfire | GET room | 26 | 201 | 37 | 157 | 23 |
| Campfire | GET sidebar | 21 | 185 | 30 | 141 | 21 |
| Writebook | GET book | 118 | 528 | 177 | — | — |
| Writebook | GET leaf | 98 | 422 | 163 | — | — |
| Fizzy | GET board | 350 | 2,069 | 442 | 1,513 | 153 |
| Fizzy | GET card | 129 | 1,075 | 178 | 837 | 115 |
| Lobsters | GET home | 921 | 2,504 | 1,500 | 1,425 | 466 |
| Lobsters | GET story | 445 | 1,056 | 1,085 | 576 | 173 |
| railsbench | GET /posts (1 of 102 requests) | — | — | 708 | 601 | 301 |
| erubi-rails | one render | 77 (59 unsafe) | 73 | 131 | 0 | 0 |

## C1: `OutputBuffer#<<` escapes without rechecking

```diff
       def <<(value)
         unless value.nil?
           value = value.to_s
           @raw_buffer << if value.html_safe?
             value
           else
-            ERB::Util.unwrapped_html_escape(value)
+            # The value is a String known not to be html_safe, so escape it
+            # directly instead of repeating those checks in unwrapped_html_escape.
+            ERB::Escape.html_escape(value)
           end
         end
         self
       end
```

**Why it is faster.** `unwrapped_html_escape` repeats `to_s` and `html_safe?` (a Ruby method on Object) and reaches
the C escape through an alias and `super`. Callgrind on 200 erubi-rails renders (interpreter): the instructions
removed are in `vm_search_super_method`, `vm_call_alias`, `vm_call_iseq_setup`, `vm_callee_setup_arg` and the frame
pushes, about 930 per call; erubi-rails makes 73 such calls per render, 71 of them from the buffer. Under YJIT the
`super` is an unspecialized fallback on both Rubies (`--yjit-stats`: `invokesuper fallback reasons: singleton_class
7,200,299 (97.3%)` on 4.0.7 over 6 iterations); C1 halves `num_send_dynamic` (13.55 M → 6.45 M on 4.0.7, 8.09 M →
3.83 M on 4.1dev).

**Per call** ([`micro_output_buffer.rb`](../../bench/upstream/actionview_cpu/micro_output_buffer.rb), quiet orb,
best of 7 × 1,000,000 appends, ns):

| `buf.append = value` | interp main → C1 | YJIT main → C1 | 4.1dev YJIT main → C1 |
| --- | ---: | ---: | ---: |
| unsafe String, nothing to escape | 146 → **89** | 66 → **51** | 72 → **56** |
| unsafe String with `<&` | 207 → **147** | 144 → **94** | 128 → **108** |
| Integer | 170 → **118** | 111 → **81** | 103 → **83** |
| SafeBuffer (control) | 69 → 71 | 35 → 36 | 38 → 39 |
| `nil` (control) | 28 → 29 | 5 → 5 | 5 → 5 |

**ruby-bench, instructions per iteration** ([`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb):
default harness, `WARMUP_ITRS=2`, `MIN_BENCH_ITRS` 1 and 4, difference over 3 iterations; main-b is a second copy
of main):

| Ruby | Benchmark | Mode | Samples | A/A (main-b) | C1 | C2 |
| --- | --- | --- | ---: | --- | --- | --- |
| 4.0.7 | erubi-rails | interpreter | 1 | +0.12% | -9.95% | -5.20% |
| 4.0.7 | erubi-rails | yjit | 4 | **+0.08%** (+0.4, +0.0, +0.1, +0.0) | **-4.99%** (-0.9, -6.1, -4.1, -5.8) | **-4.77%** (-0.2, -4.7, -4.9, -5.3) |
| 4.0.7 | railsbench | interpreter | 1 | +0.15% | -0.86% | -0.81% |
| 4.1dev | erubi-rails | interpreter | 1 | -0.06% | -10.03% | -1.44% |
| 4.1dev | erubi-rails | yjit | 4 | **-0.26%** (-1.0, +0.2, -0.3, -0.3) | **-7.82%** (-8.2, -12.6, -7.3, -7.4) | **-6.53%** (-7.2, -3.9, -6.8, -6.2) |
| 4.1dev | railsbench | interpreter | 1 | -0.67% | -1.13% | -1.74% |

YJIT rows: the median of four samples (one with 3 measured iterations, then one with 3 and two with 9), each
sample a fresh pair of processes per variant; the first sample is the outlier in every column. Interpreter counts
are one sample each; their A/A stays within ±0.7%.

railsbench under YJIT is not measurable this way: its A/A moves −4.4%, +11.9% and +13.7% between processes (also
with 5 warmup iterations), so its row is left out.

**ruby-bench, wall time** ([`ruby_bench_ab.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ab.rb): default
harness, 10 warmup + 20 timed iterations, median per run; 5 rounds, order rotated per round; Δ = median over rounds of
variant / main-a − 1):

| Ruby | Benchmark | Mode | Variant | Rounds | main-a ms | Variant ms | Δ median | Δ range |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| r40 | erubi-rails | interpreter | c1 | 5 | 1112.3 | 1020.1 | -7.52% | -15.86 … -2.39% |
| r40 | erubi-rails | interpreter | main-b | 5 | 1112.3 | 1086.3 | -5.59% | -16.38 … -0.02% |
| r40 | erubi-rails | yjit | c1 | 5 | 520.8 | 440.9 | -17.81% | -18.61 … +4.54% |
| r40 | erubi-rails | yjit | main-b | 5 | 520.8 | 537.5 | +3.20% | -12.22 … +7.98% |
| r40 | railsbench | interpreter | c1 | 5 | 2137.3 | 1944.7 | -1.49% | -28.74 … +35.84% |
| r40 | railsbench | interpreter | main-b | 5 | 2137.3 | 1938.6 | -2.26% | -28.68 … +11.34% |
| r40 | railsbench | yjit | c1 | 5 | 906.9 | 792.8 | -12.58% | -22.12 … +33.24% |
| r40 | railsbench | yjit | main-b | 5 | 906.9 | 966.1 | +4.11% | -15.09 … +30.99% |

The wall-time A/A rows swing by up to ±30% between runs, so these numbers only agree in direction with the
instruction counts. The erubi-rails YJIT row (−17.8%) is larger than the Ir change (−5.0%) supports and is not
claimed. A paired in-process check ([`erubi_paired.rb`](../../bench/upstream/actionview_cpu/erubi_paired.rb): C1's
method defined at run time, 20 ABBA pairs of 2,000 renders) gave interpreter **−6.9%** (A/A −3.7%) and YJIT
**−2.2%** (A/A −0.6%).

**Census (allocations).** `script/census run --label c1` on the five apps, compared with `base2` (A/A `base`): median
+0.0 objects per workload in both modes; workloads moved ≤ −1 / ≥ +1: 9 / 6 interpreter, 9 / 10 YJIT (A/A 11 / 10,
12 / 7). SQL digests changed on 3 / 5 workloads (A/A 2 / 1), all Fizzy comment writes, Fizzy `GET cards.json` and
Lobsters' vote toggle, the workloads whose digests also flip between A/A runs. Objects per erubi-rails render: 165.06
(interpreter) and 167.06 (YJIT) on both main and C1.

**Census apps, instructions per round of GET pages** ([`census_ir_run.rb`](../../bench/upstream/actionview_cpu/census_ir_run.rb):
one native priming run, then Valgrind runs with 2 and 62 rounds, difference over 60; one sample):

| App | Mode | Variant | main-a Ir/round | Variant Ir/round | Δ |
| --- | --- | --- | ---: | ---: | ---: |
| blog | interpreter | c1 | 2.657e+07 | 2.675e+07 | +0.67% |
| campfire | interpreter | c1 | 5.163e+07 | 5.154e+07 | -0.18% |
| fizzy | interpreter | c1 | 3.567e+08 | 3.722e+08 | +4.35% |
| lobsters | interpreter | c1 | 4.621e+08 | 4.582e+08 | -0.83% |
| writebook | interpreter | c1 | 1.129e+08 | 1.129e+08 | +0.02% |
| blog | interpreter | c2 | 2.657e+07 | 2.673e+07 | +0.59% |
| campfire | interpreter | c2 | 5.163e+07 | 5.155e+07 | -0.16% |
| fizzy | interpreter | c2 | 3.567e+08 | 3.72e+08 | +4.29% |
| lobsters | interpreter | c2 | 4.621e+08 | 4.593e+08 | -0.59% |
| writebook | interpreter | c2 | 1.129e+08 | 1.129e+08 | +0.07% |
| blog | interpreter | main-b | 2.657e+07 | 2.69e+07 | +1.23% |
| campfire | interpreter | main-b | 5.163e+07 | 5.145e+07 | -0.35% |
| fizzy | interpreter | main-b | 3.567e+08 | 3.729e+08 | +4.52% |
| lobsters | interpreter | main-b | 4.621e+08 | 4.601e+08 | -0.43% |
| writebook | interpreter | main-b | 1.129e+08 | 1.13e+08 | +0.08% |
| blog | yjit | c1 | 3.461e+07 | 3.482e+07 | +0.62% |
| campfire | yjit | c1 | 4.736e+07 | 4.314e+07 | -8.92% |
| fizzy | yjit | c1 | 2.346e+08 | 2.354e+08 | +0.34% |
| lobsters | yjit | c1 | 2.761e+08 | 2.745e+08 | -0.58% |
| writebook | yjit | c1 | 8.003e+07 | 7.888e+07 | -1.43% |
| blog | yjit | c2 | 3.461e+07 | 3.504e+07 | +1.24% |
| campfire | yjit | c2 | 4.736e+07 | 5.049e+07 | +6.61% |
| fizzy | yjit | c2 | 2.346e+08 | 2.339e+08 | -0.30% |
| lobsters | yjit | c2 | 2.761e+08 | 2.738e+08 | -0.84% |
| writebook | yjit | c2 | 8.003e+07 | 7.668e+07 | -4.18% |
| blog | yjit | main-b | 3.461e+07 | 3.467e+07 | +0.17% |
| campfire | yjit | main-b | 4.736e+07 | 4.458e+07 | -5.87% |
| fizzy | yjit | main-b | 2.346e+08 | 2.356e+08 | +0.44% |
| lobsters | yjit | main-b | 2.761e+08 | 2.763e+08 | +0.07% |
| writebook | yjit | main-b | 8.003e+07 | 7.408e+07 | -7.43% |

**Inconclusive.** The A/A pair moves by up to +4.5% (Fizzy, interpreter) and −7.4% (Writebook, YJIT), more than
C1 can change a page: from the call counts, Lobsters' home page makes ~920 unsafe appends, about 0.9 M of its
~140 M interpreter instructions (≈0.6%). The apps' own state (caches, sessions, background timers) varies between processes
more than Valgrind's counting does. No app-level claim is made; the breadth claim rests on the call counts and on
ruby-bench.

**Suites.** Action View `bin/test` (all groups) 3,352 runs, 0 failures, 0 errors, `RAILS_STRICT_WARNINGS=1`, Ruby
4.0.7; RuboCop clean on the changed file. The only warnings printed come from Capybara.

**Exactness and boundary.** The value is already `to_s`'d and known not to be `html_safe?`; `unwrapped_html_escape`
would call `to_s` (a no-op on a String) and `html_safe?` again and then reach `ERB::Escape.html_escape` through
`super`, which is the same C function (erb 4+, shipped with every Ruby Rails supports; erb's pure-Ruby fallback
defines the same constant). Output, encoding handling (non-ASCII-compatible strings go to `CGI.escapeHTML` in both)
and the returned String are identical. **Boundary:** a module prepended to `ERB::Util`'s singleton class before
Active Support loads, or `ERB::Util.html_escape` redefined in place, no longer sees `<%= %>` appends.

**Overlap.** No open rails/rails PR touches `buffers.rb` or `erb/util.rb` (checked 2026-11-03: `gh pr list
--search OutputBuffer`, `--search unwrapped_html_escape`, and the open Action View performance PRs). Related merged
work: #45614 (OutputBuffer composition), #46573 (the `super` design), #59118 (collection buffer).

**Draft PR description:**

> Every `<%= %>` appends through `ActionView::OutputBuffer#<<`. For a value that isn't html_safe it already calls
> `to_s` and `html_safe?`, then calls `ERB::Util.unwrapped_html_escape`, which repeats both checks and reaches
> `ERB::Escape.html_escape` through an alias and `super`. YJIT can't specialize that `super` (it is defined on a
> singleton class), so each append is a dynamic send.
>
> This calls `ERB::Escape.html_escape` directly, which is the method `super` reaches, so the output is the same.
> The one boundary: a module prepended to `ERB::Util` before Active Support loads no longer sees these appends;
> modules prepended after it never did.
>
> | `<%= %>` of an unsafe String | main | this PR |
> | --- | ---: | ---: |
> | interpreter | 146 ns | 89 ns |
> | YJIT | 66 ns | 51 ns |
>
> On ruby-bench's erubi-rails this runs 9.9% fewer instructions per iteration in the interpreter and 5.0% fewer with
> YJIT (7.8% on Ruby master); a page in Fizzy or Lobsters makes 130–920 such appends.

## C2 (held): `unwrapped_html_escape` without `super`

```diff
       def html_escape(s) # :nodoc:
         s = s.to_s
         if s.html_safe?
           s
         else
-          super(s)
+          ERB::Escape.html_escape(s)
         end
       end
       alias :unwrapped_html_escape :html_escape # :nodoc:
```

The method behind every escape in Rails (`unwrapped_html_escape`, and through it `html_escape`/`h`, tag attributes,
`content_tag`, `safe_join`, `SafeBuffer#concat` and interpolation) calls erb's C escape directly instead of reaching
it through `super`. C1 removes the whole frame for template appends; C2 keeps the frame and removes only the alias
plus `super` part, but for every caller.

**Per call** (`ERB::Util.unwrapped_html_escape(value)`, ns, main → C2): 
| `ERB::Util.unwrapped_html_escape(value)` | interp 4.0.7 | YJIT 4.0.7 | interp 4.1dev | YJIT 4.1dev |
| --- | ---: | ---: | ---: | ---: |
| unsafe String, nothing to escape | 78 → **71** | 55 → **43** | 77 → **70** | 58 → **42** |
| unsafe String with `<&` | 158 → 156 | 132 → 128 | 134 → **122** | 109 → **92** |
| Symbol | 112 → 109 | 95 → **85** | 76 → **65** | 56 → **45** |
| SafeBuffer (control) | 54 → 54 | 33 → 33 | 54 → 54 | 32 → 34 |

([`micro_unwrapped_escape.rb`](../../bench/upstream/actionview_cpu/micro_unwrapped_escape.rb), best of 7 × 2,000,000.)

**ruby-bench, instructions per iteration:** see the table under C1 (rows `c2`).

**Census apps:** see the instruction table under C1 (rows `c2`); inconclusive for the same reason.

**Census (allocations):** median +0.0 in both modes; moved ≤ −1 / ≥ +1: 6 / 9 interpreter, 9 / 13 YJIT (A/A 11 / 10,
12 / 7); SQL digests changed on 2 / 2 workloads (A/A 2 / 1). **Suites:** Active Support `bin/test` 6,869 runs, 0
failures, 0 errors, 403 skips (cache stores without their services); Action View 3,352 runs, 0 failures, 0 errors;
`RAILS_STRICT_WARNINGS=1`; RuboCop clean.

**Why held.** C2 is exact for Rails and erb, but it removes the `super` that #46573 introduced on purpose, so a
module prepended to `ERB::Util` (or its singleton class) before Active Support loads no longer sees *any* escape.
That is a design question for the maintainers, not a review nit. C1 keeps `super` for every caller except template
appends. Most of C2's gain is under YJIT; a YJIT fix (see [Leads outside Rails](#leads-outside-rails)) would recover that
part without touching Rails or its `super`.

## Rejected and leads

| Idea | Numbers | Decision |
| --- | --- | --- |
| `xml_name_escape`: skip `blank?` for ASCII names that match `SAFE_XML_TAG_NAME_REGEXP` (such names can't be blank; the only safe blank names are all U+1680) | per call interp 153 → 124 ns ("class"), YJIT 88 → 90; `""` 23 → 105 ns YJIT | **Rejected**: no gain under YJIT, slower for empty names. |
| `xml_name_escape`: cheaper safe-name check (ASCII-only regex, negated class search, `String#count`) | `"data-turbo-frame"`: current regex 220 ns; ASCII regex 197, negated search 287, `count` 401 | **Rejected**: the cost is per-character regex matching, not the Unicode class; nothing cheaper is exact. A per-name cache grows with user-built attribute keys. |
| `ensure_valid_html5_tag_name`: frozen Set of standard element names before the regex (`content_tag("a")`, `tag("input")`) | regex 133 → Set 36 ns (String name, interp), 121 → 30 (YJIT); 14–27 calls on Blog pages, 19–25 Campfire, 153 Fizzy board, 466 Lobsters home; railsbench `/posts` 301 calls, but `/posts` is 1 of 102 requests | **Rejected**: 0.04–0.26% of an app page, ≈0.07% of a railsbench iteration, 0 on erubi-rails. |
| `prepend_formats`: skip re-deriving the lookup formats when the template's format already leads them | renderer path (`ApplicationController.render` without `formats:`, which keeps the 36 default formats): 6.0 µs interp / 5.4 µs YJIT per template render; with a request format `[:html]` 0.8 / 0.5 µs; 2–3% of erubi-rails | **Lead, not exact cheaply**: the skip must still validate the current formats (`render formats: [:html, :bogus]` raises only on this path) and keep the JS→HTML fallback that `with_prepended_formats([:js])` relies on; that validation is most of the cost. Only renderer-based template renders benefit. |
| `_all_renderers`: avoid `_renderers + Renderers.all` (a new Set) per controller render | 489 ns interp / 409 ns YJIT per render (`_render_to_body_with_renderer` 711 / 580 ns) | **Rejected**: < 0.1% of a railsbench request. |
| `OutputBuffer#safe_concat` (1–7% self) | already `@raw_buffer << value; self` | **No change possible**: the cost is the call itself, one per static template chunk. |
| Tag attribute building (`tag_options`, `append_tag_option`) | 2–3.5% in Blog, Fizzy, Lobsters | **Covered**: main already appends every attribute into one buffer (what #57999 proposes); what remains is `xml_name_escape` (above), `Hash#each_pair`, `blank?` and String appends. |
| Route generation (`OptimizedUrlHelper#call`, `Journey::Format#add_to`, `url_options`) | 0.4–0.8% self + C per app | **Not pursued**: reworked by merged PRs in the last week (#59470, #59479 by linyiru); `url_options` is memoized and `Format#add_to` builds into one buffer. R2-3 (URL default merge) stays held. |
| `view_assigns` / `Base#assign` | 1.2–1.7% of erubi-rails, ≤ 0.5% in apps | **Not pursued**: the String keys are public API (`view_assigns`), as R2 found. |
| `OrderedOptions#method_missing` (39 per op), `respond_to?` on the view (51 per op) | R2's numbers; 0.2–0.4% self in apps here (`asset_path`, `compute_asset_host`) | **Below the bar**, as in R2. |

## Leads outside Rails

* **YJIT:** `gen_invokesuper_specialized` gives up on any receiver whose class is a singleton class ("Don't compile
  `super` on objects with singleton class to avoid retaining the receiver", counter `invokesuper_singleton_class`),
  on 4.0.7 and master. `ERB::Util.unwrapped_html_escape` is called on the module `ERB::Util`, which has a singleton
  class (Rails prepends to it), so every escape's `super` is a dynamic send: 7.2 M fallbacks over 6 erubi-rails
  iterations on 4.0.7, 97% of all `super` calls there. A receiver that is a Class or Module lives as long as its
  constant, so specializing on it would retain nothing new; that would recover C2's YJIT part for every
  `singleton_class.prepend` pattern without changing Rails. Needs its own ruby-bench evidence (DECISIONS).

## Process notes

* The first profile set charged C functions wrongly (stackprof names their file `<cfunc>`), so `self + C` equalled
  `self`; the profiler now stores per-stack counts and `rank.rb` aggregates, and the set was rerun.
* The first wall-time round 0 ran while call-count probes used CPU (railsbench interpreter C1 +36%); later rounds ran
  with nothing else on the orb. Rounds were not discarded; the A/A rows show the resulting noise.
* An early estimate of ~100 escapes per page rejected C2 at ~0.03%; the call counts (130–2,500 per page) reopened it.
* The first ruby-bench YJIT instruction sample (C1 −0.9%) disagreed with the YJIT stats (`num_send_dynamic` halved);
  three more samples (−6.1, −4.1, −5.8%) settled it. The first app-level count run was discarded because fragment
  caches in Redis/Solid Cache were cold for the first variant; the rerun primes each pair natively first.
