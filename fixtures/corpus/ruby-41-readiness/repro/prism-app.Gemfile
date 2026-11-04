# Rails main without anything that pulls in prism (minitest 5, irb < 1.17,
# rdoc 6). On Ruby master, `ActionView.eager_load!` and
# `require "rails/test_unit/runner"` raise LoadError: cannot load such file -- prism.
source "https://rubygems.org"
gem "rails", github: "rails/rails", branch: "main"
gem "minitest", "~> 5.27"
gem "irb", "1.14.3"
gem "rdoc", "6.13.1"
