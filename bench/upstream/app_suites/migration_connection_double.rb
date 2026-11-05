# RAILS=path ruby migration_connection_double.rb -> a migration whose connection is a bare stand-in object (as
# Gumroad's migration specs stub it with an RSpec double), then respond_to?(:anything). 8-1: false; main: NoMethodError,
# because Migration#respond_to_missing? builds the execution strategy, which now asks connection.migration_strategy.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
end
require "active_record"
migration = Class.new(ActiveRecord::Migration[8.1]).new
bare = Object.new
migration.define_singleton_method(:connection) { bare }
begin
  puts "#{ActiveRecord.version}: respond_to?(:change_table_comment) => #{migration.respond_to?(:change_table_comment)}"
  exit 0
rescue NoMethodError => error
  puts "#{ActiveRecord.version}: #{error.class}: #{error.message.lines.first.strip}"
  exit 1
end
