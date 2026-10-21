# frozen_string_literal: true

require "open3"
require "fileutils"
require "json"
require "rbconfig"

root = File.expand_path("../..", __dir__)
corpus, output, *apps = ARGV
abort "usage: method_seal_corpus.rb CORPUS NEW_OUTPUT APP..." unless corpus && output && !apps.empty?
corpus, output = File.expand_path(corpus), File.expand_path(output)
raise "new output required" if File.exist?(output)
FileUtils.mkdir_p(output, mode: 0o700)
records = []
apps.each do |app|
  directory = File.join(corpus, app)
  args = app == "casa" ? %w[--seed 41231 --exclude-pattern spec/system/**/*_spec.rb] : []
  ENV.fetch("METHOD_SEAL_MODES", "baseline,freeze,warm_freeze,selective,tripwire").split(",").each do |mode|
    label = "#{app}-#{mode}"
    prefix = File.join(output, label)
    env = {"RAILS_ENV" => "test", "LOWRAIL" => "0", "PARALLEL_WORKERS" => "1", "MT_CPU" => "1", "SEED" => "41231",
      "METHOD_SEAL_MODE" => mode, "METHOD_SEAL_REPORT" => "#{prefix}.json", "LOWRAIL_OUTCOMES" => "#{prefix}-outcomes.json",
      "RUBYOPT" => "-I#{root}/gem/lib -rlowrail/setup", "DISABLE_SPRING" => "1"}
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = File.open("#{prefix}.log", "w") do |log|
      system(env, RbConfig.ruby, "-S", "bundle", "exec", "ruby", File.join(__dir__, "method_seal_suite.rb"), *args,
        chdir: directory, out: log, err: [:child, :out])
      $?
    end
    record = {"app" => app, "mode" => mode, "exit" => status.exitstatus,
      "seconds" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started}
    records << record
    File.write(File.join(output, "runs.json"), JSON.pretty_generate(records))
    puts JSON.generate(record)
    $stdout.flush
  end
end
