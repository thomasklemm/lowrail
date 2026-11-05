# RAILS=path ruby reading_prevent_writes.rb -> connected_to(role: :reading, prevent_writes: false), which Gumroad's
# Mysql2ProxyRouting::ScopedRoles passes outside a reading block. 8-1: writes are still prevented; main: ArgumentError.
require "bundler/inline"
require "tmpdir"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
db = File.join(Dir.mktmpdir, "app.sqlite3")
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
ApplicationRecord.connects_to(database: { writing: { adapter: "sqlite3", database: db }, reading: { adapter: "sqlite3", database: db } })
class Post < ApplicationRecord; end
ApplicationRecord.connection.execute("CREATE TABLE posts (id integer primary key)")
begin
  ApplicationRecord.connected_to(role: :reading, prevent_writes: false) do
    puts "#{ActiveRecord.version}: preventing writes inside the block: #{ApplicationRecord.current_preventing_writes}"
  end
  exit 0
rescue ArgumentError => error
  puts "#{ActiveRecord.version}: #{error.class}: #{error.message}"
  exit 1
end
