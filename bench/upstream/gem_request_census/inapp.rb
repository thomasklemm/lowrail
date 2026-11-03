# frozen_string_literal: true

# Run SCRIPT inside a census copy with script/census's environment and the
# copy's variant bundle (GEMS=NAME=OWNER/REPO@SHA,... pins gems as --gem does):
#   ruby inapp.rb APP SCRIPT [ARGS]      (RUBYFLAGS adds ruby flags, CENSUS_MODE the mode)
load File.expand_path("../../../script/census", __dir__)
app, script, *args = ARGV
script = File.expand_path(script)
bin = Census.ruby_bin("4.0.7")
dir = Census.app_dir("census", app)
rails = JSON.parse(File.read(File.join(dir, ".census.json"))).fetch("base")
gems = (ENV["GEMS"] || "").split(",").to_h { |pin| n, sp = pin.split("=", 2); [n, Census.resolve_rails(sp)] }
env = Census.env_for(app, bin, rails, Census.variant("census", app, rails, bin, gems)).merge("CENSUS_MODE" => ENV.fetch("CENSUS_MODE", "interpreter"))
exec(env, "bundle", "exec", "ruby", *ENV.fetch("RUBYFLAGS", "").split, script, app, *args, chdir: dir)
