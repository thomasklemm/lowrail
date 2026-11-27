require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:things) { |t| t.string :name } }
class Thing < ActiveRecord::Base; end
class Key < String
  attr_accessor :effect
  def hash
    if fn = effect
      self.effect = nil
      fn.call
    end
    super
  end
end
key = Key.new("trigger")
record = Thing.instantiate("id" => 1, "name" => "name", key => "trigger value", "last" => "old")
p record.attributes_before_type_cast.keys.map { |k| [k, k.class] }
key.effect = -> { record["last"] = "new" }
p record.attributes_before_type_cast
p record["last"]
