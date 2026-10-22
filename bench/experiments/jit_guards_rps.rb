# frozen_string_literal: true

# Bet Y reuses the shared real-Puma harness unchanged. Admission is untimed:
# every worker asserts its actual JIT mode after fork, and the coverage server
# must reach every worker with a guarded hit and zero fallbacks before load.
module NativeRps
  module PumaSetup
    def self.configure(puma:, config:, arm:)
      directory = File.dirname(ENV.fetch("PIDFILE"))
      puma.on_worker_boot do
        jit = {"pid" => Process.pid, "yjit" => RubyVM::YJIT.enabled?,
          "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?), "ruby" => RUBY_DESCRIPTION}
        raise "actual worker YJIT required" unless jit.fetch("yjit") && !jit.fetch("zjit")
        NativeRps.write(File.join(directory, "worker-jit-#{Process.pid}.json"), jit)
      end
    end
  end
end

module JitGuardsRPS
  def samples(config, directory, phase)
    rows = super
    master = JSON.parse(File.read(File.join(directory, "boot.json"))).fetch("pid")
    expected = File.read("/proc/#{master}/task/#{master}/children").split.map(&:to_i)
    raise "Puma worker count differs" unless expected.size == config.fetch("workers")
    jit = expected.to_h do |pid|
      row = JSON.parse(File.read(File.join(directory, "worker-jit-#{pid}.json")))
      raise "worker JIT receipt mismatch" unless row.fetch("pid") == pid && row.fetch("yjit") && !row.fetch("zjit")
      [pid, row]
    end
    NativeRps.write(File.join(directory, "jit-admission-#{phase}.json"), {"passed" => true, "workers" => jit})
    return rows unless File.basename(directory) == "validation-on"

    rows.each_value { check_hits!(_1) }
    observed = rows.values.to_h { [_1.fetch("pid"), _1.fetch("counts").fetch("direct_sites")] }
    client = NativeRps::Client.new(config, directory, 0, "admission")
    client.login
    64.times do |index|
      break if (expected - observed.keys).empty?
      response = client.request("GET", "/buckets", "hit#{index}")
      raise "coverage GET failed" unless response.code == "200"
      sample = JSON.parse(File.read(File.join(directory, "sample-0-admission-hit#{index}.json")))
      check_hits!(sample)
      observed[sample.fetch("pid")] = sample.fetch("counts").fetch("direct_sites")
    end
    passed = (expected - observed.keys).empty?
    NativeRps.write(File.join(directory, "direct-site-admission.json"),
      {"passed" => passed, "expected_pids" => expected, "workers" => observed, "jit" => jit})
    raise "not every Puma worker completed a DirectSite hit" unless passed
    rows
  end

  def check_hits!(sample)
    counts = sample.fetch("counts").fetch("direct_sites")
    raise "coverage entropy/status failed" unless sample.fetch("status") == 200 && sample.fetch("evidence").fetch("passed")
    raise "on coverage did not optimize" unless counts.fetch("bucket:hit", 0).positive? && counts.fetch("bucket:fallback", 0).zero?
  end
end

if $PROGRAM_NAME == __FILE__
  shared, config_path, output = ARGV
  abort "usage: jit_guards_rps.rb SHARED_SCRIPT_RPS CONFIG NEW_OUTPUT" unless output
  load File.realpath(shared)
  NativeRps.singleton_class.prepend(JitGuardsRPS)
  config = JSON.parse(File.read(config_path))
  raise "worker JIT hook required" unless File.realpath(config.fetch("puma_setup")) == File.realpath(__FILE__)
  report = NativeRps.run(config, File.expand_path(output))
  aa = report.fetch("summary").fetch("aa").fetch("ci95_pct")
  effect = report.fetch("summary").fetch("on_off").fetch("ci95_pct")
  decision = {"aa_pass" => aa.first <= 0 && aa.last >= 0,
    "rps_win" => effect.first > aa.last, "operational_pass" => report.fetch("passed"),
    "rule" => "A/A interval contains zero; treatment lower bound > A/A upper; all exact/error/worker gates; no retries/exclusions"}
  decision["accepted"] = decision.values_at("aa_pass", "rps_win", "operational_pass").all?
  NativeRps.write(File.join(output, "decision.json"), decision)
  exit(decision.fetch("accepted") ? 0 : 2)
end
