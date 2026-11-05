### Test each tag attribute name for blankness once

Since 99a3247ebc, `tag_options` checks [the raw key with `blank?` and then the name it converts the key to](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/tag_helper.rb#L1548-L1551). For a plain String key the name is normally the key itself, so `String#blank?` runs twice per String-keyed attribute; for a Symbol, the name check already skips an empty one.

This checks only the converted name for Symbols and plain Strings, and keeps both checks for every other key, including String subclasses, whose `to_s` or `blank?` can differ. Nested `data` and `aria` keys are unchanged. The new tests cover whitespace String keys and String keys that are blank only once converted. Output for 48 kinds of keys, each with 9 values, is identical to main.

Callgrind instructions per call, Ruby 4.0.9 interpreter, in the railsbench app (main against itself within 0.1%):

| | main | this PR |
| --- | ---: | ---: |
| `tag.a` with Symbol keys | 57,534 | 56,671 (−1.5%) |
| `content_tag` with String keys | 59,387 | 58,354 (−1.7%) |

Per railsbench iteration, `String#blank?` runs 9.3M fewer instructions. 8-1-stable has the same double check (9190210606).

---
<sub>Found by comparing Rails 8.1.1 and 8.1.4.1 on ruby-bench with Callgrind ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
