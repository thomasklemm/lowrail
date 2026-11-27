# frozen_string_literal: true

# Runs a script inside a census app copy with the census environment, as
# `script/census run` would: production, the app's Gemfile variant for the
# Rails tree and Ruby given.
#   [WRAP="valgrind ..."] ruby run_in_app.rb APP RAILS_SPEC RUBY SCRIPT [ARGS...]
load File.expand_path("../../../script/census", __dir__)

app, spec, ruby, script, *args = ARGV
rails = Census.resolve_rails(spec)
bin = Census.ruby_bin(ruby)
gemfile = Census.variant("census", app, rails, bin)
env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => "interpreter")
Census.sh(env, "bundle", "exec", *ENV.fetch("WRAP", "").split, File.join(bin, "ruby"), File.expand_path(script), app, *args, chdir: Census.app_dir("census", app))
