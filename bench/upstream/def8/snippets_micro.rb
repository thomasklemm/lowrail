# Callgrind on one snippet in a generated app (micro.sh runs it):
#   ruby -rbundler/setup snippets_micro.rb CASE N
ENV["RAILS_ENV"] = "production"
$stdout.reopen(File::NULL)
require "./config/application"
Rails.application.config.yjit = false
require "./config/environment"
abort "yjit on" if RubyVM::YJIT.enabled?
name, n = ARGV[0], Integer(ARGV[1])
cases = {
  "root_join" => -> { "#{Rails.root.join("app/assets")}/**/*.css" },
  "file_join" => -> { File.join(Rails.root, "app/assets/**/*.css") },
  "pluralize" => -> { "query".pluralize(0) },
  "ternary" => -> { 0 == 1 ? "query" : "queries" },
  "noop" => -> { nil },
}
c = cases.fetch(name)
100.times { c.call }
GC.start; GC.disable
o = GC.stat(:total_allocated_objects)
[c].cycle(n, &:call)
warn "objects=#{(GC.stat(:total_allocated_objects) - o) / n}"
