# frozen_string_literal: true

# Reuse the exact RPS boot, samples, worker coverage and cleanup without
# starting oha or producing another performance cohort. No app/config edits.
shared, config_path, output = ARGV
abort "usage: jit_guards_admission.rb SHARED_RPS CONFIG NEW_OUTPUT" unless output
load File.realpath(shared)
require_relative "jit_guards_rps"

module JitGuardsAdmission
  PAIRED_SAMPLES = NativeRps.method(:samples)

  def samples(config, directory, phase)
    # Keep paired request histories identical. On-only coverage fanout logs
    # in again and inserts a session; do it only AFTER both paired samples.
    cold = PAIRED_SAMPLES.call(config, directory, phase)
    client = NativeRps::Client.new(config, directory)
    client.login
    20.times do |index|
      raise "warm GET failed" unless client.request("GET", "/buckets", "warm#{index}").code == "200"
    end
    warm = PAIRED_SAMPLES.call(config, directory, "warm")
    super(config, directory, "coverage")
    (@admission_rows ||= []) << {"arm" => File.basename(directory).delete_prefix("validation-"),
      "samples" => cold, "warm_samples" => warm}
    return cold unless @admission_rows.size == 3

    checks = exact_checks(@admission_rows)
    warm_checks = exact_checks(@admission_rows.map { {"samples" => _1.fetch("warm_samples")} })
    passed = [checks, warm_checks].all? { |set| set.values.all? { _1.fetch("passed") } }
    throw :admission_complete, {"passed" => passed, "scope" => "untimed real-Puma admission only; no throughput measurement",
      "cold" => checks, "warm" => warm_checks, "rows" => @admission_rows}
  end

  def load(*)
    raise "admission probe must never start a timing window"
  end
end

NativeRps.singleton_class.prepend(JitGuardsRPS)
NativeRps.singleton_class.prepend(JitGuardsAdmission)
config = JSON.parse(File.read(config_path)).merge("rounds" => 2)
result = catch(:admission_complete) { NativeRps.run(config, File.expand_path(output)); raise "admission did not stop" }
NativeRps.write(File.join(output, "admission-only.json"), result)
puts JSON.pretty_generate(result.slice("passed", "scope", "cold", "warm"))
exit(result.fetch("passed") ? 0 : 2)
