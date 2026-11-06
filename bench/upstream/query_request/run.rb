# frozen_string_literal: true

# Run with the measurement Ruby: ruby run.rb NEW_OUTPUT BASE CONTROL CANDIDATE.
# BUNDLE_GEMFILE selects the same dependency lock for every tree; no Lowrail runtime is loaded.
require "json"
require "fileutils"
require "rbconfig"
require "shellwords"
require "digest"
require_relative "../../heap_windows"
require_relative "../../jit_stability"

out, *trees = ARGV.map { File.expand_path(_1) }
raise "new output directory and three Rails trees required" unless out && trees.size == 3 && !File.exist?(out)
FileUtils.mkdir_p(out)
root = File.expand_path("../../..", __dir__)
extension = File.join(out, "lowrail_callgrind.so")
raise "extension compile failed" unless system(*RbConfig::CONFIG.fetch("LDSHARED").shellsplit, "-fPIC", "-O2",
  "-I#{RbConfig::CONFIG.fetch('rubyhdrdir')}", "-I#{RbConfig::CONFIG.fetch('rubyarchhdrdir')}",
  File.join(root, "bench/callgrind.c"), "-o", extension)
floors = HeapWindows.floors.each_with_index.to_h { |slots, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", slots.to_s] }
tool = ENV.fetch("VALGRIND", File.expand_path("~/vg-brk512/bin/valgrind"))
workers = []
3.times do |round|
  [0, 1, 2].rotate(round).each do |arm|
    label = "r#{round}-#{%w[base control candidate].fetch(arm)}"
    cg = File.join(out, "#{label}.callgrind")
    env = floors.merge("BENCH_RAILS_PATH" => trees.fetch(arm), "BENCH_OUTPUT" => out,
      "BENCH_CALLGRIND_EXTENSION" => extension)
    flags = JitStability.flags
    flags += %w[--zjit-stats-quiet --zjit-mem-size=1024] if JitStability.mode == "zjit"
    ok = system(env, tool, "--tool=callgrind", "--instr-atstart=no", "--callgrind-out-file=#{cg}",
      RbConfig.ruby, *flags, "-rbundler/setup", File.join(__dir__, "worker.rb"),
      out: File.join(out, "#{label}.json"), err: File.join(out, "#{label}.log"))
    log = File.read(File.join(out, "#{label}.log"))
    raise "failed #{label}: inspect log" unless ok && !log.match?(/brk segment overflow|Cannot map memory to grow brk/)
    data = JSON.parse(File.read(File.join(out, "#{label}.json")))
    data.fetch("windows").each_with_index do |window, index|
      totals = File.foreach("#{cg}.#{index + 1}").find { _1.start_with?("totals:") }
      window["ir"] = Integer(totals.split.fetch(1))
    end
    raise "heap grew in #{label}" unless data.fetch("windows").all? { _1.fetch("heap_ok") }
    data["arm"] = %w[base control candidate].fetch(arm)
    data["round"] = round
    data["values"] = data.fetch("windows").each_slice(2).to_h do |zero, measured|
      [zero.fetch("name"), %w[ir objects bytes].to_h { |key|
        [key, (measured.fetch(key) - zero.fetch(key)).fdiv(measured.fetch("n"))]
      }]
    end
    workers << data
    puts "#{label}: #{JSON.generate(data.fetch('values'))}"
    $stdout.flush
  end
end
heap_equal = workers.map { _1.fetch("capacity") }.uniq.size == 1
File.write(File.join(out, "results.json"), JSON.pretty_generate(
  ruby: RUBY_DESCRIPTION, tool_sha256: Digest::SHA256.file(File.join(File.dirname(tool), "../libexec/valgrind/callgrind-amd64-linux")).hexdigest,
  worker_sha256: Digest::SHA256.file(File.join(__dir__, "worker.rb")).hexdigest,
  cross_worker_heap_equal: heap_equal,
  jit_control: JitStability.control(workers.each_with_index.to_h { |worker, index| [index.to_s, worker] }, requested: JitStability.mode),
  workers: workers))
raise "cross-worker heap mismatch (results retained)" unless heap_equal
