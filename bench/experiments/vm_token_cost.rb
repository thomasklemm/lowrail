# frozen_string_literal: true

require_relative "../request_pairs"
require_relative "../heap_windows"

SOURCES = {
  "off_a" => "n.times { true }", "off_b" => "n.times { true }",
  "epoch_read" => "n.times { RubyVM.mutation_epoch }",
  "epoch_branch" => 'n.times { raise "changed" unless RubyVM.mutation_epoch == saved }',
  "token_read" => "n.times { token.valid? }",
  "token_branch" => 'n.times { raise "changed" unless token.valid? }',
  "c_off_a" => "VMTokenNative.empty(n)", "c_off_b" => "VMTokenNative.empty(n)",
  "c_token" => "VMTokenNative.checks(n, token)", "cas" => "VMTokenNative.bumps(n)"
}.freeze

harness_head, status = Open3.capture2("git", "-C", File.expand_path("../..", __dir__), "rev-parse", "HEAD")
raise "cannot identify benchmark harness revision" unless status.success?
harness_head = harness_head.strip

if (arm = ENV["TOKEN_COST_WORKER"])
  require ENV.fetch("TOKEN_COST_NATIVE")
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION") if ENV["BENCH_CALLGRIND_EXTENSION"]
  Object.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
    def token_operation(n, token, saved)
      #{SOURCES.fetch(arm)}
    end
  RUBY
  token = RubyVM.method_token(Hash, :each)
  saved = RubyVM.mutation_epoch
  token_operation(100_000, token, saved)
  if ENV["TOKEN_COST_NATIVE_RUN"]
    3.times { GC.start }
    t0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    token_operation(5_000_000, token, saved)
    puts "NATIVE_COST #{JSON.generate(cpu_seconds: Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t0,
      harness_head: harness_head)}"
    exit
  end
  warm = JitStability.warm { |n| token_operation(n, token, saved) } if RubyVM::YJIT.enabled?
  windows = HeapWindows.windows(100_000)
  anchors = HeapWindows.run(windows, observe: RubyVM::YJIT.enabled? ? JitStability.method(:snapshot) : nil) do |n|
    token_operation(n, token, saved)
  end
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, harness_head: harness_head, yjit: RubyVM::YJIT.enabled?,
    jit_warmup: warm, windows: windows, heap_anchors: anchors, ar_installed: 0)}"
  exit
end

mode, out = ARGV
abort "usage: vm_token_cost.rb native|micro NEW_DIRECTORY" unless %w[native micro].include?(mode) && out
abort "output must be new" if File.exist?(out)
FileUtils.mkdir_p(out)
source = File.expand_path("vm_token_native.c", __dir__)
FileUtils.cp(source, out)
File.write(File.join(out, "extconf.rb"), 'require "mkmf"; $CFLAGS += " -O3"; create_makefile("vm_token_native")')
raise "extconf failed" unless system(RbConfig.ruby, "extconf.rb", chdir: out)
raise "native build failed" unless system("make", chdir: out)
extension = File.expand_path("vm_token_native.#{RbConfig::CONFIG.fetch('DLEXT')}", out)
envs = SOURCES.keys.to_h { [_1, {"TOKEN_COST_WORKER" => _1, "TOKEN_COST_NATIVE" => extension, "RUBYOPT" => nil}] }
metadata = {seed: 41231, rounds: 6, workers: {}, ruby: RUBY_DESCRIPTION, harness_head: harness_head,
  sources: [__FILE__, source].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}
if mode == "native"
  rng = Random.new(41231)
  samples = 6.times.map do
    envs.keys.shuffle(random: rng).to_h do |arm|
      log, status = Open3.capture2e(envs.fetch(arm).merge("TOKEN_COST_NATIVE_RUN" => "1"),
        RbConfig.ruby, *JitStability.flags, File.expand_path(__FILE__))
      raise log unless status.success?
      [arm, JSON.parse(log.lines.find { _1.start_with?("NATIVE_COST ") }.delete_prefix("NATIVE_COST ")).fetch("cpu_seconds") * 200]
    end
  end
  File.write(File.join(out, "native.json"), JSON.pretty_generate(metadata: metadata, nanoseconds_per_check_including_loop: samples))
else
  accepted = RequestPairs.heap_instructions(envs, Dir.pwd, out, "tokens", metadata,
    worker: File.expand_path(__FILE__), requests: 100_000)
  samples = JSON.parse(File.read(File.join(out, "samples.json"))).fetch("samples")
  prices = (SOURCES.keys - %w[off_a off_b c_off_a c_off_b]).to_h do |arm|
    base = %w[c_token cas].include?(arm) ? "c_off_a" : "off_a"
    [arm, RequestPairs.estimate(samples.map { _1.fetch(arm).fetch("instructions_total") - _1.fetch(base).fetch("instructions_total") }, seed: 41231)]
  end
  File.write(File.join(out, "prices.json"), JSON.pretty_generate(accepted: accepted, prices: prices))
  puts JSON.pretty_generate(accepted: accepted, prices: prices)
  exit(accepted ? 0 : 2)
end
