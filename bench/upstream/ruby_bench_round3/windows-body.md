This builds on #567 and includes its commit until #567 merges; I'll rebase then.

This runs erubi-rails, lobsters and railsbench in the `benchmark-default-windows` job, so only graphql-native stays excluded there.

They were excluded because nokogiri 1.18.9 builds from source on Windows and its bundled libiconv fails to compile. #567 moved lobsters and railsbench to nokogiri 1.19.7, which installs on Windows with Ruby 4.0 (the precompiled x64-mingw-ucrt gem) and with head (built from source). erubi-rails gets the same bump here.

lobsters was also excluded because stackprof fails to build. stackprof 0.2.28, the latest release, uses POSIX signals and timers that MinGW doesn't have. lobsters lists it only in its development group, which the benchmark doesn't load, so it now gets `platforms: :mri`, as in railsbench's Gemfile. Gemfile.lock doesn't change.

graphql-native stays excluded: graphql-c_parser names tokens FLOAT, INT and INPUT, which the Windows headers already define, and 1.1.4, the latest release, still does.

In this run on my fork, both `benchmark-default-windows` jobs pass and run all three benchmarks: https://github.com/thomasklemm/ruby-bench/actions/runs/42018186964
