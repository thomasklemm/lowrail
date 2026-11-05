# Boots a minimal app and tries each mutation in four boot phases; prints a JSON table.
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"
require "json"
ENV["DATABASE_URL"] = "sqlite3::memory:"

RESULTS = Hash.new { |h, k| h[k] = {} }
$n = 0

def mutations
  {
    "ExceptionWrapper.rescue_responses[]=" => -> { ActionDispatch::ExceptionWrapper.rescue_responses["E#{$n += 1}"] = :not_found },
    "ExceptionWrapper.rescue_responses.merge!" => -> { ActionDispatch::ExceptionWrapper.rescue_responses.merge!("M#{$n += 1}" => :not_found) },
    "Response.default_headers[]=" => -> { ActionDispatch::Response.default_headers["X-P#{$n += 1}"] = "1" },
    "Request.parameter_parsers[]=" => -> { ActionDispatch::Request.parameter_parsers[:"p#{$n += 1}"] = ->(b) { {} } },
    "ActiveRecord.query_transformers << (shareable lambda)" => -> { ActiveRecord.query_transformers << Ractor.shareable_lambda { |sql, _| sql } },
    "AR::Base.time_zone_aware_types <<" => -> { ActiveRecord::Base.time_zone_aware_types << :"t#{$n += 1}" },
    "ERB.escape_ignore_list <<" => -> { ActionView::Template::Handlers::ERB.escape_ignore_list << "text/x#{$n += 1}" },
    "model.predicate_builder.register_handler" => -> { Class.new(ActiveRecord::Base) { self.table_name = "users" }.predicate_builder.register_handler(Regexp, proc { |c, v| c }) },
    "TableMetadata ivar memo" => -> { Class.new(ActiveRecord::Base) { self.table_name = "users" }.predicate_builder.send(:table).instance_variable_set(:@memo, true) },
    "model_name.instance_variable_set(:@route_key)" => -> { Class.new(ActiveRecord::Base) { def self.name = "Profile" }.model_name.instance_variable_set(:@route_key, "profile") },
    "Time.zone singleton stub" => -> { ActiveSupport::TimeZone["UTC"].define_singleton_method(:now) { Time.at(0) } },
  }
end

def probe(phase)
  mutations.each do |name, m|
    RESULTS[name][phase] = begin
      m.call
      "ok"
    rescue => e
      e.class.name
    end
  end
end

probe("1 require time")

class App < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "x" * 64
  config.active_support.deprecation = :silence
  config.after_initialize { probe("3a after_initialize, registered at require") }
  initializer "gem.initializer" do
    probe("2 initializer")
    config.after_initialize { probe("3b after_initialize, registered in initializer") }
  end
end


App.initialize!
probe("4 after boot")

puts JSON.generate(rails: Rails.version, results: RESULTS)
