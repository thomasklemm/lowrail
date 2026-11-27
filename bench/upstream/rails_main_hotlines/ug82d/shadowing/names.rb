# Lists the public method names that a model's relation answers itself, so a
# model class method of the same name is not delegated to on relations.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) }
class Post < ActiveRecord::Base; end

rel = Post.all.class
by_owner = Hash.new { |h, k| h[k] = [] }
rel.public_instance_methods.each do |m|
  owner = rel.instance_method(m).owner
  by_owner[owner.name || owner.inspect] << m
end
by_owner.sort_by { |k, v| -v.size }.each { |k, v| puts "#{k} #{v.size}" }

ar = by_owner.select { |k, _| k.start_with?("ActiveRecord::") }.values.flatten.uniq.sort
q = ActiveRecord::Querying::QUERYING_METHODS
puts "AR-owned public relation methods: #{ar.size}; QUERYING_METHODS: #{q.size}; QUERYING not AR-owned on relation: #{(q - ar).inspect}"
File.write(ARGV[0] || "names-#{ActiveRecord.version}.txt", ar.join("\n") + "\n")
