This bumps lobsters, railsbench, shipit and activerecord from Rails 8.1.1 (shipit 8.1.2) to 8.1.4.1, the latest 8.1 release. Only Gemfile.lock files change. Action View 8.1.4.1 requires rails-html-sanitizer 1.7.2, which needs loofah 2.25.3, which needs nokogiri 1.19.5 or later, so those move too. erubi-rails stays on Rails 8.0, as in #456. #566 makes the same nokogiri change in shipit; the two PRs merge cleanly in either order.

`bundle lock --update` fails for railsbench and activerecord on CRuby because of the JRuby-only git source from #530, so I copied versions and checksums from the new lobsters lock (nokogiri -java from rubygems.org). `bundle install` on Ruby 4.0.9 leaves both unchanged, and JRuby 10.1.2.0 rewrites them the same way it rewrites main's.

All 2,000 railsbench, 114 lobsters and 57 shipit requests return 200 with the same bodies as on main, apart from CSRF tokens and timestamps.

Rails 8.1.4.1 runs about 1–1.5% more instructions per iteration (Callgrind, Ruby 4.0.9 interpreter, fixed heap, two processes per tree; main vs main within 0.1%): railsbench +1.4–1.5%, shipit +1.1%, lobsters +0.8–1.0%. Wall time from two runs is too noisy to confirm this.
