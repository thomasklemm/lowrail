require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
Post.create!(title: "abc")
class DownType < ActiveModel::Type::String
  def serialize(v) v.downcase! ; v end
end
c = ActiveRecord::Base.lease_connection
events = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| events << (p[:cached] ? "cache" : "db") if p[:name] == "q" }
v = +"ABC"
bind = ActiveModel::Attribute.with_cast_value("title", v, DownType.new)
c.cache do
  2.times { c.select_all("SELECT * FROM posts WHERE title = ?", "q", [bind]) }
  puts "events=#{events.join('/')} size=#{c.query_cache.size}"
end
