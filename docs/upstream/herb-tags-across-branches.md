# Herb on 8.2 defaults: lobsters' `users/tree.html.erb` (2026-11-06)

**Recommendation: documentation only for the reported failure. Separately, fix in Herb for a whitespace divergence
found on the way; that fix isn't ready.** Herb rejects the template on purpose: it pairs HTML tags inside each branch of Ruby control flow,
and lobsters opens `<ul>`/`<li>` in one branch or iteration and closes them in another. Herb documents this as
"Elements must close in the same scope", Rails' upgrade guide says templates with structural problems fail to
compile, and `bin/rails herb:check` flags the file. Nothing is broken silently: the failure is loud, at
compile time, with the location. The Rails guide's wording ("structural problems, such as an unclosed tag")
undersells that **valid, runtime-balanced** templates are rejected too; that's the documentation gap.

Separately, the guide's "Valid templates render the same output as before" is not quite true today: Herb leaves
blank lines where Erubi trims a `<% # comment %>` line, and after a `<%# %>` line followed by a statement inside
a block. A draft Herb fix exists but regresses other shapes, so it isn't pushed (below). No upstream posts, issues or PRs; Thomas decides.

## Repro

Rails main [`8e8a9bb`](https://github.com/rails/rails/commit/8e8a9bb38bf1a64d93aae2261f37623f46933500) (four
commits after the benchmarked `cadf0fc8d6`; both lock herb 0.11.0), Ruby 4.0.9, one-file app with
`config.load_defaults "8.2"` rendering the unmodified ruby-bench template
([ad63bf8c `users/tree.html.erb`](https://github.com/ruby/ruby-bench/blob/ad63bf8cac618032adefdd1c5219636a52b47e5e/benchmarks/lobsters/app/views/users/tree.html.erb#L18-L50)):

```
app/views/users/tree.html.erb:19:7: Conditional element pattern detected at (21:10) but the conditional
block contains multiple HTML tags. ... (and 5 more errors): Encountered a syntax error while rendering
template located at: app/views/users/tree.html.erb (ActionView::SyntaxErrorInTemplate)
  from herb-0.11.0/lib/herb/engine.rb:412:in 'Herb::Engine#handle_parser_errors'
  from actionview/lib/action_view/template/handlers/erb/herb.rb:31
✘ [ConditionalElementMultipleTagsError] (19:7)   ✘ [OmittedClosingTagError] `<li>` (20:9)
✘ [MissingClosingTagError] `<ul>` (39:13)        ✘ [MissingOpeningTagError] `</li>` (41:14), `</ul>` (47:12), `</li>` (47:17)
```

Same app with `load_defaults "8.1"`, or 8.2 with `erb_implementation = :erubi`: 200, identical bytes. Herb
0.11.2 (latest) reports the same six errors. Herb's `strict: false` parser option removes only the
`OmittedClosingTagError`; Rails exposes no per-template opt-out besides switching every HTML template to Erubi.

**Minimal snippet** (Erubi compiles and renders it; Herb 0.11.0 and 0.11.2 reject it with
`MissingClosingTagError`, `MissingOpeningTagError`):

```erb
<% if open %>
  <ul>
<% else %>
  </ul>
<% end %>
```

Not every split is rejected: Herb 0.9 added "conditional element" detection, so
`<% if c %><div><% end %> … <% if c %></div><% end %>` with the same condition passes. It stops passing as soon
as the opening branch holds anything else, e.g. one `<%= %>` (discourse's case below).

## Root cause

Deliberate Herb design, not a Rails integration bug and not invalid ERB. Herb parses HTML+ERB into one tree and
requires each element to open and close in the same control-flow scope
([docs at v0.11.0](https://github.com/marcoroth/herb/blob/c54649b8c0a46c220302657be828851e37b602e5/docs/docs/language/templates.md#L63-L88):
"Herb pairs tags within each branch of Ruby control flow, not across it"). The lobsters template is a stack
machine that emits a balanced tree only at runtime; no static pairing can accept it. Rails' handler
(`ActionView::Template::Handlers::ERB::Herb`) only passes options and adapts buffer calls; the error comes from
`Herb::Engine#initialize` before Rails code is involved. Earlier Herb discussion:
[#856](https://github.com/marcoroth/herb/issues/856) (led to the 0.9 detection),
[#954](https://github.com/marcoroth/herb/issues/954) (Marco: parse errors can't be disabled, "we need a valid
document"). No rails/rails issue or PR covers it (searched "herb" in issues and PRs; the only open Herb issue is
the unrelated Ractor one, [#59153](https://github.com/rails/rails/issues/59153)).

**Already documented?** Yes, broadly:
[upgrade guide L86–L96](https://github.com/rails/rails/blob/8e8a9bb38bf1a64d93aae2261f37623f46933500/guides/source/upgrading_ruby_on_rails.md#L86-L96),
the Action View CHANGELOG, and
[`new_framework_defaults_8_2.rb.tt` L143–L156](https://github.com/rails/rails/blob/8e8a9bb38bf1a64d93aae2261f37623f46933500/railties/lib/rails/generators/rails/app/templates/config/initializers/new_framework_defaults_8_2.rb.tt#L143-L156)
all say structural problems fail to compile, point to `herb:check`, and give the `:erubi` escape hatch.
`ActionView::HerbChecker` reports `tree.html.erb` (verified). The possible doc change: name the "opened in one
branch, closed in another" case and link Herb's section, so readers don't take it for a broken template.

**Lobsters-side rewrite** (for ruby-bench, if it should run on 8.2 defaults): emit the four split tags as
strings, e.g. `<%== %(<ul class="user_tree">) %>`, `<%== "</li>" %>`, `<%== "</ul></li>" %>` and the `<li>` line.
Herb then compiles it, but the page differs from 8.1 by three blank lines, which is the divergence below. With
the Herb fix the rewritten page is byte-identical to 8.1 Erubi.

## Reach

Default branches, all `.html.erb`/`.html+*.erb` templates that Erubi compiles, compiled through Rails' Herb
handler (herb 0.11.0, `trim: true`): **144 of 6,802 fail (2.1%)**, 94 of them on tag pairing. Mastodon and
GitLab are almost all HAML (0 and 5 ERB templates); OpenProject (1,717), Campfire, Devise, Active Admin,
Spree pass completely.

| repo (SHA) | fail / templates | tag-pairing |
| --- | ---: | ---: |
| forem `c59fd562` | 42 / 800 | 30 |
| canvas-lms `1c9f0bb8` | 58 / 593 | 31 |
| decidim `32b3374d` | 12 / 1,086 | 11 |
| redmine `4dba4a79` | 11 / 438 | 6 |
| zammad `3116e46f` | 11 / 592 | 9 |
| discourse `b2d17919` | 4 / 112 | 4 |
| lobsters `36f631c0` (ruby-bench copy: 16 / 80) | 2 / 115 | 2 |
| administrate, chatwoot, solidus | 2 + 1 + 1 | 1 |

Of the 94 pairing failures, **28 are textually balanced** (equal open and close counts of the flagged tag), the
lobsters shape: valid output, split across control flow. The other 66 are real markup bugs Herb rightly catches
(`<h1 …>…</h2>` in forem admin/tags/edit, `<dev>…</div>` in a zammad mailer, `<html>` opened in a layout partial
and closed elsewhere). Examples of the balanced shape, pinned:
[lobsters tree L22–L38](https://github.com/lobsters/lobsters/blob/36f631c083baf1aa1bf0cf7ed22a8e9fe277c41c/app/views/users/tree.html.erb#L22-L38)
and [`comments/_threads` L11–L31](https://github.com/lobsters/lobsters/blob/36f631c083baf1aa1bf0cf7ed22a8e9fe277c41c/app/views/comments/_threads.html.erb#L11-L31),
[discourse `topics/show` L64–L67 and L149–L151](https://github.com/discourse/discourse/blob/b2d1791995a03498e183d2929452b762af99b305/app/views/topics/show.html.erb#L64-L67)
(`<div <%= main_entity_schema %>>` plus a `<%= %>` in the opening branch),
[redmine `issues/bulk_edit` L202–L204](https://github.com/redmine/redmine/blob/4dba4a79238191d617c4809b25e3818f966f5406/app/views/issues/bulk_edit.html.erb#L202-L204)
(`</div><div class="splitcontentright">` inside an `if`). The classification is a heuristic (tag counts, control
flow within three lines); counts are approximate, the examples were read by hand.

## Whitespace divergence and the Herb fix

Found while checking the rewrite. Herb 0.11.0 (and main `37b2325d`) differ from Erubi with trim:

| template | Erubi | Herb |
| --- | --- | --- |
| `<p>\n  <% # a comment %>\n  hi\n</p>\n` | `<p>\n  hi\n</p>\n` | `<p>\n  \n  hi\n</p>\n` |
| `<% if a %>\n  <%# c %>\n  <% b = 1 %>\n  hi\n<% end %>\n` | `  hi\n` | `  \n  hi\n` |

1. `visit_erb_content_node` returns early for a Ruby-comment tag
   ([v0.11.0 compiler.rb L231–L232](https://github.com/marcoroth/herb/blob/c54649b8c0a46c220302657be828851e37b602e5/lib/herb/engine/compiler.rb#L231-L232)),
   so its line is never trimmed. Erubi treats it as a statement and drops the line.
2. After a trimmed `<%#` line, the indentation token before the next statement is emptied and
   `at_line_start?` ([L747](https://github.com/marcoroth/herb/blob/c54649b8c0a46c220302657be828851e37b602e5/lib/herb/engine/compiler.rb#L747))
   no longer sees the newline, so the statement line isn't trimmed.

HTML-insignificant whitespace in most places, but visible in `<pre>`, text mail parts and byte-compared
fixtures, and it contradicts "renders the same output". `<% # %>` alone on a line occurs in Active Admin,
Forem, Canvas, lobsters and a Rails test fixture. With the fix, 35 of 6,722 Herb-compiled corpus templates get
different compiled source (0.5%).

A draft fix (two commits on Herb main `37b2325d`, v0.11.2) is saved as
[`data/herb-erb-comment-line-trim.draft.patch`](data/herb-erb-comment-line-trim.draft.patch). It is **not pushed**
to a fork, because the skeptical review found regressions:

* `3be0ea49` Trim a statement line after an ERB comment line in a block (`at_line_start?` also accepts a newline
  the previous trim consumed).
* `b0bc44da` Trim a line that only holds a Ruby comment like Erubi (route it through the `<%#` path).

What held: each new Erubi-equality test fails without its commit; `rake test` shows only main's 5 pre-existing
failures; on random line-structured templates, mismatches with Erubi fell from about 2,460 per 5,000 to 0
across 5 seeds; the lobsters rewrite renders byte-identical to 8.1.

What the review broke (inputs outside the fuzz grammar):

1. `<%# c %><% # c %>\n<%= __LINE__ %>` prints 3 instead of 2. Both comments claim the newline, so every later
   line moves. Shapes Erubi can't compile (`<% # c %>` after other tags on a line) also change output. Fix
   idea: count a `<% # %>` as a comment line only when it is first on its line.
2. `Slots::SubtreeCompiler#visit_all` (subtree_compiler.rb L142) never sets the sibling pair, so the subtree
   compiler no longer renders like the engine.
3. The `at_line_start?` fallback reaches Herb's older "several tags on one line" trim path, which already
   differs from Erubi. Example: `<% [1, 2].each do |i| %>\n  <%# skip odd %>\n  <% next if i.odd? %><%# early exit %>\n  <li><%= i %></li>\n<% end %>`,
   whose whitespace matched Erubi before the patch and no longer does; lines below it move by one. The real
   fix is in that older path.
4. Minor: `x\n<% a = 1 %><% b = 2 %>\n<% #c %>\nz` used to match Erubi by accident and now doesn't.

So the Herb fix needs a rework of statement-line trimming (multi-tag lines included), with line-number probes
in the differential. That's larger than a small patch and belongs with whoever owns Herb's trim logic.

## Not done

No issue, PR or comment upstream. Rails-side code change not recommended: the handler is correct, and a
fallback to Erubi on parse errors would hide the markup bugs that are Herb's point (66 of 94 above).
