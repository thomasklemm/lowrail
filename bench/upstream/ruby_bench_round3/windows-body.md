This builds on #567 and includes its commit until #567 merges; I'll rebase then.

This runs erubi-rails, graphql-native, lobsters and railsbench in the `benchmark-default-windows` job, so it no longer excludes any benchmark.

They were excluded because nokogiri 1.18.9 builds from source on Windows and its bundled libiconv fails to compile. #567 moved lobsters and railsbench to nokogiri 1.19.7, which installs on Windows with Ruby 4.0 (the precompiled x64-mingw-ucrt gem) and with head (built from source). erubi-rails gets the same bump here.

lobsters was also excluded because stackprof fails to build. stackprof 0.2.28, the latest release, uses POSIX signals and timers that MinGW doesn't have. lobsters lists it only in its development group, which the benchmark doesn't load, so it now gets `platforms: :mri`, as in railsbench's Gemfile. Gemfile.lock doesn't change.

graphql-native moves from graphql-c_parser 1.1.3 to 1.2.0 (released 2026-11-05), which includes rmosolgo/graphql-ruby#5877: it renames the C token names that clashed with Windows headers. graphql stays at 2.5.11.

This also changes graphql-native on Linux. It returns the same tokens and AST for `negotiate.gql`, but runs about 2% more instructions per iteration (Cachegrind, Ruby 4.0.9 interpreter, fixed heap, two runs each; two runs of 1.1.3 differ by 0.3%). The extra instructions are in the C lexer and parser that 1.1.4 and 1.2.0 regenerated for their number, BOM and parser-stack changes, not in #5877's renames.

In this run on my fork, both `benchmark-default-windows` jobs pass and run all four benchmarks: https://github.com/thomasklemm/ruby-bench/actions/runs/42063514767
