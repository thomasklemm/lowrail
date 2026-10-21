#!/usr/bin/env ruby
# Untimed, fixed-count diagnostic. No runtime or application source edits.
# mise exec ruby@4.0.7 -- ruby script/rails82-setup-check.rb APP PRIVATE_OUTPUT_DIR [loads|sql]
if ENV["LOWRAIL_SETUP_CHECK_CHILD"] == "1"
  require "lowrail/setup"
  at_exit do
    names = ->(owner) { owner.ancestors.map { Module.instance_method(:name).bind_call(_1) } }
    Lowrail.write_json(ENV.fetch("LOWRAIL_SETUP_CHECK_WITNESS"), {
      "module_ancestors" => names.call(Module),
      "iseq_singleton_ancestors" => names.call(RubyVM::InstructionSequence.singleton_class),
      "iseq_ancestors" => names.call(RubyVM::InstructionSequence),
      "setup_features" => $LOADED_FEATURES.select { _1.match?(%r{/lowrail/|/bootsnap|/require[_-]hooks}) },
      "manifest_units" => Lowrail.manifest&.units&.size,
      "refusal" => Lowrail.refusal_reason
    })
  end
else
  require "json"
  require "digest"
  require "fileutils"
  abort "usage: rails82-setup-check.rb APP PRIVATE_OUTPUT_DIR [loads|sql]" unless (2..3).cover?(ARGV.size)
  abort "Ruby 4.0.7 required" unless RUBY_VERSION == "4.0.7"
  app, output = ARGV.first(2).map { File.expand_path(_1) }
  scenario = ARGV[2] || "loads"
  command = case scenario
  when "loads" then %w[bundle exec rails test test/system/push_subscription_resync_test.rb -n /a_browser_posts/ --seed 41231]
  when "sql" then %w[bundle exec rails test --seed 41231]
  else abort "unknown scenario: #{scenario}"
  end
  root = File.expand_path("..", __dir__)
  manifest_path = File.join(app, ".lowrail/manifest.json")
  manifest = JSON.parse(File.read(manifest_path))
  abort "requires an EMPTY, compatible default manifest" unless manifest.fetch("units").empty? &&
    manifest.fetch("files").empty? && manifest.fetch("selected_passes").empty? && manifest.fetch("rails_env") == "test"
  abort "output already exists; never overwrite a cohort" if File.exist?(output)
  FileUtils.mkdir_p(output)
  schedule = %w[offoff offon].flat_map do |kind|
    (1..3).flat_map { |pair| [["#{kind}-#{pair}-a", "0"], ["#{kind}-#{pair}-b", kind == "offoff" ? "0" : "1"]] }
  end
  rows = schedule.map do |label, mode|
    base = File.join(output, label)
    env = {"RAILS_ENV" => "test", "LOWRAIL" => mode, "PARALLEL_WORKERS" => "1", "MT_CPU" => "1",
      "SEED" => "41231", "LOWRAIL_VERIFY_LOADS" => "1", "LOWRAIL_SHADOW" => "strict",
      "LOWRAIL_OUTCOMES" => "#{base}.json", "LOWRAIL_SQL_TRACE" => "full", "LOWRAIL_STATS" => "",
      "LOWRAIL_SETUP_CHECK_CHILD" => "1", "LOWRAIL_SETUP_CHECK_WITNESS" => "#{base}-witness.json",
      "RUBYOPT" => "-I#{root}/gem/lib -r#{File.expand_path(__FILE__)}", "BUNDLE_FROZEN" => "true"}
    status = File.open("#{base}.log", "w") do |log|
      system(env, *command, chdir: app, out: log, err: log)
      $?.exitstatus
    end
    raw = JSON.parse(File.read("#{base}.json"))
    witness = JSON.parse(File.read("#{base}-witness.json"))
    events = raw.fetch("verify_loads").fetch("stages").fetch("after_suite").fetch("load_events").sort_by { _1.to_i }
    targets = events.select { _1.match?(/\t(?:RoomScoped|Rooms::InvolvementsController|ActionCable::Server::(?:Socket|TaggedLoggerProxy))\t/) }
    row = {"label" => label, "mode" => mode, "exit" => status,
      "tests" => raw.fetch("tests").transform_values { _1.fetch("result") },
      "target_events" => targets, "sql" => raw.fetch("sql").transform_values do |entry|
        lines = entry.fetch("lines")
        own = lines.index("--- other threads")
        entry.slice("digest", "n", "other_digest", "skipped").merge("own_n" => own, "other_n" => lines.size - own - 1)
      end,
      "witness" => witness}
    sql = row["sql"].select { |key, _| key.include?("#test_concurrent_ensure!_repairs") }
    puts "#{label}: exit #{status}, #{row['tests'].values.tally}, #{targets.map { _1.split("\t")[0, 3].join(':') }.join(', ')}, #{sql}"
    row
  end
  report = {"ruby" => RUBY_DESCRIPTION, "scenario" => scenario, "command" => command,
    "manifest_sha256" => Digest::SHA256.file(manifest_path).hexdigest,
    "lock_sha256" => Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
    "policy" => "Three off/off and three off/on pairs, all fresh processes; no reruns or performance measurements.", "runs" => rows}
  File.write(File.join(output, "summary.json"), JSON.pretty_generate(report) + "\n")
end
