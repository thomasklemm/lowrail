# Dump the indexes of one PostgreSQL schema with diverse index shapes; diff the output between Rails trees.
require "active_record"
require "stringio"
db = "c11_pg_index_dump"
system("dropdb --if-exists #{db} >/dev/null 2>&1; createdb #{db}")
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: db)
c = ActiveRecord::Base.lease_connection
c.execute(<<~SQL)
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS btree_gist;
  CREATE TABLE posts (id bigserial primary key, title varchar, body text, author_id bigint, score int, tags text[], data jsonb,
    created_at timestamp, deleted_at timestamp, "Mixed Case" text, slug varchar COLLATE "C", period tsrange);
  CREATE INDEX idx_plain ON posts (author_id);
  CREATE UNIQUE INDEX idx_unique_multi ON posts (author_id, title);
  CREATE INDEX idx_desc ON posts (created_at DESC NULLS LAST, score ASC NULLS FIRST);
  CREATE INDEX idx_partial ON posts (author_id) WHERE deleted_at IS NULL AND score > 3;
  CREATE INDEX idx_expr ON posts (lower(title));
  CREATE INDEX idx_expr_multi ON posts (lower(title), author_id);
  CREATE INDEX idx_expr_mixed ON posts (author_id, (data->>'kind'), lower(title) DESC);
  CREATE INDEX idx_trgm ON posts USING gin (title gin_trgm_ops);
  CREATE INDEX idx_opclass_multi ON posts (title varchar_pattern_ops, body text_pattern_ops);
  CREATE INDEX idx_gin_tags ON posts USING gin (tags);
  CREATE INDEX idx_jsonb_path ON posts USING gin (data jsonb_path_ops);
  CREATE INDEX idx_include ON posts (author_id) INCLUDE (title, score);
  CREATE UNIQUE INDEX idx_nnd ON posts (slug) NULLS NOT DISTINCT;
  CREATE INDEX idx_quoted ON posts ("Mixed Case");
  CREATE INDEX idx_collate ON posts (title COLLATE "C");
  CREATE INDEX idx_hash ON posts USING hash (slug);
  CREATE INDEX idx_brin ON posts USING brin (created_at);
  CREATE INDEX idx_gist ON posts USING gist (period);
  CREATE INDEX idx_gist_multi ON posts USING gist (author_id, period);
  CREATE INDEX idx_with ON posts (score) WITH (fillfactor = 70);
  CREATE INDEX idx_desc_opclass ON posts (title varchar_pattern_ops DESC);
  CREATE INDEX idx_expr_where ON posts (date_trunc('day', created_at)) WHERE (data ? 'x');
  COMMENT ON INDEX idx_plain IS 'plain comment';
  CREATE SCHEMA other;
  CREATE TABLE other.items (id serial primary key, name text);
  CREATE INDEX idx_other ON other.items (lower(name));
  CREATE TABLE parts (id bigint, at date) PARTITION BY RANGE (at);
  CREATE INDEX idx_parts ON parts (at);
  CREATE TABLE parts_2026 PARTITION OF parts FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
SQL
c.execute("CREATE INDEX idx_invalid ON posts (score, author_id)")
c.execute("UPDATE pg_index SET indisvalid = false WHERE indexrelid = 'idx_invalid'::regclass")
puts "Rails #{ActiveRecord.version}"
%w[posts other.items parts parts_2026].each do |t|
  c.indexes(t).sort_by(&:name).each do |i|
    attrs = %i[unique columns orders where using comment valid].to_h { [_1, i.public_send(_1)] }
    %i[lengths opclasses include nulls_not_distinct type].each { |r| attrs[r] = i.public_send(r) if i.respond_to?(r) }
    puts "#{t} #{i.name}: #{attrs.inspect}"
  end
end
io = StringIO.new
ActiveRecord::SchemaDumper.dump(c.pool, io)
puts io.string.lines.grep(/t\.index|add_index|create_table/).join
