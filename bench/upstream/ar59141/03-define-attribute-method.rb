require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :settings }
  create_table(:comments) { |t| t.string :body }
end
def probe(name)
  puts "#{name}: #{yield.inspect}"
rescue Exception => e
  puts "#{name}: #{e.class}: #{e.message.lines.first&.strip}"
end

# typedstore 1.6.0 pattern: store accessor, then define_attribute_method for it (dirty tracking).
class Post < ActiveRecord::Base
  store :settings, accessors: [:color], coder: JSON
end
probe("define_attribute_method(store accessor)") { Post.define_attribute_method("color"); p = Post.new(color: "red"); [p.color, p.attribute_names] }
probe("define_attribute_methods(:not_an_attribute)") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; def virt = "x" }
  k.define_attribute_methods(:virt); k.new.virt
end

# Aliases declared on abstract classes (#59141 now generates them per concrete model).
class ApplicationRecord < ActiveRecord::Base; self.abstract_class = true; alias_attribute :name, :title; end
class Post2 < ApplicationRecord; self.table_name = "posts"; end
class Comment < ApplicationRecord; end
probe("abstract alias on model with column") { Post2.new(title: "t").name }
probe("abstract alias on model without column") { Comment.new(body: "b").respond_to?(:name) }
probe("abstract alias where(name:)") { Post2.where(name: "t").to_sql }
probe("alias declared on abstract after load") do
  Post2.create!(title: "late"); ApplicationRecord.alias_attribute :heading, :title; Post2.first.heading
end
# alias in a concern included into abstract class
module Named; extend ActiveSupport::Concern; included { alias_attribute :label, :title }; end
class Base3 < ActiveRecord::Base; self.abstract_class = true; include Named; end
class Post3 < Base3; self.table_name = "posts"; end
probe("concern alias via abstract") { Post3.new(title: "c").label }
# alias to an attribute added by `attribute` in the subclass only
class Base4 < ActiveRecord::Base; self.abstract_class = true; alias_attribute :v2, :virt; end
class Post4 < Base4; self.table_name = "posts"; attribute :virt, :string, default: "d"; end
probe("abstract alias to subclass-declared attribute") { Post4.new.v2 }
