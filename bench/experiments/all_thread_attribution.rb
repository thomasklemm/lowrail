# frozen_string_literal: true

# Untimed synthetic validation only: one C process, one interpreter API smoke,
# one native refusal. Never boots Rails or launches a YJIT/price cohort.
require "json"
require "digest"
require "fileutils"
require "rbconfig"
require "shellwords"

resume = ARGV.delete("--resume")
output = ARGV.fetch(0) { abort "usage: all_thread_attribution.rb [--resume] OUTPUT" }
output = File.expand_path(output)
raise "fresh output required (or --resume to analyse retained runs)" if File.exist?(output) && !resume
raise "missing retained output" if resume && !File.directory?(output)
FileUtils.mkdir_p(output)
source = File.join(output, "sources")
files = %w[all_thread_callgrind.h all_thread_callgrind.c all_thread_control.c all_thread_attribution.rb]
unless resume
  FileUtils.mkdir_p(source)
  files.each { FileUtils.cp(File.join(__dir__, _1), source) }
end
cc = RbConfig::CONFIG.fetch("CC").shellsplit
control = File.join(output, "control")
extension = File.join(output, "lowrail_all_thread_callgrind.#{RbConfig::CONFIG.fetch('DLEXT')}")
raise "control compile failed" unless resume || system(*cc, "-O2", "-g", "-fno-stack-protector", "-fcf-protection=none", "-pthread",
  File.join(source, "all_thread_control.c"), "-o", control)
raise "extension compile failed" unless resume || system(*RbConfig::CONFIG.fetch("LDSHARED").shellsplit, "-fPIC", "-O2", "-g",
  "-I#{RbConfig::CONFIG.fetch('rubyhdrdir')}", "-I#{RbConfig::CONFIG.fetch('rubyarchhdrdir')}",
  File.join(source, "all_thread_callgrind.c"), "-o", extension)

# Self costs, not inclusive calls; independently reconcile every output's Ir.
def profile(file)
  names = {}
  current = nil
  call = false
  costs = Hash.new(0)
  children = Hash.new(0)
  total = nil
  thread = nil
  File.foreach(file) do |line|
    thread = Integer(line.split.last) if line.start_with?("thread: ")
    total = Integer(line.split.fetch(1)) if line.start_with?("totals: ")
    if (match = line.match(/\A(c?fn)=\((\d+)\)(?: (.*))?/))
      names[match[2]] = match[3]&.strip if match[3]
      current = names.fetch(match[2]) if match[1] == "fn"
    end
    call = true if line.start_with?("calls=")
    if (match = line.match(/\A(?:[+-]?\d+|\*)\s+(\d+)\s*\z/))
      costs.fetch(current) { costs[current] = 0 }
      if call
        children[current] += Integer(match[1])
      else
        costs[current] += Integer(match[1])
      end
      call = false
    end
  end
  raise "missing thread/Ir or self-cost mismatch: #{file}" unless thread && total && costs.values.sum == total
  {file: File.basename(file), thread: thread, Ir: total, request_work: costs.fetch("request_work", 0),
    background_work: costs.fetch("background_work", 0),
    tick_begin_Ir: costs.fetch("lowrail_cg_tick_begin", 0), tick_end_Ir: costs.fetch("lowrail_cg_tick_end", 0),
    tick_C_entry_Ir: %w[tick_begin tick_end].to_h { [_1, costs[_1] + children[_1]] },
    sha256: Digest::SHA256.file(file).hexdigest}
end

def execute(output, label, *command)
  log = File.join(output, "#{label}.log")
  status = File.join(output, "#{label}.status.json")
  if File.exist?(log)
    raise "previous #{label} failed/incomplete; never rerun" unless File.file?(status) && JSON.parse(File.read(status))["success"]
    raise "retained command differs: #{label}" unless JSON.parse(File.read(status)).fetch("command") == command
    return
  end
  ok = system(*command, out: log, err: [:child, :out])
  File.write(status, JSON.generate(success: ok, command: command))
  raise "#{label} failed; retained #{log}" unless ok
end

options = ["--tool=callgrind", "--instr-atstart=no", "--separate-threads=yes"]
execute(output, "control", "valgrind", *options,
  "--callgrind-out-file=#{output}/control.cg", control)
log = File.read(File.join(output, "control.log"))
mapping = log.scan(/^MAP (\w+) (\d+) (\d+)/).to_h { |role, tid, lwp| [role, {thread: tid.to_i, lwp: lwp.to_i}] }
raise "two distinct native and Valgrind identities required" unless mapping.size == 2 &&
  mapping.values.map { _1[:thread] }.uniq.size == 2 && mapping.values.map { _1[:lwp] }.uniq.size == 2
labels = log.scan(/^DUMP (\w+)/).flatten
expected = {"empty" => [3, 3], "asymmetric_a" => [151, 681], "asymmetric_b" => [1031, 117],
  "reset_all" => [31, 249], "dump_rebaseline" => [39, 405], "negative_current_reset" => [31, 9246],
  "negative_current_dump" => [151, nil], "negative_dump_background_retained" => [0, 681],
  "request_only_exclusion" => [31, 177], "parked_background" => [175, 0],
  "calibrate_off_a" => [151, 300003], "calibrate_off_b" => [40003, 300003], "calibrate_on" => [80003, 300003]}
