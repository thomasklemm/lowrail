require "tmpdir"
require "rails"
require "active_job/railtie"
require "active_job/arguments" if ENV["EAGER"] == "1"
Money = Struct.new(:cents)
class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
  def klass = Money
  def serialize(money) = super("cents" => money.cents)
  def deserialize(hash) = Money.new(hash["cents"])
end
root = Dir.mktmpdir
Dir.mkdir("#{root}/config"); Dir.mkdir("#{root}/config/initializers")
init = ENV["FORM"] == "hook" ?
  "ActiveSupport.on_load(:active_job_arguments) { ActiveJob::Serializers.add_serializers MoneySerializer }\n" :
  "Rails.application.config.active_job.custom_serializers << MoneySerializer\n"
File.write("#{root}/config/initializers/custom_serializers.rb", init)
class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "secret_key_base"
  config.active_job.queue_adapter = :test
  config.logger = Logger.new(nil)
end
TestApp.config.root = root
Rails.application.initialize!
loaded = $LOADED_FEATURES.any? { _1.end_with?("active_job/arguments.rb") }
begin
  r = ActiveJob::Arguments.serialize([Money.new(100)])
  puts "EAGER=#{ENV["EAGER"]} FORM=#{ENV["FORM"]} arguments_loaded_at_boot=#{loaded} -> #{r.inspect}"
rescue => e
  puts "EAGER=#{ENV["EAGER"]} FORM=#{ENV["FORM"]} arguments_loaded_at_boot=#{loaded} -> #{e.class}: #{e.message}"
end
