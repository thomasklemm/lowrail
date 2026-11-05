# RAILS=path ruby poly_type.rb -> exit 1 if saving overwrites an explicitly assigned polymorphic type
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:widgets)
  create_table(:inboxes) { |t| t.references :channel, polymorphic: true }
end
class Widget < ActiveRecord::Base; end
class Inbox < ActiveRecord::Base; belongs_to :channel, polymorphic: true; end
inbox = Inbox.new(channel: Widget.new)
inbox.channel_type = "Page"
inbox.save!
puts "before save: Page, after save: #{inbox.channel_type}, reloaded: #{inbox.reload.channel_type}"
exit(inbox.channel_type == "Page" ? 0 : 1)
