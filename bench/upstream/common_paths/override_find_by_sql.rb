require "bundler/setup"
require "active_record"
[true, false].each do |prep|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", prepared_statements: prep)
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define { create_table(:posts, force: true) { |t| t.string :title } }
  Object.send(:remove_const, :Post) if defined?(Post)
  Object.const_set(:Post, Class.new(ActiveRecord::Base) { self.table_name = "posts"; def self.find_by_sql(sql, *a, **k, &b) = (sql << " /* t */" if sql.is_a?(String); super) })
  Post.connection.insert("INSERT INTO posts (title) VALUES ('a')")
  sqls = []
  ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] if p[:name] =~ /Load/ }
  r = 3.times.map { begin; Post.find(1).title; rescue => e; e.class.name; end }
  p [prep, r, sqls.uniq]
  ActiveSupport::Notifications.unsubscribe("sql.active_record")
end
