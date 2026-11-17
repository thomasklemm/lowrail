load File.expand_path("../../../../script/census", __dir__)
app = ARGV[0]
bin = Census.ruby_bin("4.0.9")
copy = Census.app_dir("census", app)
rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
env = Census.env_for(app, bin, rails, Census.variant("census", app, rails, bin)).merge("CENSUS_MODE" => "interpreter")
system(env, File.join(bin, "ruby"), "-rbundler/setup", File.expand_path("count.rb", __dir__), app, chdir: copy)
