# frozen_string_literal: true

# Component worker, also usable directly from rails/rails/activerecord as in
# d9fd466. script/rails-suite supplies RUBYOPT, bundle, layers and controls.
require_relative "rails_suite_report"
if ARGV.first == "--compare"
  abort "usage: #{$PROGRAM_NAME} --compare OFF.json ON.json [OFF-REPEAT.json ON-REPEAT.json]" unless [3, 5].include?(ARGV.size)
  report = RailsSuiteReport.compare(*ARGV.drop(1))
  puts JSON.pretty_generate(report)
  exit(report["differences"].empty? && report["observations"].all?(&:positive?) ? 0 : 1)
end

root = File.expand_path("..", Dir.pwd)
raise "run from a rails/rails component directory" unless File.file?(File.join(root, "RAILS_VERSION"))
raise "set LOWRAIL_OUTCOMES to an output JSON path" unless ENV["LOWRAIL_OUTCOMES"]
component = File.basename(Dir.pwd)
layer = ENV.fetch("RAILS_SUITE_LAYER", "L3")
Dir[File.join(root, "*/*.gemspec")].each do |gemspec|
  name = File.basename(gemspec, ".gemspec")
  path = File.dirname(gemspec)
  spec = Gem::Specification.load(gemspec)
  spec.full_gem_path = path
  Gem.loaded_specs[name] = spec
  $LOAD_PATH.unshift(File.join(path, "lib"))
end
$LOAD_PATH.unshift(File.join(root, "railties/lib"), File.join(Dir.pwd, "test"))
ENV["ARCONN"] ||= "sqlite3_mem"
ENV["LOWRAIL_SHADOW"] = "strict"
require "rails/version"
require "lowrail/setup"
Lowrail::Minitest::Reporter.prepend(RailsSuiteReport::Observations)
if layer == "L2" || (component == "activerecord" && layer == "L3")
  require "active_record" if component == "activerecord"
  require "lowrail/ar_guard"
  Lowrail::AR.install if Lowrail.enabled?
end
if layer == "L2"
  abort "fallback manifest failed to install" unless Lowrail.manifest && Lowrail::Loader.installed?
  Lowrail.manifest.units.each { abort "synthetic fact matched" if Lowrail.check(_1.fetch("id")) }
end
files = ARGV.take_while { !_1.start_with?("-") }
ARGV.shift(files.size)
if files.empty?
  files = case component
  when "activerecord"
    Dir["test/cases/**/*_test.rb"].sort.reject { _1.include?("/adapters/") || _1.include?("/encryption/performance/") } +
      Dir["test/cases/adapters/#{ENV.fetch('ARCONN').split('_').first}/**/*_test.rb"].sort
  when "activemodel", "activejob"
    Dir["test/cases/**/*_test.rb"].sort.reject { component == "activejob" && (_1.include?("delayed_job") || _1.include?("async")) }
  when "actionview"
    Dir["test/template/**/*_test.rb"].sort
  else
    Dir["test/**/*_test.rb"].sort.reject { _1.start_with?("test/fixtures/", "test/isolation/assets/") }
  end
end
files.each { require File.expand_path(_1) }
if (build_root = ENV["RAILS_SUITE_BUILD"])
  abort "build in a separate Lowrail-off process" unless ENV["LOWRAIL"] == "0"
  built = if defined?(ActiveRecord::Base)
    require_relative "ar_equivalence_runtime"
    Lowrail::AREquivalenceRuntime.build
  end
  units = built ? built[:manifest].units : []
  Lowrail.write_json(File.join(build_root, ".lowrail/manifest.json"), {
    "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "", "files" => {}, "units" => units })
  Lowrail.write_json(ENV.fetch("LOWRAIL_OUTCOMES") + ".build.json", {
    "units" => units.map { [_1["id"], _1["pass"], _1["file"]] }, "ledger" => built ? built[:ledger] : [] })
  # Never run the suite in this process: schema materialization changes tests.
  exit! 0
end
if layer == "L3" && Lowrail.enabled?
  abort "build a manifest first (script/rails-suite)" unless Lowrail.manifest
  { "active_record/ar_plans" => :ARPlans, "active_record/preload_plans" => :PreloadPlans,
    "active_record/instantiate" => :ARInstantiate }.each do |pass, runtime|
    Lowrail.const_get(runtime).activate if Lowrail.manifest.units.any? { _1["pass"] == pass }
  end
end
Lowrail.write_json(ENV.fetch("LOWRAIL_OUTCOMES") + ".loaded.json", { "files" => files })
if (profile = ENV["RAILS_SUITE_PROFILE"])
  abort "profiles must run with LOWRAIL=0" unless ENV["LOWRAIL"] == "0"
  require "stackprof"
  # Start before autorun without wrapping Minitest.run: wrapper frames change
  # caller_locations and break Rails' backtrace-cleaner assertions.
  at_exit { StackProf.start(mode: :wall, raw: true, interval: 1000) }
  Minitest.after_run do
    StackProf.stop
    File.binwrite(profile, Marshal.dump(StackProf.results))
  end
end
