# frozen_string_literal: true

# Classifies the raw stackprof samples that suite_profile.rb writes (docs/upstream/test-overhead-2.md).
#   ruby classify.rb RUN.PID.json [--json OUT]      (reads RUN.PID.stackprof next to it)
# Each sample (weight: wall or CPU ticks, or objects) gets three labels:
#   phase:     runner (outside a test), setup, body or teardown, from the hook frames on its stack; gc, or
#              thread for threads the tests start;
#   component: the outermost framework part it runs in (fixture loading, transactions, integration-session
#              plumbing, the request that session drives, factories, mocks, ...), or none;
#   owner:     who the leaf Ruby frame belongs to (cfuncs are charged to their Ruby caller): app, tests,
#              rails/<component>, minitest, rspec, factory_bot, gem/<name>, ruby, gc.
require "json"

COMPONENTS = [
  ["fixtures.load", /\AActiveRecord::FixtureSet\.create_fixtures\z/],
  ["fixtures.tx_setup", /\AActiveRecord::TestFixtures#setup_transactional_fixtures\z/],
  ["fixtures.tx_teardown", /\AActiveRecord::TestFixtures#teardown_transactional_fixtures\z/],
  ["fixtures.other", /\AActiveRecord::TestFixtures#(setup_fixtures|teardown_fixtures)\z/],
  ["fixtures.access", /\AActiveRecord::TestFixtures#(access_fixture|active_record_fixture|method_missing|fixture)\z/],
  ["parallel", /\AActiveSupport::Testing::(Parallelization|ParallelizeExecutor)/],
  ["integration", /\AActionDispatch::Integration::(Session#|RequestHelpers#|Runner#(create_session|integration_session|reset!|copy_session_variables!|method_missing|get|post|patch|put|delete|head)\z)/],
  ["controller_test", /\AActionController::TestCase::Behavior#(process|setup_controller_request_and_response)\z/],
  ["factory_bot", /\AFactoryBot::/],
  ["fabrication", /\AFabricat/],
  ["rspec.mocks", /\ARSpec::Mocks\.(setup|verify|teardown)\z/],
  ["database_cleaner", /\ADatabaseCleaner/],
  ["webmock", /\AWebMock/],
  ["mocha", /\AMocha::/],
].freeze
# Inside integration and controller tests, the request itself.
REQUEST = /\A(Rails::Engine#call|AbstractController::Base#process|ActionController::Metal#dispatch)\z/
SETUP = /\A(PT2Hooks#(before_setup|setup|after_setup)|RSpec::Core::Example#run_before_example|.*#before_setup)\z/
TEARDOWN = /\A(PT2Hooks#(before_teardown|teardown|after_teardown)|RSpec::Core::Example#run_after_example|.*#after_teardown)\z/
TEST = /\A(Minitest::Test#run|RSpec::Core::Example#run)\z/
PERSIST = /\AActiveRecord::(Transactions|Persistence|Suppressor)#save!?\z/
RUNNER = /\A(Minitest\.run_all_suites|RSpec::Core::Runner#run_specs|.*#run_specs)\z/
RAILS = %w[activerecord actionpack actionview activesupport activemodel activejob actionmailer actioncable
  activestorage actiontext actionmailbox railties].freeze

# Test support inside Rails components, split from the runtime code it calls.
TESTING = [
  ["rails/ar-fixtures", %r{/active_record/(test_fixtures|fixtures|fixture_set/|test_databases|testing/)}],
  ["rails/as-testing", %r{/active_support/(testing/|test_case\.rb)}],
  ["rails/ap-testing", %r{/action_dispatch/(testing/|system_test)|/action_controller/(test_case|metal/testing)}],
  ["rails/av-testing", %r{/action_view/test_case}],
  ["rails/aj-testing", %r{/active_job/test_helper}],
  ["rails/railties-testing", %r{/rails/test_(help|unit/)}],
].freeze

def owner(file, app)
  return nil if file.nil? || file.empty? || file.start_with?("<")
  TESTING.each { |name, re| return name if file.match?(re) }
  if file.start_with?(app)
    rel = file.delete_prefix(app)
    return nil if rel.start_with?("vendor/")
    return rel.start_with?("test/", "spec/") ? "tests" : "app"
  end
  return "rails/#{$1}" if file =~ %r{/rails-\h{12}/([a-z]+)/}
  if (m = file.match(%r{/(?:gems|bundler/gems)/([^/]+?)-(?:\d[^/]*|\h{12})/}))
    name = m[1]
    return "rails/#{name}" if RAILS.include?(name)
    return name if %w[minitest factory_bot fabrication].include?(name)
    return "rspec" if name.start_with?("rspec")
    return "gem/#{name}"
  end
  return "ruby" if file.match?(%r{/lib/ruby/\d})
  "other"
end

meta = JSON.parse(File.read(ARGV.fetch(0)))
app = File.join(meta.fetch("pwd"), "")
data = Marshal.load(File.binread(ARGV.fetch(0).sub(/\.json\z/, ".stackprof")))
frames = data.fetch(:frames)
raw = data.fetch(:raw)
tallies = Hash.new { |h, k| h[k] = Hash.new(0) }
total = 0
idx = 0
while (len = raw[idx])
  stack = raw[idx + 1, len]
  weight = raw[idx + 1 + len]
  idx += len + 2
  total += weight
  names = stack.map { frames.dig(_1, :name).to_s }
  leaf = names.last
  phase = if leaf.start_with?("(") then "gc"
  elsif !names.any? { _1.match?(RUNNER) } then "thread" # a thread the test started
  elsif !names.any? { _1.match?(TEST) } then "runner"
  elsif names.any? { _1.match?(SETUP) } then "setup"
  elsif names.any? { _1.match?(TEARDOWN) } then "teardown"
  else "body"
  end
  component = nil
  names.each do |n|
    component = COMPONENTS.find { |_, re| n.match?(re) }&.first
    break if component
  end
  if component == "fixtures.other" # setup_fixtures and teardown_fixtures call the transaction parts
    component = %w[fixtures.load fixtures.tx_setup fixtures.tx_teardown].find { |c| names.any? { _1.match?(COMPONENTS.to_h.fetch(c)) } } || component
  end
  if %w[integration controller_test].include?(component) && names.any? { _1.match?(REQUEST) }
    component = "#{component}.request"
  elsif %w[factory_bot fabrication].include?(component) && names.any? { _1.match?(PERSIST) }
    component = "#{component}.persist"
  end
  component ||= "none"
  own = if leaf.start_with?("(") then "gc" # (marking), (sweeping), (garbage collection)
  else stack.reverse_each.lazy.map { owner(frames.dig(_1, :file), app) }.find(&:itself) || "other"
  end
  tallies["phase"][phase] += weight
  tallies["component"][component] += weight
  tallies["owner"][own] += weight
  tallies["phase_component"]["#{phase} #{component}"] += weight
  tallies["component_owner"]["#{component} #{own}"] += weight
  tallies["leaf"]["#{leaf} (#{own})"] += weight
end

pct = ->(n) { total.zero? ? 0.0 : (100.0 * n / total).round(2) }
result = { "total" => total, "mode" => data[:mode].to_s, "tests" => meta["tests"], "window" => meta["window"] }
tallies.each { |k, h| result[k] = h.sort_by { -_2 }.first(k == "leaf" ? 80 : 200).to_h { [_1, pct.(_2)] } }
if (i = ARGV.index("--json"))
  File.write(ARGV.fetch(i + 1), JSON.pretty_generate(result) + "\n")
else
  puts JSON.pretty_generate(result)
end