raise "finite control cases changed" unless labels == expected.keys
ticks = log.scan(/^TICKS (\w+) (\d+) (\d+) (\d+) (\d+)/).to_h { |label, *counts| [label, counts.map(&:to_i)] }
windows = labels.each_with_index.to_h do |label, index|
  entries = Dir["#{output}/control.cg.#{index + 1}-*"].map { profile(_1) }
  ids = mapping.transform_values { _1.fetch(:thread) }
  required = label == "negative_current_dump" ? [ids.fetch("request")] : ids.values
  raise "lost or unexpected thread at #{label}" unless entries.map { _1[:thread] }.sort == required.sort
  request, background = expected.fetch(label)
  a = entries.find { _1[:thread] == ids.fetch("request") }
  b = entries.find { _1[:thread] == ids.fetch("background") }
  raise "request/background instruction oracle failed: #{label}" unless a.fetch(:request_work) == request &&
    (!background || b.fetch(:background_work) == background) && a.fetch(:background_work).zero? &&
    (!b || b.fetch(:request_work).zero?)
  activity = ticks[label]
  raise "missing activity endpoints: #{label}" unless activity || label == "negative_current_dump"
  if activity
    s0, c0, s1, c1 = activity
    count = label == "negative_current_reset" ? 2 : (label == "parked_background" ? 0 : 1)
    raise "partial/lost activity: #{label}" unless s0 == c0 && s1 == c1 && s1 - s0 == count
  end
  [label, {expected_request_work: request, expected_background_work: background,
    activity_endpoints: activity, threads: entries, process_Ir: entries.sum { _1.fetch(:Ir) }}]
end

rates = %w[calibrate_off_a calibrate_off_b calibrate_on].map do |label|
  windows.fetch(label).fetch(:threads).find { _1.fetch(:thread) == mapping.fetch("background").fetch(:thread) }.fetch(:Ir)
end
spread = 100.0 * (rates.max - rates.min) / rates.min
tolerance = [1, spread.ceil].max
raise "calibration refused (>1%): #{spread}%" if tolerance > 1

smoke = <<~'RUBY'
  require ARGV.fetch(0)
  a = LowrailCallgrindBench.thread_identity
  LowrailCallgrindBench.start(false)
  LowrailCallgrindBench.tick_begin
  31.times { Object.new }
  LowrailCallgrindBench.tick_end
  raise unless LowrailCallgrindBench.finish == 0
  raise unless LowrailCallgrindBench.window_activity.include?([*a, 0, 0, 1, 1])
  LowrailCallgrindBench.start(true)
  LowrailCallgrindBench.tick_begin
  GC.start
  LowrailCallgrindBench.tick_end
  raise unless LowrailCallgrindBench.finish.positive?
  raise unless LowrailCallgrindBench.window_activity.include?([*a, 1, 1, 2, 2])
  raise unless a == LowrailCallgrindBench.thread_identity
  puts "API_SMOKE_PASS"
RUBY
execute(output, "api", "valgrind", *options, "--callgrind-out-file=#{output}/api.cg",
  RbConfig.ruby, "--disable-yjit", "--disable-zjit", "-e", smoke, extension)
raise "API smoke incomplete" unless File.read(File.join(output, "api.log")).include?("API_SMOKE_PASS")
execute(output, "native_refusal", RbConfig.ruby, "--disable-yjit", "--disable-zjit", "-e", <<~'RUBY', extension)
  require ARGV.fetch(0)
  begin
    LowrailCallgrindBench.start
    abort "native accepted"
  rescue RuntimeError => e
    raise unless e.message == "Callgrind required"
    puts "NATIVE_REFUSAL_PASS"
  end
RUBY
raise "native refusal incomplete" unless File.read(File.join(output, "native_refusal.log")).include?("NATIVE_REFUSAL_PASS")
api_profiles = Dir["#{output}/api.cg.*-*"].map { profile(_1) }
result = {scope: "Untimed synthetic attribution validation, no app/YJIT/cohort/price/slot", status: "pass",
  mapping: mapping, windows: windows, api_smoke: true, native_refusal: true,
  api_profiles: api_profiles,
  calibration: {whole_background_Ir_per_tick: rates, relative_spread_percent: spread, tolerance_percent: tolerance},
  source_sha256: files.to_h { [_1, Digest::SHA256.file(File.join(source, _1)).hexdigest] },
  analysis_driver_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  evidence_sha256: Dir["#{output}/*"].select { File.file?(_1) && File.basename(_1) != "result.json" }
    .to_h { [File.basename(_1), Digest::SHA256.file(_1).hexdigest] }}
File.write(File.join(output, "result.json"), JSON.pretty_generate(result))
puts "ALL_THREAD_ATTRIBUTION_PASS #{windows.size} windows; exact 4n/6n work; all-thread reset/dump and negative controls"
