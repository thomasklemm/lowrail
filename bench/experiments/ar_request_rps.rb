# frozen_string_literal: true

# Reuse the unchanged shared RPS harness; add only DirectSite coverage admission.
# All extra requests are untimed, on the separate coverage server, before load.
module ARRequestRPS
  def samples(config, directory, phase)
    rows = super
    return rows unless File.basename(directory) == "validation-on"

    rows.each_value { check_hits!(_1) }
    master = JSON.parse(File.read(File.join(directory, "boot.json"))).fetch("pid")
    expected = File.read("/proc/#{master}/task/#{master}/children").split.map(&:to_i)
    raise "Puma worker count differs" unless expected.size == config.fetch("workers")
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
      {"passed" => passed, "expected_pids" => expected, "workers" => observed})
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
  abort "usage: ar_request_rps.rb SHARED_SCRIPT_RPS CONFIG NEW_OUTPUT" unless output
  load File.realpath(shared)
  NativeRps.singleton_class.prepend(ARRequestRPS)
  config = JSON.parse(File.read(config_path))
  report = NativeRps.run(config, File.expand_path(output))
  exit(report.fetch("passed") ? 0 : 2)
end
