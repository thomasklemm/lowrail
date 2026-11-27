$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { "/home/user/w/rails-main/#{_1}/lib" })
require "active_record"
sql = 'SELECT "posts".* FROM "posts" WHERE "posts"."author_id" = $1 LIMIT $2'
binds = [ActiveRecord::Relation::QueryAttribute.new("author_id", 1, ActiveModel::Type::Integer.new),
  ActiveRecord::Relation::QueryAttribute.new("LIMIT", 1, ActiveModel::Type::Value.new)]
binds.hash
nested = [sql, binds]; flat = [sql, *binds]
$op = case ENV["CASE"]
when "nested" then -> { nested.hash }
when "flat" then -> { flat.hash }
when "binds" then -> { binds.hash }
when "sql" then -> { sql.hash }
when "one" then b = binds[0]; -> { b.hash }
end
