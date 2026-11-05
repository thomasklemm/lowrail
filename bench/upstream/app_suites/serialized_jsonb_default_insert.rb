# A serialized jsonb column with a DB default and NOT NULL, partial_inserts off (OpenProject's HealthReport).
# RAILS_PATH=/path/to/rails ruby serialized_jsonb_default_insert.rb   (PGHOST/PGPORT/PGUSER; uses database postgres)
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "pg"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Base.partial_inserts = true # as OpenProject ends up with
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :reports, force: true do |t|
    t.jsonb :results, default: {}, null: false
  end
end
module Coder
  def self.load(json) = Array(json).map(&:to_h)
  def self.dump(value) = value.is_a?(Array) ? value.map(&:to_h) : value.to_h
end
class Report < ActiveRecord::Base
  serialize :results, coder: Coder
end
r = Report.new
puts "changed=#{r.changed.inspect}"
begin
  r.save!
  puts "Rails #{ActiveRecord.version}: saved, results=#{Report.connection.select_value("select results::text from reports").inspect}"
rescue => e
  puts "Rails #{ActiveRecord.version}: #{e.class}: #{e.message.lines.first.strip}"
ensure
  Report.connection.drop_table :reports, if_exists: true
end
