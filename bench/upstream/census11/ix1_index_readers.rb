# IX1: index readers that 8.1 had on every adapter. ruby -I<rails>/{activesupport,activemodel,activerecord}/lib ix1_index_readers.rb [sqlite3|postgresql]
require "active_record"
adapter = ARGV[0] || "sqlite3"
if adapter == "postgresql"
  system("dropdb --if-exists ix1_probe >/dev/null 2>&1; createdb ix1_probe")
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "ix1_probe")
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
end
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :author_id; t.index [:author_id, :title]; t.index :author_id }
end
puts "Rails #{ActiveRecord.version} #{adapter}"
index = ActiveRecord::Base.lease_connection.indexes(:posts).first
%i[lengths orders opclasses type using include nulls_not_distinct where].each do |reader|
  puts "#{reader}: " + (index.public_send(reader).inspect rescue "#{$!.class}")
end
# The base constructor's keywords (third-party adapters build indexes with them).
begin
  ActiveRecord::ConnectionAdapters::IndexDefinition.new("posts", "i", false, ["a"], lengths: {}, opclasses: {}, type: nil, include: nil, nulls_not_distinct: nil)
  puts "IndexDefinition.new(lengths:, opclasses:, type:, include:, nulls_not_distinct:): ok"
rescue ArgumentError => e
  puts "IndexDefinition.new(lengths:, ...): ArgumentError #{e.message}"
end
