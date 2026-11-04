# frozen_string_literal: true

# Runs a script inside a census copy with script/census's environment:
#   ruby run_in_copy.rb CORPUS APP RUBY_BIN_DIR [RAILS_DIR@SHA] -- [ruby flags] SCRIPT ARGS...
# RAILS_DIR@SHA picks another Rails checkout (a candidate branch); default: the copy's base.
load File.expand_path("../../../script/census", __dir__)

corpus, app, bin, *rest = ARGV
rails_spec = rest.first == "--" ? nil : rest.shift
rest.shift
rails = rails_spec ? Census.resolve_rails(rails_spec) : Census.state(corpus, app).fetch("base")
gemfile = Census.variant(corpus, app, rails, bin)
env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => ENV.fetch("CENSUS_MODE", "interpreter"))
%w[CENSUS_ONLY CENSUS_WARMUP CENSUS_REQUESTS CENSUS_DEBUG].each { env[_1] = ENV[_1] if ENV[_1] }
exec(env, "bundle", "exec", "ruby", *rest, chdir: Census.app_dir(corpus, app))
