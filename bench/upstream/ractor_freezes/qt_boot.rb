# Boots a minimal app after pushing a query transformer shaped like bemi-rails (module proc) or iron_trail (instance proc).
require "rails"
require "active_record/railtie"
ENV["DATABASE_URL"] = "sqlite3::memory:"
module ModuleShape
  def self.append_context = Proc.new { |sql, adapter = nil| sql }
end
class InstanceShape
  def initialize = @transformer_proc = proc { |query, adapter| query }
  def setup = ActiveRecord.query_transformers << @transformer_proc
end
case ARGV[0]
when "module" then ActiveRecord.query_transformers << ModuleShape.append_context
when "instance" then ActiveSupport.on_load(:active_record) { InstanceShape.new.setup }
end
class App < Rails::Application
  config.root = __dir__; config.eager_load = false; config.logger = Logger.new(nil); config.secret_key_base = "x" * 64
  initializer("load_ar") { ActiveRecord::Base } if ARGV[1] == "early"
end
begin
  App.initialize!
  ActiveRecord::Base
  puts "#{ARGV[0]}: booted, #{ActiveRecord.query_transformers.size} transformers"
rescue => e
  puts "#{ARGV[0]}: #{e.class}: #{e.message[0, 70]}"
end
