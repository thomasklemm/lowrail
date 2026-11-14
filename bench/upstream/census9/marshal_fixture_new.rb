# Main's own Rails 6.1 new-record fixture, loaded and saved on a tree:
#   BUNDLE_GEMFILE=<bundle> ruby marshal_fixture_new.rb <tree>/activerecord/test/support/marshal_compatibility_fixtures/SQLite/rails_6_1_new_topic.dump defined|undefined [read_first]
# "defined" runs Topic.define_attribute_methods before Marshal.load; "read_first" calls the title reader before writing and saving.
require "bundler/setup"; require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
class Topic < ActiveRecord::Base; self.inheritance_column = nil; end
class Reply < Topic; end
raw = File.binread(ARGV[0])
ActiveRecord::Schema.define { create_table(:topics) { |t| t.string :title } } rescue nil
cols = Marshal.load(raw).instance_variable_get(:@attributes).instance_variable_get(:@attributes).keys rescue (p $!; exit)
ActiveRecord::Base.connection.drop_table(:topics)
ActiveRecord::Schema.define { create_table(:topics, id: :integer) { |t| (cols - ["id"]).each { |c| t.column c, :string } } }
Topic.reset_column_information
Topic.define_attribute_methods if ARGV[1] == "defined"
t = Marshal.load(raw)
t.title if ARGV[2] == "read_first"; t.title = "Renamed"
begin; t.save!; puts "saved: #{Topic.find(t.id).title}"; rescue => e; puts "#{e.class}: #{e.message[0,90]}"; end
