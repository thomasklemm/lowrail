require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }

ActiveRecord::Base.singleton_class.prepend(Module.new do
  def build_schema_context
    primary_key # Fizzy's config/initializers/uuid_primary_keys.rb checks the primary key's column type here
    super
  end
end)

class Post < ActiveRecord::Base; end
p Post.create!(title: "a").id
