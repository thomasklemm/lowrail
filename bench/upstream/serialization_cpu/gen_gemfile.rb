# ruby gen_gemfile.rb NAME RAILS_DIR [JSON_VERSION] -> Gemfile.v-NAME (+ lock via bundle lock --local)
name, rails, json = ARGV
json ||= "3.1.0"
File.write("Gemfile.v-#{name}", <<~G)
  source "https://rubygems.org"
  gem "rails", path: #{rails.inspect}
  gem "sqlite3"
  gem "jbuilder", "2.15.1"
  gem "json", #{json.inspect}
  gem "stackprof"
G
