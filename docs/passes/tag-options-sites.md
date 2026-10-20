# Tag/form source-site census

2026-10-20. Appendix to [the component survey](tag-options.md).
Every site is refused as `upstream_solved`; no unit or hit was added.
L/D means a literal/live option expression, not a complete rendered-attribute certificate.
Nested entries are marked `nested`; ** splats remain unknown. Source-site savings are unmeasured.
Runtime-generated framework attributes and link/image helpers are covered separately in the survey.

## real-blog-r4

| Source site | Helper | Shape | Option keys (L/D) |
|---|---|---|---|
| `app/views/articles/_form.html.erb:1` | `form_with` | mixed_live | model:D, class:L |
| `app/views/articles/_form.html.erb:15` | `label` | no_option_hash |  |
| `app/views/articles/_form.html.erb:16` | `text_field` | mixed_live | class:D |
| `app/views/articles/_form.html.erb:20` | `label` | no_option_hash |  |
| `app/views/articles/_form.html.erb:21` | `textarea` | mixed_live | rows:L, class:D |
| `app/views/articles/_form.html.erb:25` | `submit` | all_literal | class:L |
| `app/views/articles/show.html.erb:42` | `form_with` | mixed_live | model:D, class:L |
| `app/views/articles/show.html.erb:44` | `label` | all_literal | class:L |
| `app/views/articles/show.html.erb:45` | `text_field` | all_literal | class:L |
| `app/views/articles/show.html.erb:48` | `label` | all_literal | class:L |
| `app/views/articles/show.html.erb:49` | `text_area` | all_literal | rows:L, class:L |
| `app/views/articles/show.html.erb:51` | `submit` | all_literal | class:L |

## campfire

