# Records Marshal-dumped by 8.1 in the 6.1 format, loaded on Rails main. Run in an empty directory:
#   BUNDLE_GEMFILE=<8.1 bundle> ruby marshal_6_1_repro.rb dump    writes new.dump and loaded.dump
#   BUNDLE_GEMFILE=<main bundle> ruby marshal_6_1_repro.rb load   loads both, saves the new record
require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:topics) { |t| t.string :title; t.timestamps } }
class Topic < ActiveRecord::Base; end
case ARGV[0]
when "dump"
  ActiveRecord::Marshalling.format_version = 6.1
  Topic.create!(title: "loaded")
  File.binwrite("new.dump", Marshal.dump(Topic.new(title: "new")))
  File.binwrite("loaded.dump", Marshal.dump(Topic.first))
  puts "dumped with #{ActiveRecord.version}"
when "load"
  puts ActiveRecord.version
  t = Marshal.load(File.binread("new.dump"))
  t.title = "renamed"
  begin; t.save!; puts "new: saved #{Topic.count} rows"; rescue => e; puts "new: #{e.class}: #{e.message} (rows: #{Topic.count})"; end
  begin; puts "loaded: #{Marshal.load(File.binread("loaded.dump")).title}"; rescue => e; puts "loaded: #{e.class}: #{e.message}"; end
end
