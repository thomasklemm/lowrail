---
id: DC1
repo: rails/rails
kind: fix
area: Action View, form helpers
reviewer: seanpdoyle (author of #55410), skipkayhil (merged it)
branch: thomasklemm/form-tag-helper-token-tag
head: "ab0a99e41a"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: classes that include FormTagHelper or FormHelper without NavigationHelper (cells-rails' cells, Decidim's profile pages) render non-GET forms again; fixes unreleased #55410
rank: 4
risky: false
state: ready
pr: 59667
note: "opened as draft 2026-11-05; the body paragraph on why includers can't fix it themselves came after the recorded passes (f2149ee); body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: test sentence, cells-rails and Decidim versions, the defined? workaround clause; in docs/upstream/app-suites.md"
passes:
  - {reviewer: skeptic, head: "ab0a99e41a", date: 2026-11-05, verdict: approve, open: wording nit applied}
  - {reviewer: sol, head: "ab0a99e41a", date: 2026-11-05, verdict: approve, open: body link pinned (13:13)}
  - {reviewer: sol, head: "ab0a99e41a", date: 2026-11-05, verdict: nits, open: "20:09, optional: assert method ownership, narrow the profile-page claim"}
  - {reviewer: claude-code, head: "ab0a99e41a", date: 2026-11-06, verdict: approve, open: "none; rebases cleanly on main 8e8a9bb3 (actionview unchanged since bdb3d960), so no push; both methods private and owned only by UrlHelper for NavigationHelper, UrlHelper, FormTagHelper, FormHelper and ActionView::Base; button_to fine; new test fails on main with NoMethodError; actionview test:template 2956 runs and actionpack request_forgery_protection green, RuboCop clean; links verified; no CHANGELOG (unreleased, entry names no private methods); left Sol's optional nits as is"}
---

# Keep token_tag and method_tag where FormTagHelper can reach them

#55410 moved `token_tag` and `method_tag` from `UrlHelper` into the new `NavigationHelper`, but [`FormTagHelper#extra_tags_for_form`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/form_tag_helper.rb#L1129-L1145) calls them too, and `FormTagHelper` [includes `UrlHelper`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/form_tag_helper.rb#L21) but not `NavigationHelper`. So a class that includes only `FormTagHelper` or `FormHelper` can no longer render a form that isn't a GET:

```ruby
class Renderer
  include ActionView::Helpers::FormTagHelper
  attr_accessor :output_buffer
end
Renderer.new.form_tag("/posts", method: :patch) { "" }
# 8.1:  <form action="/posts" ...><input type="hidden" name="_method" value="patch" ...></form>
# main: NoMethodError: undefined method 'method_tag'
```

cells-rails' `Cell::ViewModel` [includes `FormHelper`](https://github.com/trailblazer/cells-rails/blob/77ff22ae8f94472cf477672ca2f0c86757d627d8/lib/cell/railtie.rb#L49), so Decidim's report-user modal, a cell with a [`decidim_form_for … method: :post`](https://github.com/decidim/decidim/blob/80149bbba83a3c477172d113d21e22115c901e54/decidim-core/app/cells/decidim/report_user_button/flag_modal.erb#L2), raises `undefined method 'token_tag'` on a user's profile page.

These are private helpers of `FormTagHelper` itself, so includers have no reason to know about them. Both modules include `UrlHelper`, where the two methods lived on 8.1, so this moves them back there unchanged.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c96c47539d8b49f7455fe03f66a498aa123d6e30/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
