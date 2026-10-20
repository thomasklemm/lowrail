# frozen_string_literal: true

# Run from a disposable rails/rails checkout's activerecord directory:
# LOWRAIL=0|1 LOWRAIL_OUTCOMES=/tmp/ar-off.json ruby -I/abs/lowrail/gem/lib \
#   /abs/lowrail/bench/ar_rails_suite.rb [test/cases/..._test.rb ...] --seed 41231
# Uses repository source/gemspecs, not the installed AR gem's implementation.
require "json"
if ARGV.first == "--compare"
  abort "usage: #{$PROGRAM_NAME} --compare OFF.json ON.json" unless ARGV.size == 3
  off, on = ARGV.drop(1).map { JSON.parse(File.read(_1 + ".shadow.json")).fetch("outcomes") }
  changed = (off.keys | on.keys).select { off[_1] != on[_1] }
  puts JSON.pretty_generate({ "observations" => [off, on].map { _1.values.sum(&:size) },
    "outcomes" => [off, on].map { _1.values.flatten.group_by { |entry| entry.fetch("result") }.transform_values(&:size) },
    "differences" => changed.to_h { [_1, { "off" => off[_1], "on" => on[_1] }] } })
  exit(changed.empty? && !off.empty? ? 0 : 1)
end

root = File.expand_path("..", Dir.pwd)
raise "run from rails/rails/activerecord" unless File.file?(File.join(root, "RAILS_VERSION"))
raise "set LOWRAIL_OUTCOMES to an output JSON path" unless ENV["LOWRAIL_OUTCOMES"]
%w[activesupport activemodel activerecord].each do |name|
  path = File.join(root, name)
  spec = Gem::Specification.load(File.join(path, "#{name}.gemspec"))
  spec.full_gem_path = path
  Gem.loaded_specs[name] = spec
  $LOAD_PATH.unshift(File.join(path, "lib"))
end
$LOAD_PATH.unshift(File.join(root, "railties/lib"), File.join(Dir.pwd, "test"))
ENV["ARCONN"] ||= "sqlite3_mem"
ENV["LOWRAIL_SHADOW"] = "strict"
require "rails/version"
require "lowrail"
Lowrail.boot
# Rails has a few distinct runnable classes sharing one printed class/name
# identity. Preserve multiplicities instead of letting the standard app
# reporter's identity hash overwrite those observations.
module ComponentOutcomes
  def record(result)
    super
    key = "#{result.respond_to?(:klass) ? result.klass : result.class.name}##{result.name}"
    entry = { "result" => Lowrail::Minitest::Reporter.result_of(result) }
    entry["failure"] = Lowrail::Minitest::Reporter.describe(result.failures.first) unless result.failures.empty?
    (@observations ||= Hash.new { |hash, name| hash[name] = [] })[key] << entry
  end

  def observations = @observations
end
Lowrail::Minitest::Reporter.prepend(ComponentOutcomes)
require "active_record"
require "lowrail/ar_guard"
Lowrail::AR.install if Lowrail.enabled?
files = ARGV.take_while { !_1.start_with?("-") }
ARGV.shift(files.size)
if files.empty?
  files = Dir["test/cases/**/*_test.rb"].sort.reject { _1.include?("/adapters/") || _1.include?("/encryption/performance/") }
  files.concat(Dir["test/cases/adapters/sqlite3/**/*_test.rb"].sort)
end
files.each { require File.expand_path(_1) }
require_relative "ar_equivalence_runtime"
built = Lowrail::AREquivalenceRuntime.build
File.write(ENV.fetch("LOWRAIL_OUTCOMES") + ".build.json", JSON.pretty_generate({
  "units" => built[:manifest].units.map { [_1["id"], _1["pass"], _1["file"]] }, "ledger" => built[:ledger] }))
at_exit do
  # This block runs before Minitest's autorun. Its after_run hook writes the
  # checks actually reached, not just the units that happened to build.
  Minitest.after_run do
    File.write(ENV.fetch("LOWRAIL_OUTCOMES") + ".shadow.json", JSON.pretty_generate({
      "checks" => Lowrail::ARShadow.counts, "mismatches" => Lowrail::ARShadow.mismatches,
      "outcomes" => Lowrail::Minitest.reporter.observations }))
  end
end
