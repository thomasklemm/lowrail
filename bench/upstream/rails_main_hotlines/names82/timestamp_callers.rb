# RAILS_PATH=TREE ruby timestamp_callers.rb: the three callers' code in callers/ (fetched verbatim at the SHAs in
# callers/SHAS), loaded into models as the projects use them, then create and update.
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
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:courses) { |t| t.string :name; t.timestamps; t.datetime :changed_at }
  create_table(:plants) { |t| t.string :name; t.timestamps; t.datetime :inserted_at }
  create_table(:domains) { |t| t.string :name; t.datetime :created; t.datetime :modified }
end
puts "Active Record #{ActiveRecord.version}"
dir = File.join(__dir__, "callers")
def run(label)
  puts "#{label} => #{yield.inspect}"
rescue Exception => e
  puts "#{label} => #{e.class}: #{e.message.lines.first.strip}"
end

load File.join(dir, "DFE-Digital_publish-teacher-training__changed_at.rb")
class Course < ActiveRecord::Base
  include ChangedAt
end
run("publish-teacher-training ChangedAt: changed_at set on create, moves on update") do
  c = Course.create!(name: "a")
  before = c.changed_at
  sleep 0.01
  c.update!(name: "b")
  [!before.nil?, c.changed_at > before]
end

load File.join(dir, "treflehq_trefle-api__application_record.rb")
class Plant < ApplicationRecord; end
run("trefle-api ApplicationRecord: inserted_at set on create") { !Plant.create!(name: "a").inserted_at.nil? }

load File.join(dir, "krhitoshi_postfix_admin__existing_timestamp.rb")
class Domain < ActiveRecord::Base
  include ExistingTimestamp
end
run("postfix_admin 0.8.0 ExistingTimestamp: created and modified set") { d = Domain.create!(name: "a"); [!d.created.nil?, !d.modified.nil?] }
