# RAILS_PATH=TREE ruby removed_probe.rb: removed or moved names that real callers use (Mastodon's migration helpers
# call ActiveRecord::Base.get_primary_key; GitLab and diaspora call String#mb_chars).
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"])
    %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" }
  else
    gem "activerecord", ENV.fetch("AR_VERSION", "8.1.4.1")
  end
  gem "sqlite3"
end
require "active_record"
ActiveRecord.deprecator.behavior = :silence
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
puts "Active Record #{ActiveRecord.version}"
def run(label) = (puts "#{label} => #{yield.inspect}" rescue puts("#{label} => #{$!.class}: #{$!.message.lines.first.strip}"))
run("ActiveRecord::Base.get_primary_key('posts')") { ActiveRecord::Base.get_primary_key("posts") }
run("'é'.mb_chars.upcase.to_s") { "é".mb_chars.upcase.to_s }
