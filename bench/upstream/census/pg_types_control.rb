# frozen_string_literal: true
# PG census behavior control (docs/upstream/pg-census.md): the type every result
# column and schema column resolves to. Run with BUNDLE_GEMFILE=RAILS/Gemfile
# against the AR test database; compare the output across Rails checkouts.
require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "activerecord_unittest2")
c = ActiveRecord::Base.lease_connection
types = %w[int2 int4 int8 float4 float8 numeric numeric(10,2) numeric(5,0) money text varchar varchar(5) char(3) bpchar
  name bool date time time(2) timetz timestamp timestamp(0) timestamp(3) timestamptz timestamptz(6) interval
  interval(2) bit(3) varbit(4) bytea json jsonb uuid inet cidr macaddr point line lseg box path polygon circle xml
  tsvector oid int4[] numeric(5,1)[] varchar(7)[] timestamp(3)[] text[] int4range numrange tsrange tstzrange daterange
  int8range regclass]
desc = ->(t) { [t.class.name, t.type, t.try(:precision), t.try(:scale), t.try(:limit), t.try(:subtype)&.then { [_1.class.name, _1.try(:precision), _1.try(:limit)] }] }
2.times do |pass| # the second pass hits the type map cache
  r = c.select_all("SELECT " + types.each_with_index.map { |t, i| "NULL::#{t} AS c#{i}" }.join(", "))
  types.each_with_index { |t, i| puts "#{pass} result #{t}: #{desc.(r.column_types["c#{i}"]).inspect}" }
end
c.execute("DROP TABLE IF EXISTS census_types")
c.execute("CREATE TABLE census_types (" + types.each_with_index.map { |t, i| "c#{i} #{t}" }.join(", ") + ")")
c.schema_cache.clear!
model = Class.new(ActiveRecord::Base) { self.table_name = "census_types" }
c.columns("census_types").each { |col| puts "column #{col.sql_type}: #{desc.(model.attribute_types[col.name]).inspect}" }
c.execute("DROP TABLE census_types")
