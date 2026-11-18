# ruby prep.rb APP... -> bundles each app's main and head Rack variants (the same SIDES as reqrun.rb), then prints, per app
# and side, the Rack each loads (gem dir, its git revision, Rack::VERSION, the escape guard line) and refuses when
# the two variants resolve different gems apart from rack.
load File.expand_path("../../../../script/census", __dir__)
SIDES = { "main" => "rack/rack@da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f",
  "head" => "thomasklemm/rack@c0a8e93011567e93c80800f81bdd111b9f0fa166" }.freeze
bin = Census.ruby_bin("4.0.9")
ARGV.each do |app|
  copy = Census.app_dir("census", app)
  rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
  locks = SIDES.to_h do |side, spec|
    gemfile = Census.variant("census", app, rails, bin, { "rack" => Census.resolve_rails(spec) })
    env = Census.env_for(app, bin, rails, gemfile)
    probe = 'require "rack"; require "rack/utils"; d = Gem.loaded_specs["rack"].full_gem_path; ' \
      'rev = Dir.chdir(d) { `git rev-parse HEAD 2>/dev/null`.strip }; ' \
      'guard = File.read(File.join(d, "lib/rack/utils.rb"))[/^.*def escape\(s\)\n.*\n.*$/]; ' \
      'puts [d, rev.empty? ? Gem.loaded_specs["rack"].source.revision : rev, Rack::RELEASE, guard.inspect].join(" | ")'
    out = Census.capture(env, File.join(bin, "ruby"), "-rbundler/setup", "-e", probe, chdir: copy)
    puts "#{app} #{side}: #{File.basename(gemfile)} | #{out}"
    lock = File.read("#{gemfile}.lock")
    [side, lock.split(/\n{2,}/).grep_v(/\A(GIT|PATH)\n/).map { _1.gsub(/^ *rack \(.*\n?|^  rack!\n?/, "") }]
  end
  abort "#{app}: main and head variants resolve different gems besides rack" unless locks.values.uniq.size == 1
  puts "#{app}: third-party gems identical in both variants"
end
