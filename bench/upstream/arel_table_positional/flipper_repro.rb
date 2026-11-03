# RAILS=tree ruby flipper_repro.rb : flipper-active_record 1.4.2's get_all on SQLite.
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "activesupport", path: File.join(ENV.fetch("RAILS"), "activesupport")
  gem "activemodel", path: File.join(ENV.fetch("RAILS"), "activemodel")
  gem "activerecord", path: File.join(ENV.fetch("RAILS"), "activerecord")
  gem "sqlite3"
  gem "flipper", "1.4.2"
  gem "flipper-active_record", "1.4.2"
end
require "active_record"
require "flipper/adapters/active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:flipper_features) { |t| t.string :key, null: false; t.timestamps }
  create_table(:flipper_gates) { |t| t.string :feature_key, null: false; t.string :key, null: false; t.text :value; t.timestamps }
end
ActiveRecord.deprecator.behavior = ->(msg, *) { puts "DEPRECATION: #{msg}" }
flipper = Flipper.new(Flipper::Adapters::ActiveRecord.new)
flipper.enable(:search); flipper.enable_percentage_of_actors(:beta, 25)
begin
  p flipper.adapter.get_all.transform_values { |v| v.compact.reject { |_, x| x.respond_to?(:empty?) && x.empty? } }
rescue => e
  puts "#{e.class}: #{e.message}"
end
puts "Rails #{ActiveRecord.version} flipper #{Flipper::VERSION}"
