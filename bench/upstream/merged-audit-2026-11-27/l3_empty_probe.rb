# Cases where the attribute set may hold no built attributes: does attributes_to_hash return the same on both trees?
require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a")
class Plain; include ActiveModel::Model; include ActiveModel::Attributes; end
class One; include ActiveModel::Model; include ActiveModel::Attributes; attribute :x, :integer; end
cases = {
  "Plain.new" => -> { Plain.new },
  "One.new" => -> { One.new },
  "Post.new" => -> { Post.new },
  "Post.first" => -> { Post.first },
  "select 1 AS one" => -> { Post.select("1 AS one").first },
  "select id" => -> { Post.select(:id).first },
}
cases.each do |name, build|
  r = build.call
  set = r.instance_variable_get(:@attributes)
  out = %i[values_before_type_cast values_for_database].map do |m|
    set.respond_to?(m) ? (set.public_send(m) rescue "#{$!.class}: #{$!.message}") : :na
  end
  puts "#{name} #{set.class}: #{out.inspect}"
end
puts "loaded from #{ActiveModel::AttributeSet.instance_method(:values_for_database).source_location.first.sub(Dir.home, "~")}"
