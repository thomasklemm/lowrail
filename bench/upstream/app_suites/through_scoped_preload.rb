# RAILS=path ruby through_scoped_preload.rb -> preloads a has_many :through a belongs_to with a scope on the source
# (Gumroad's Link#global_checkout_custom_fields: through: :user, source: :custom_fields, -> { global }) on links whose
# user is already loaded, and prints the queries and the loaded records. 8-1 reuses the loaded users and queries
# custom_fields; main reloads users LEFT OUTER JOIN custom_fields. Same records. Exit 1 without a custom_fields query.
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
  create_table(:users)
  create_table(:links) { |t| t.integer :user_id }
  create_table(:custom_fields) { |t| t.integer :seller_id; t.boolean :global }
end
class User < ActiveRecord::Base
  has_many :custom_fields, foreign_key: :seller_id
end
class CustomField < ActiveRecord::Base
  scope :global, -> { where(global: true) }
end
class Link < ActiveRecord::Base
  belongs_to :user
  has_many :global_custom_fields, -> { global }, through: :user, source: :custom_fields
end
user = User.create!
CustomField.create!(seller_id: user.id, global: true)
CustomField.create!(seller_id: user.id, global: false)
2.times { Link.create!(user: user) }
queries = []
ActiveSupport::Notifications.subscribed(->(*, p) { queries << p[:sql] unless p[:name] == "SCHEMA" }, "sql.active_record") do
  links = Link.where(user: user).to_a.each { _1.user = user }
  ActiveRecord::Associations::Preloader.new(records: links, associations: :global_custom_fields).call
  links.each { |l| puts "link #{l.id}: #{l.global_custom_fields.map(&:id)}" }
end
puts "#{ActiveRecord.version}:", queries.map { "  #{_1}" }
exit(queries.any? { _1.include?(%(FROM "custom_fields")) } ? 0 : 1)
