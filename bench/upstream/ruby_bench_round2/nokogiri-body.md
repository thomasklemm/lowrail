This bumps nokogiri in shipit's Gemfile.lock from 1.19.1 to 1.19.7 to fix the `benchmark-default-windows (head)` job, which has failed on every run on main since 2026-10-30 (the last passing run was on 2026-10-29).

In that job, shipit's `bundle install` fails compiling nokogiri 1.19.1 (run 41944045400): `xml_node_set.c:382:33: error: passing argument 2 of 'rb_range_beg_len' from incompatible pointer type [-Wincompatible-pointer-types]`. ruby/ruby@cc3ba11012 changed `rb_range_beg_len` to take `rb_len_t *`, and on 2026-10-29 RubyInstaller's ruby-head build made `rb_len_t` 64 bits (oneclick/rubyinstaller2-packages@0f441be052), so it no longer matches nokogiri's `long`. Elsewhere `rb_len_t` is still `long`, which is why the Linux head job passes. nokogiri switched to `rb_len_t` in 1.19.5 (sparklemotion/nokogiri#3711), and 1.19.7 also compiles against Ruby 4.1.0-preview1 (sparklemotion/nokogiri#3755).

Of the benchmarks the Windows job runs, only shipit is affected: lobsters, railsbench and erubi-rails lock nokogiri 1.18.9, but that job already excludes them. #567, the Rails 8.1.4.1 bump, makes the same nokogiri change in shipit's Gemfile.lock; the two PRs merge cleanly in either order.

On Linux, with Ruby 4.0.9 and with Ruby master 7f9638f41e, shipit installs and runs. All 57 requests of one benchmark pass return 200 and the same bodies as with 1.19.1, apart from CSRF tokens.
