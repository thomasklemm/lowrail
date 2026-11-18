# Census of lobsters-yml

App: `/home/user/apps/lobsters` (measured on a copy). Rails 8.1.3.1 (the app's own), ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]. Measured 2026-11-18T11:23:26Z, 11 workloads, interpreter.

Each workload is one request, job or mail, run in a production boot of the app with its own Gemfile.lock. **Objects** are Ruby objects allocated per operation (median of three windows of 20). **Instructions** are CPU instructions per operation, counted exactly by Callgrind for the measuring thread. Everything ran twice in separate processes (an **A/A pair**): the A/A column is how much the same code moved between the two, the noise floor. These are counts of work, not timings; nothing here claims a request gets faster.

## Workloads

| Workload | Kind | Objects/op | A/A | Instructions/op | A/A | SQL queries/op |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| GET home | html | 36,601 | +73.6 | – | – | 14.0 |
| GET active | html | 36,830 | +76.0 | – | – | 14.0 |
| GET story | html | 28,780 | +77.0 | – | – | 30.0 |
| GET tag | html | 9,991 | +10.4 | – | – | 20.0 |
| GET hottest.json | json | 14,181 | −23.6 | – | – | 12.0 |
| GET story.json | json | 11,455 | −0.5 | – | – | 20.0 |
| POST story vote toggle | form | 4,502 | +1.7 | – | – | 19.5 |
| POST comment preview | form | 5,982 | +0.5 | – | – | 23.0 |
| POST comment (XHR) | form | 11,221 | −4.2 | – | – | 57.0 |
| deliver EmailReplyMailer#reply | mailer | 2,021 | ±0 | – | – | 0.0 |
| perform NotifyCommentJob | job | 1,325 | ±0 | – | – | 6.0 |

A/A: 7 of 11 workloads moved by one object or more between two runs of the same code. A difference smaller than a workload's A/A is noise. Instructions were not measured (`--no-cpu`, or no patched Valgrind: `script/cpu-census build`).

### Where the objects come from

Mean objects per operation over all workloads, by where they were allocated:

* Rails: 9,024.9 (69%)
* Gems: 2,414.7 (19%)
* Ruby standard library: 124.3 (1%)
* The app's own code: 1,174.0 (9%)
* The census's own request client (not your app): 103.7

### Top Rails, Ruby and gem lines by objects

| # | Line | Source | Objects/op | A/A | Workloads | Main class | Known work |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- |
| 1 | `GEM/sqlite3-2.9.6/lib/sqlite3/statement.rb:125` | `val = step` | 370.7 | −0.8 | 10 of 11 | String | none found |
| 2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `%(#{key}="#{value}")` | 330.4 | ±0 | 6 of 11 | String | open PR #45236 Fix regression in XSS filtering of HTML characters (line numbers from main); 10 more open PRs touch this file |
| 3 | `GEM/tzinfo-2.0.6/lib/tzinfo/timestamp.rb:208` | `sub_second = time.subsec` | 241.7 | ±0 | 9 of 11 | Rational | none found |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` | 168.5 | ±0 | 6 of 11 | Rational | 6 more open PRs touch this file; ledger: #59609 (I1), closed |
| 5 | `GEM/sqlite3-2.9.6/lib/sqlite3/statement.rb:186` | `val&.downcase` | 167.3 | ±0 | 10 of 11 | String | none found |
| 6 | `GEM/sqlite3-2.9.6/lib/sqlite3/statement.rb:185` | `val = column_decltype(column)` | 167.3 | ±0 | 10 of 11 | String | none found |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `ActiveSupport::SafeBuffer.new(self)` | 159.9 | ±0 | 7 of 11 | ActiveSupport::SafeBuffer | 3 more open PRs touch this file |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `super` | 141.8 | ±0 | 7 of 11 | String | 3 more open PRs touch this file |
| 9 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `parts = @parts.dup` | 137.5 | ±0 | 10 of 11 | Array | none found |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `name = name.to_s` | 131.5 | ±0 | 6 of 11 | String | none found |
| 11 | `GEM/tzinfo-2.0.6/lib/tzinfo/timestamp.rb:193` | `result = allocate` | 120.9 | ±0 | 9 of 11 | TZInfo::Timestamp | none found |
| 12 | `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:123` | `keys_to_keep = route.parts.reverse_each.drop_while { \|part\|` | 120.5 | ±0 | 10 of 11 | Array | 1 more open PR touches this file |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:141` | `new_sec += Rational(new_usec, 1000000)` | 115.6 | ±0 | 9 of 11 | Rational | open PR #45902 Validate option keys passed to #change() (line numbers from main); 5 more open PRs touch this file; ledger: #59609 (I1), closed |
| 14 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `output = +""` | 110.0 | ±0 | 6 of 11 | String | 11 more open PRs touch this file |
| 15 | `RAILS/activerecord/lib/active_record/associations.rb:60` | `association = reflection.association_class.new(self, reflection)` | 107.4 | ±0 | 10 of 11 | ActiveRecord::Associations::BelongsToAss | 13 more open PRs touch this file |

Objects/op is the mean over all 11 workloads (a line reached by one workload in ten with 10 objects shows 1.0); Workloads counts those where it allocates at least 0.5 per operation.

### On Rails c48c154e3f

What the same workloads do on this Rails, against the app's own. A change counts only when it is larger than both A/A pairs. Gems the new Rails needs were resolved by Bundler from the app's lock, so a difference can come from them too (here they differ from the app's lock).

| Workload | Objects/op | Δ | Beyond A/A | Instructions/op | Δ | Beyond A/A | SQL |
| --- | ---: | ---: | --- | ---: | ---: | --- | --- |
| GET home | 26,279 | −10,322.8 | yes | – | – | – | same |
| GET active | 26,449 | −10,380.8 | yes | – | – | – | same |
| GET story | 21,349 | −7,431.0 | yes | – | – | – | same |
| GET tag | 7,957 | −2,033.5 | yes | – | – | – | same |
| GET hottest.json | 11,164 | −3,017.6 | yes | – | – | – | same |
| GET story.json | 9,332 | −2,122.6 | yes | – | – | – | same |
| POST story vote toggle | 4,155 | −346.6 | yes | – | – | – | same |
| POST comment preview | 5,226 | −756.7 | yes | – | – | – | changed |
| POST comment (XHR) | 9,718 | −1,502.6 | yes | – | – | – | changed |
| deliver EmailReplyMailer#reply | 1,916 | −105.0 | yes | – | – | – | same |
| perform NotifyCommentJob | 1,222 | −104.0 | yes | – | – | – | changed |

11 workloads moved beyond their A/A in objects. SQL compares the masked statements each workload runs; "changed" means both pairs were stable and differ.

Objects per operation by origin, mean over workloads (app's Rails → this Rails): Rails 9,024.9 → 6,634.7; Gems 2,414.7 → 2,146.6; Ruby standard library 124.3 → 89.5; The app's own code 1,174.0 → 1,164.2.

## Limits

* Lines are attributed where the object was allocated or where Ruby was running when an instruction sample hit (C functions count for the Ruby line that called them). A line high in this list is where work happens, not proof that the work is avoidable; the PRs and ledger entries show where someone already looked.
* Matches to open PRs use each PR's diff on Rails main; for a released Rails, line numbers differ and a match is a hint. Ledger matches are by file or method name.
* Workloads run with jobs captured (performed as their own workloads), mail delivered to the test deliverer, and data from the census's own seeding of a copy, not your production data.
