require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "127.0.0.1", port: 5433, username: "postgres", database: "postgres")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:permalinks, force: true) { |t| t.string :url; t.string :external_url; t.datetime :created_at }
end
class Permalink < ActiveRecord::Base; end
Permalink.create!(url: "a/x", external_url: "e")
Permalink.create!(url: "b", external_url: "f")

def probe(label)
  r = yield
  puts "#{label}: #{r.to_sql} => #{r.pluck(:id).inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message.lines.first.strip[0, 140]}"
end

url = "x"
probe("discourse filter_by") do
  permalinks = Permalink.order("permalinks.created_at desc")
  permalinks.where!("url ILIKE :url OR external_url ILIKE :url", url: "%#{url}%")
  permalinks.limit!(100)
  permalinks
end
probe("? bind") { Permalink.all.where!("url = ?", "b") }
