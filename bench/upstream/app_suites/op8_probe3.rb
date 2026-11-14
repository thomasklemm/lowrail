# OP8 third probe: native PostgreSQL mutable defaults (nested jsonb, text[], hstore), an STI subclass, a proc
# default, and which models keep frozen defaults.
# RAILS_PATH=/path/to/rails ruby op8_probe3.rb   (PGHOST/PGPORT/PGUSER; uses database postgres)
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "pg"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  enable_extension "hstore"
  create_table :op8_natives, force: true do |t|
    t.string :type
    t.jsonb :doc, default: { "theme" => { "mode" => "light" } }
    t.string :tags, array: true, default: ["light"]
    t.hstore :props, default: '"mode"=>"light"'
  end
  create_table :op8_safes, force: true do |t|
    t.string :name, default: "x"
    t.jsonb :doc # NULL default
  end
end

class Native < ActiveRecord::Base; self.table_name = "op8_natives"; end
class NativeChild < Native; end
class NativeProc < ActiveRecord::Base
  self.table_name = "op8_natives"
  attribute :doc, default: -> { { "theme" => { "mode" => "light" } } }
end
class Safe < ActiveRecord::Base; self.table_name = "op8_safes"; end

[Native, NativeChild, NativeProc].each do |klass|
  a = klass.new
  a.doc["theme"]["mode"] = "dark"
  a.tags.first << "-dark"
  a.props["mode"] << "-dark"
  b = klass.new
  shared = { doc: b.doc["theme"]["mode"] != "light", tags: b.tags.first != "light", props: b.props["mode"] != "light" }
  puts "#{klass}: shared=#{shared.select { _2 }.keys.inspect} changed=#{klass.new.changed.inspect} " \
    "read_only_defaults=#{klass._default_attributes.try(:read_only?)}"
end
puts "Safe: read_only_defaults=#{Safe._default_attributes.try(:read_only?)} changed=#{Safe.new.changed.inspect}"
