# Per-call micro under Callgrind (--toggle-collect=rb_ary_cycle): boots a ruby-bench app
# (APP=railsbench|lobsters|shipit|erubi-rails, BUNDLE_GEMFILE set by the driver) or nothing (APP=none,
# RAILS_PATH libs on the load path), loads CASES (a Ruby file defining MICRO = { name => -> { setup; -> { work } } }),
# warms up, then runs ITERS calls of the case with GC disabled inside [nil].cycle(1).
#   ruby irm.rb CASES CASE ITERS
cases_file, name, iters = ARGV[0], ARGV[1], Integer(ARGV[2])
app = ENV.fetch("APP", "none")
if app != "none"
  Dir.chdir(File.join(ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench")), "benchmarks", app))
  ENV["RAILS_ENV"] ||= "production"
  ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1"
  ENV["SHIPIT_DISABLE_AUTH"] = "1"
  ENV["SECRET_KEY_BASE"] ||= "0" * 128
  require File.expand_path("config/environment", Dir.pwd)
  if app == "shipit"
    mem_db = ActiveRecord::Base.connection.raw_connection
    file_db = SQLite3::Database.new("db/production.committed.sqlite3")
    b = SQLite3::Backup.new(mem_db, "main", file_db, "main")
    b.step(-1)
    b.finish
  end
end
load cases_file
work = MICRO.fetch(name).call
(ENV.fetch("WARMUP", "2000").to_i).times { work.call }
GC.start
GC.disable
alloc0 = GC.stat(:total_allocated_objects)
[nil].cycle(1) { iters.times { work.call } }
alloc = GC.stat(:total_allocated_objects) - alloc0
GC.enable
$stderr.puts "OBJECTS_PER_CALL #{alloc / iters.to_f}"
