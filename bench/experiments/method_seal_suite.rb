# frozen_string_literal: true

# Run from a disposable script/corpus checkout, under its own bundle.
# METHOD_SEAL_MODE=baseline|freeze|warm_freeze|selective|tripwire
# METHOD_SEAL_REPORT=/new/private/report.json
# RUBYOPT='-I/path/to/gem/lib -rlowrail/setup' LOWRAIL_OUTCOMES=/new/outcomes
require "json"
require "digest"
require_relative "method_seal"
require_relative "../../gem/lib/lowrail/freeze_audit"

mode = ENV.fetch("METHOD_SEAL_MODE")
raise "unknown mode" unless %w[baseline freeze warm_freeze selective tripwire].include?(mode)
destination = ENV.fetch("METHOD_SEAL_REPORT")
raise "report exists" if File.exist?(destination)
report = {"mode" => mode, "ruby" => RUBY_DESCRIPTION, "lowrail" => ENV["LOWRAIL"],
  "lock_sha256" => Digest::SHA256.file("Gemfile.lock").hexdigest,
  "sources" => [__FILE__, File.join(__dir__, "method_seal.rb")].to_h { [_1, Digest::SHA256.file(_1).hexdigest] },
  "warm_steps" => [], "errors" => []}
session = nil
at_exit do
  report["session"] = session.finish! if session
  report["exception"] = $! && {"class" => $!.class.name, "backtrace" => $!.backtrace}
  report["exit_ok"] = $!.nil? || (SystemExit === $! && $!.success?)
  File.write(destination, JSON.pretty_generate(report))
end

require File.expand_path("config/environment", Dir.pwd)

seal = lambda do
  Rails.application.eager_load!
  helpers = %w[ActionView::Helpers::UrlHelper ActionView::Helpers::TagHelper].filter_map { Lowrail.loaded_constant(_1) }
  models = ActiveRecord::Base.descendants.reject { _1.abstract_class? }
  holders = [*helpers, *models]
  report["selected"] = holders.map(&:name).compact.sort
  if mode == "warm_freeze"
    models.each do |model|
      next unless model.table_exists?
      %i[load_schema define_attribute_methods model_name all_timestamp_attributes_in_model
        arel_table predicate_builder finder_needs_type_condition? query_constraints_list].each do |method|
        model.send(method)
        report["warm_steps"] << [model.name, method.to_s]
      rescue StandardError => error
        report["errors"] << {"holder" => model.name, "method" => method.to_s, "class" => error.class.name}
      end
    end
    Rails.application.reload_routes_unless_loaded
    report["warm_steps"] << ["Rails.application", "reload_routes_unless_loaded"]
  end
  case mode
  when "freeze", "warm_freeze"
    ENV["LOWRAIL_FREEZE"] = "1"
    session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: holders).start!
  when "selective"
    # Deliberately NOT a closure certificate. Quantify compatibility of only
    # stateless helper modules; never use this to authorize eliding inherited facts.
    selected = helpers.reject { Class === _1 || !_1.instance_variables.empty? }
    report["frozen_modules"] = selected.map(&:name)
    report["uncovered"] = (holders - selected).map(&:name)
    report["ancestor_closure_complete"] = false
    trace = TracePoint.new(:raise) do |event|
      error = event.raised_exception
      report["errors"] << {"class" => "FrozenError", "backtrace" => error.backtrace} if FrozenError === error
    end
    trace.enable
    selected.each { |mod| mod.singleton_class.freeze; mod.freeze }
  when "tripwire"
    session = MethodSeal::Session.new(holders: holders).start!
  end
  report["seal_reached"] = true
end

if File.directory?("spec")
  require "rspec/core"
  RSpec.configure { |config| config.before(:suite) { seal.call } }
  exit RSpec::Core::Runner.run(ARGV)
else
  $LOAD_PATH.unshift(File.expand_path("test"))
  require "rails/test_unit/runner"
  Rails::TestUnit::Runner.load_tests(ARGV)
  ARGV.replace(%w[--seed 41231])
  seal.call
end
