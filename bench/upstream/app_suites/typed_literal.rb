require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "127.0.0.1", port: 5418, username: "postgres", database: "activerecord_unittest", prepared_statements: ENV["PS"] != "0")
ActiveRecord::Base.lease_connection.create_table(:fbs_items, force: true) { |t| t.date :day }
class FbsItem < ActiveRecord::Base; end
FbsItem.create!(day: Date.new(2026, 1, 2))
d = Date.new(2026, 1, 1)
{
  "find_by_sql DATE :d"        => -> { FbsItem.find_by_sql(["SELECT DATE :d AS x", { d: d }]).first.x },
  "find_by_sql :d::date"       => -> { FbsItem.find_by_sql(["SELECT :d::date AS x", { d: d }]).first.x },
  "find_by_sql day - :n"        => -> { FbsItem.find_by_sql(["SELECT day - :n AS x FROM fbs_items", { n: 1 }]).first.x },
  "where DATE ?"               => -> { FbsItem.where("day > DATE ?", d).count },
  "count_by_sql DATE ?"        => -> { FbsItem.count_by_sql(["SELECT COUNT(*) FROM fbs_items WHERE day > DATE ?", d]) },
}.each do |label, l|
  r = begin; l.call.inspect; rescue => e; "#{e.class}: #{e.message.lines.first.strip[0, 70]}"; end
  puts "#{label.ljust(24)} #{r}"
end
