# frozen_string_literal: true

# Paired, interleaved, multi-process wall-time driver.
#   ruby drive.rb OUT.jsonl ROUNDS MODES COLS ARMS
# MODES: interp,yjit,zjit  COLS: 10,30,100  ARMS: main,main2,l6 (Gemfiles in g-ARM/)
# Every round runs one fresh process per (mode, cols, arm); the arm order rotates
# by round so no arm always runs first. Each process is pinned to CPU $CPU (default 1).
require "json"
require "shellwords"

out, rounds, modes, cols, arms = ARGV
rounds = Integer(rounds)
modes = modes.split(",")
cols = cols.split(",").map { Integer(_1) }
arms = arms.split(",")
dir = __dir__
rubies = {
  "interp" => [File.join(`mise where ruby@4.0.10`.strip, "bin/ruby")],
  "yjit" => [File.join(`mise where ruby@4.0.10`.strip, "bin/ruby"), "--yjit"],
  "zjit" => [File.expand_path("~/rubies/master-42a644f6e0/bin/ruby"), "--zjit"],
  "minterp" => [File.expand_path("~/rubies/master-42a644f6e0/bin/ruby")]
}
heap = { "RUBY_GC_HEAP_0_INIT_SLOTS" => "1000000", "RUBY_GC_HEAP_1_INIT_SLOTS" => "250000",
  "RUBY_GC_HEAP_2_INIT_SLOTS" => "100000", "RUBY_GC_HEAP_3_INIT_SLOTS" => "20000", "RUBY_GC_HEAP_4_INIT_SLOTS" => "10000" }
cpu = ENV.fetch("CPU", "1")

File.open(out, "a") do |f|
  rounds.times do |r|
    modes.each do |mode|
      cols.each do |c|
        arms.rotate(r % arms.size).each do |arm|
          ruby, *flags = rubies.fetch(mode)
          env = heap.merge("COLS" => c.to_s, "ARM" => arm, "ROUND" => r.to_s, "MODE" => mode,
            "BUNDLE_GEMFILE" => File.join(dir, (mode == "zjit" || mode == "minterp") ? "gm-#{arm}" : "g-#{arm}", "Gemfile"))
          env["DB"] = ENV["DB"] if ENV["DB"]
          %w[WARM WINDOWS CALLS CASES].each { |k| env[k] = ENV[k] if ENV[k] }
          cmd = ["taskset", "-c", cpu, ruby, *flags, "-rbundler/setup", File.join(dir, "worker.rb")]
          line = IO.popen(env, cmd, unsetenv_others: false, &:read).lines.last
          raise "worker failed: #{cmd.shelljoin}" unless $?.success? && line&.start_with?("{")
          f.puts line
          f.flush
          $stderr.puts "round #{r} #{mode} cols=#{c} #{arm}"
        end
      end
    end
  end
end
