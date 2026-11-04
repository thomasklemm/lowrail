# RAILS=/path/to/rails ruby pg_extension_array.rb  (database from DB, default lowrail_ltree; needs createdb)
# 8-1 creates ltree/citext/hstore array columns with defaults; main raises "can't quote Array".
# (The enum array default fails on both trees.)
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { |g| gem g, path: File.join(ENV.fetch("RAILS"), g) }
  gem "pg"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: ENV.fetch("DB", "lowrail_ltree"))
c = ActiveRecord::Base.connection
%w[ltree citext hstore].each { |e| c.enable_extension e }
c.execute "DROP TYPE IF EXISTS mood CASCADE; CREATE TYPE mood AS ENUM ('ok', 'sad')"
{ ltree: ["a.b"], citext: ["A"], hstore: [{ "a" => "1" }], mood: ["ok"], integer: [1] }.each do |type, default|
  c.create_table("t_#{type}", force: true) { |t| t.column :v, type, default: default, array: true }
  c.add_column "t_#{type}", :w, type, default: default, array: true
  puts "#{type}: ok #{c.columns("t_#{type}").map(&:default).inspect}"
rescue => e
  puts "#{type}: #{e.class}: #{e.message[0, 80]}"
end
