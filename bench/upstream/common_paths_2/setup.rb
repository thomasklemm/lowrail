RAILS = ENV.fetch("RAILS", File.expand_path("~/w/rails"))
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :authors do |t|
    t.string :name
    t.timestamps
  end
  create_table :posts do |t|
    t.string :title
    t.text :body
    t.boolean :published, default: false
    t.integer :author_id
    t.timestamps
  end
end
ActiveRecord.default_timezone = :utc
Time.zone_default = Time.find_zone!("UTC")
ActiveRecord::Base.time_zone_aware_attributes = true
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author, optional: true; end
AUTHOR = Author.create!(name: "a")
