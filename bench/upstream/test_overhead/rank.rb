# frozen_string_literal: true

# Ranks framework parts by their share of each suite's sampled CPU (docs/upstream/test-overhead-2.md).
#   ruby rank.rb [--json OUT] RUN.PID.json...      (suite_profile.rb output; reads RUN.PID.stackprof next to it)
#   PT2_FOLDED=DIR ruby rank.rb suites/runs/APP-MODE.json...   (the committed archive: DIR/APP-MODE.folded, fold.rb)
# Shares are inclusive: a sample counts for a part when any frame on its stack belongs to it (parts overlap,
# e.g. SQL logging inside a factory's save). "excl" patterns drop samples that are really app or request work.
require "json"

PARTS = {
  "SQL and event debug logging" => [/\A(ActiveSupport::StructuredEventSubscriber#call|ActiveSupport::LogSubscriber#call|ActiveSupport::EventReporter#notify)\z/],
  "  of which query source (verbose_query_logs)" => [/\AActiveRecord::LogSubscriber#log_query_source\z/],
  "Fixtures, all" => [/\AActiveRecord::(TestFixtures#(setup_fixtures|teardown_fixtures|access_fixture|active_record_fixture)|FixtureSet\.create_fixtures)\z/],
  "  fixture loading" => [/\AActiveRecord::FixtureSet\.create_fixtures\z/],
  "  transactional setup and teardown" => [/\AActiveRecord::TestFixtures#(setup_transactional_fixtures|teardown_transactional_fixtures)\z/],
  "  fixture accessors (record finds)" => [/\AActiveRecord::TestFixtures#(access_fixture|active_record_fixture)\z/],
  "Integration session, outside the request" => [/\AActionDispatch::Integration::(Session#|RequestHelpers#|Runner#(create_session|integration_session|reset!|copy_session_variables!|get|post|patch|put|delete|head)\z)/,
    /\A(Rails::Engine#call|AbstractController::Base#process|ActionController::Metal#dispatch|ActiveRecord::TestFixtures#method_missing)\z/],
  "  rack-test request and cookies" => [/\ARack::Test::Session#request\z/, /\A(Rails::Engine#call|AbstractController::Base#process)\z/],
  "Controller test plumbing, outside the action" => [/\AActionController::TestCase::Behavior#process\z/, /\AAbstractController::Base#process\z/],
  "Factories, all (factory_bot, Fabrication)" => [/\A(FactoryBot::|Fabricat)/],
  "  factory gem's own code" => [:leaf_gem, /\/(factory_bot|fabrication)-[\d.]+\//, %r{\A@gem/(factory_bot|fabrication)\z}],
  "Test framework (Minitest, RSpec, Rails test helpers), own code" => [:leaf_gem,
    %r{/(minitest|rspec-core|rspec-expectations|rspec-support|rails-dom-testing)-[\d.]+/|/active_support/testing/|/active_record/test_fixtures|/action_dispatch/testing/|/action_controller/test_case|/active_job/test_helper|/rails/test_unit/},
    %r{\A@(gem/(minitest|rspec-core|rspec-expectations|rspec-support|rails-dom-testing)|testing)\z}],
  "Mocks and stubs (Mocha, WebMock, rspec-mocks)" => [/\A(Mocha::|WebMock|RSpec::Mocks)/],
  "Garbage collection" => [:gc],
}.freeze

def tally(totals, names, leaf_matches, last)
  PARTS.each do |part, (rule, excl, token)|
    hit = case rule
    when :gc then last.start_with?("(")
    when :leaf_gem then leaf_matches.(excl, token)
    else names.any? { _1.match?(rule) } && !(excl && names.any? { _1.match?(excl) })
    end
    totals[part] += yield if hit
  end
end

def share_folded(path)
  totals, all = Hash.new(0), 0
  File.foreach(path) do |line|
    stack, weight = line.rpartition(" ").then { [_1.split(";"), Integer(_3)] }
    leaf = stack.pop
    all += weight
    tally(totals, stack, ->(_, token) { token && leaf.match?(token) }, stack.last.to_s) { weight }
  end
  PARTS.keys.to_h { [_1, 100.0 * totals[_1] / all] }
end

def share(path)
  if (dir = ENV["PT2_FOLDED"])
    return share_folded(File.join(dir, File.basename(path, ".json") + ".folded"))
  end
  data = Marshal.load(File.binread(path.sub(/\.json\z/, ".stackprof")))
  frames, raw = data.fetch(:frames), data.fetch(:raw)
  names = Hash.new { |h, id| h[id] = frames.dig(id, :name).to_s }
  files = Hash.new { |h, id| h[id] = frames.dig(id, :file).to_s }
  totals = Hash.new(0)
  all = 0
  i = 0
  while (len = raw[i])
    stack, weight = raw[i + 1, len], raw[i + 1 + len]
    i += len + 2
    all += weight
    leaf_ruby = stack.reverse_each.find { !files[_1].empty? && !files[_1].start_with?("<") }
    tally(totals, stack.map { names[_1] }, ->(file_re, _) { leaf_ruby && files[leaf_ruby].match?(file_re) },
      names[stack.last]) { weight }
  end
  PARTS.keys.to_h { [_1, 100.0 * totals[_1] / all] }
end

out = (i = ARGV.index("--json")) ? ARGV.slice!(i, 2).last : nil
apps = ARGV.to_h do |path|
  meta = JSON.parse(File.read(path))
  name = File.basename(path).split("-").first
  w = meta.fetch("window")
  [name, { "tests" => meta["tests"], "cpu_ms_per_test" => (1000 * w["cpu"] / meta["tests"]).round(1),
    "objects_per_test" => (w["allocs"] / meta["tests"]).round, "ruby" => meta["ruby"], "shares" => share(path) }]
end
median = ->(xs) { s = xs.sort; (s[(s.size - 1) / 2] + s[s.size / 2]) / 2.0 }
puts "| Part | #{apps.keys.join(" | ")} | Median |"
puts "| --- |#{" ---: |" * (apps.size + 1)}"
%w[tests cpu_ms_per_test objects_per_test].each { |k| puts "| #{k.tr("_", " ")} | #{apps.values.map { _1[k] }.join(" | ")} | |" }
PARTS.each_key do |part|
  vals = apps.values.map { _1["shares"][part] }
  puts "| #{part.sub(/\A  /, "· ")} | #{vals.map { format("%.1f%%", _1) }.join(" | ")} | #{format("%.1f%%", median.(vals))} |"
end
File.write(out, JSON.pretty_generate(apps) + "\n") if out
