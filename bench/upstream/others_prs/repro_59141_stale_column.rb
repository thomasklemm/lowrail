require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
c = ActiveRecord::Base.connection
c.create_table(:widgets) { |t| t.string :name; t.string :gone, default: "g" }
K = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
K.create!(name: "w")
K.first
c.remove_column :widgets, :gone
K.singleton_class.prepend(Module.new { def _load_from_sql(rs, &b) = (p(cols: rs.columns, rows: rs.rows); super) }); r = K.first
p attrs: r.attributes, has: r.has_attribute?(:gone)
p((r.gone rescue $!.class))