| Source site | Helper | Shape | Option keys (L/D) |
|---|---|---|---|
| `app/views/accounts/bots/_form.html.erb:18` | `text_field` | all_literal | class:L, autocomplete:L, placeholder:L, autofocus:L, required:L, data:L/nested |
| `app/views/accounts/bots/edit.html.erb:10` | `form_with` | mixed_live | model:D, url:D, class:L |
| `app/views/accounts/bots/new.html.erb:10` | `form_with` | mixed_live | model:D, url:D, class:L |
| `app/views/accounts/custom_styles/edit.html.erb:10` | `form_with` | mixed_live | model:D, url:D, class:L, data:L/nested |
| `app/views/accounts/custom_styles/edit.html.erb:26` | `text_area` | all_literal | class:L, placeholder:L, autocomplete:L, spellcheck:L, autocorrect:L, autocapitalize:L, rows:L, required:L |
| `app/views/accounts/edit.html.erb:26` | `form_with` | mixed_live | model:D, method:L, class:L, data:L/nested |
| `app/views/accounts/edit.html.erb:35` | `form_with` | mixed_live | model:D, method:L, data:L/nested |
| `app/views/accounts/edit.html.erb:52` | `form_with` | mixed_live | model:D, data:L/nested, class:L |
| `app/views/accounts/edit.html.erb:57` | `text_field` | all_literal | class:L, autocomplete:L, placeholder:L, autofocus:L, data:L/nested |
| `app/views/accounts/edit.html.erb:69` | `form_with` | mixed_live | model:D, method:L, data:L/nested, class:L |
| `app/views/accounts/edit.html.erb:79` | `input` | mixed_live | type:L, class:L, checked:D, data:L/nested |
| `app/views/accounts/users/_user.html.erb:14` | `form_with` | mixed_live | model:D, url:D, data:L/nested, method:L |
| `app/views/action_text/attachables/_opengraph_embed.html.erb:12` | `img` | mixed_live | src:D, class:L, alt:L |
| `app/views/first_runs/show.html.erb:4` | `form_with` | mixed_live | model:D, url:D, class:L |
| `app/views/first_runs/show.html.erb:32` | `text_field` | all_literal | class:L, autocomplete:L, placeholder:L, autofocus:L, required:L, data:L/nested |
| `app/views/layouts/application.html.erb:16` | `meta` | mixed_live | name:L, content:D |
| `app/views/layouts/application.html.erb:17` | `meta` | all_literal | name:L, content:L |
| `app/views/layouts/application.html.erb:19` | `link` | mixed_live | rel:L, href:D |
| `app/views/layouts/application.html.erb:20` | `link` | mixed_live | rel:L, href:D, type:L |
| `app/views/layouts/application.html.erb:21` | `link` | mixed_live | rel:L, href:D |
| `app/views/layouts/application.html.erb:66` | `div` | mixed_live | hidden:L, data:D/nested |
| `app/views/messages/_actions.html.erb:5` | `details` | all_literal | class:L, data:L/nested |
| `app/views/messages/_actions.html.erb:40` | `button` | mixed_live | class:L, data:D/nested, title:L, aria:L/nested |
| `app/views/messages/_actions.html.erb:45` | `button` | all_literal | class:L, data:L/nested, title:L, aria:L/nested |
| `app/views/messages/_actions.html.erb:50` | `button` | mixed_live | class:L, title:L, aria:L/nested, data:D/nested |
| `app/views/messages/boosts/_boost.html.erb:8` | `span` | mixed_live | role:L, class:D, data:L/nested |
| `app/views/messages/boosts/new.html.erb:3` | `form_with` | mixed_live | model:D, class:L, data:D/nested |
| `app/views/messages/boosts/new.html.erb:11` | `text_field` | mixed_live | id:L, autofocus:L, autocomplete:L, autocorrect:L, maxlength:L, required:L, pattern:D, data:L/nested, class:L |
| `app/views/messages/edit.html.erb:8` | `button_tag` | mixed_live | class:L, type:L, form:D, data:L/nested |
| `app/views/messages/edit.html.erb:16` | `form_with` | mixed_live | model:D, url:D, id:D, data:L/nested |
| `app/views/messages/edit.html.erb:34` | `button_tag` | all_literal | type:L, class:L |
| `app/views/messages/edit.html.erb:39` | `button_tag` | mixed_live | class:L, type:L, form:D, data:L/nested |
| `app/views/messages/edit.html.erb:57` | `form_with` | mixed_live | url:D, method:L, id:D, data:D/nested |
| `app/views/rooms/directs/new.html.erb:3` | `form_with` | mixed_live | model:D, class:L, data:L/nested |
| `app/views/rooms/directs/new.html.erb:17` | `text_field` | all_literal | autocomplete:L, autocorrect:L, "data-1p-ignore":L, class:L, data:L/nested |
| `app/views/rooms/directs/new.html.erb:23` | `button_tag` | all_literal | class:L, type:L |
| `app/views/rooms/layouts/_form.html.erb:1` | `form_with` | mixed_live | model:D |
| `app/views/rooms/layouts/_form.html.erb:7` | `text_field` | all_literal | name:L, id:L, class:L, required:L, autofocus:L, placeholder:L, data:L/nested |
| `app/views/rooms/show/_nav.html.erb:4` | `span` | all_literal | class:L |
| `app/views/searches/index.html.erb:7` | `div` | all_literal | class:L |
| `app/views/searches/index.html.erb:69` | `form_with` | mixed_live | url:D, class:L, data:L/nested |
| `app/views/searches/index.html.erb:74` | `text_field` | mixed_live | value:D, class:L, role:L, aria:L/nested, autofocus:L, required:L |
| `app/views/sessions/new.html.erb:8` | `form_with` | mixed_live | url:D, class:L |
| `app/views/users/new.html.erb:13` | `form_with` | mixed_live | model:D, url:D, class:L |
| `app/views/users/new.html.erb:44` | `text_field` | all_literal | class:L, autocomplete:L, placeholder:L, autofocus:L, required:L, data:L/nested |
| `app/views/users/profiles/show.html.erb:9` | `form_with` | mixed_live | url:D, method:L, data:L/nested |
| `app/views/users/profiles/show.html.erb:56` | `text_field` | all_literal | class:L, autocomplete:L, placeholder:L, autofocus:L, required:L, data:L/nested |
| `app/views/users/profiles/show.html.erb:96` | `text_area` | all_literal | class:L, placeholder:L, maxlength:L, rows:L, required:L |
| `app/helpers/accounts_helper.rb:3` | `figure` | mixed_live | class:D |
| `app/helpers/application_helper.rb:3` | `title` | no_option_hash |  |
| `app/helpers/application_helper.rb:9` | `tag` | mixed_live | name:L, content:D |
| `app/helpers/application_helper.rb:10` | `tag` | mixed_live | name:L, content:D |
| `app/helpers/application_helper.rb:17` | `style` | all_literal | data:L/nested |
| `app/helpers/application_helper.rb:34` | `span` | all_literal | class:L |
| `app/helpers/cable_helper.rb:3` | `meta` | mixed_live | name:L, content:D |
| `app/helpers/clipboard_helper.rb:3` | `button` | mixed_live | class:L, data:D/nested |
| `app/helpers/forms_helper.rb:6` | `form_with` | dynamic_splat | **splat:D, data:D |
| `app/helpers/messages/attachment_presentation.rb:37` | `video` | mixed_live | src:D, poster:D, controls:L, preload:L, width:L, height:L, class:L |
| `app/helpers/messages/attachment_presentation.rb:63` | `div` | mixed_live | class:L, style:D |
| `app/helpers/messages/attachment_presentation.rb:65` | `div` | all_literal | class:L |
| `app/helpers/messages/attachment_presentation.rb:88` | `div` | all_literal | class:L |
| `app/helpers/messages/attachment_presentation.rb:90` | `span` | no_option_hash |  |
| `app/helpers/messages/attachment_presentation.rb:101` | `span` | all_literal | class:L |
| `app/helpers/messages/attachment_presentation.rb:106` | `button` | mixed_live | class:L, style:L, data:D/nested |
| `app/helpers/messages/attachment_presentation.rb:107` | `span` | all_literal | class:L |
| `app/helpers/messages_helper.rb:11` | `div` | mixed_live | id:L, class:L, contents:L, data:D/nested |
| `app/helpers/messages_helper.rb:24` | `div` | mixed_live | id:D, class:L, data:D/nested |
| `app/helpers/messages_helper.rb:36` | `div` | mixed_live | id:D, class:D, data:D/nested |
| `app/helpers/messages_helper.rb:160` | `div` | mixed_live | class:L, data:D/nested |
| `app/helpers/messages_helper.rb:166` | `button` | all_literal | class:L, data:L/nested |
| `app/helpers/rich_text_helper.rb:9` | `lexxy_prompt` | mixed_live | trigger:L, name:L, src:D, "remote-filtering":L, "empty-results":L |
| `app/helpers/rooms/involvements_helper.rb:14` | `span` | mixed_live | class:L, id:D |
| `app/helpers/rooms_helper.rb:29` | `span` | all_literal | class:L |
| `app/helpers/rooms_helper.rb:34` | `button` | all_literal | class:L, data:L/nested, hidden:L |
| `app/helpers/rooms_helper.rb:39` | `span` | all_literal | class:L |
| `app/helpers/rooms_helper.rb:44` | `button_tag` | all_literal | class:L, type:L |
| `app/helpers/rooms_helper.rb:46` | `span` | all_literal | class:L |
| `app/helpers/rooms_helper.rb:51` | `form_with` | mixed_live | model:D, url:D, id:L, class:L, data:D |
| `app/helpers/searches_helper.rb:3` | `div` | all_literal | id:L, class:L, data:L/nested |
| `app/helpers/time_helper.rb:3` | `time` | dynamic_splat | **splat:D, datetime:D, data:D/nested |
| `app/helpers/translations_helper.rb:20` | `dl` | all_literal | class:L |
| `app/helpers/translations_helper.rb:22` | `dt` | no_option_hash |  |
| `app/helpers/translations_helper.rb:23` | `dd` | all_literal | class:L |
| `app/helpers/translations_helper.rb:29` | `details` | all_literal | class:L, data:L/nested |
| `app/helpers/translations_helper.rb:30` | `summary` | all_literal | class:L, tabindex:L |
| `app/helpers/translations_helper.rb:32` | `span` | all_literal | class:L |
| `app/helpers/translations_helper.rb:34` | `div` | all_literal | class:L, data:L/nested |
| `app/helpers/users/filter_helper.rb:3` | `menu` | all_literal | class:L, data:L/nested |
| `app/helpers/users/filter_helper.rb:8` | `input` | all_literal | type:L, id:L, autocorrect:L, autocomplete:L, "data-1p-ignore":L, class:L, placeholder:L, data:L/nested |
| `app/helpers/users/profiles_helper.rb:3` | `form_with` | dynamic_splat | model:D, url:D, method:L, data:L/nested, **splat:D |
| `app/helpers/users/profiles_helper.rb:11` | `button` | all_literal | class:L, type:L |
| `app/helpers/users/profiles_helper.rb:13` | `span` | all_literal | class:L |
| `app/helpers/users/profiles_helper.rb:18` | `button` | mixed_live | class:L, hidden:L, data:D/nested |
| `app/helpers/version_helper.rb:3` | `span` | all_literal | class:L |

## pingcrm

| Source site | Helper | Shape | Option keys (L/D) |
|---|---|---|---|
| `app/views/layouts/application.html.erb:10` | `tag` | mixed_live | name:L, content:D |
| `app/views/layouts/application.html.erb:11` | `tag` | mixed_live | name:L, content:D |

## redprints-cfp

| Source site | Helper | Shape | Option keys (L/D) |
|---|---|---|---|
No direct tag/form sites; framework helpers still serialize attributes.

## react-starter-kit

| Source site | Helper | Shape | Option keys (L/D) |
|---|---|---|---|
No direct tag/form sites; framework helpers still serialize attributes.
