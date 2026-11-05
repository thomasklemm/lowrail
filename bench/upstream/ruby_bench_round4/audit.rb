# frozen_string_literal: true

# Determinism audit of ruby-bench: per-iteration Callgrind Ir (and GC
# counters) of the default harness, several processes per benchmark.
#   ruby audit.rb run --out DIR --ruby RUBY [--valgrind] [--reps 3] [--jobs 4]
#     [--warmup 5] [--itrs 5] [--variant NAME] [--rubyopt OPTS] [--env K=V,..] BENCH...
#   ruby audit.rb summary --out DIR [--markdown] [--from 2]
# Each worker owns a copy of ruby-bench (COPIES/w<i>, made with `git worktree`
# from RUBY_BENCH_DIR), so two processes never share tmp/, logs or databases.
# Reps of one benchmark go to different workers. --variant/--rubyopt add
# control runs (e.g. a -r file that seeds the RNG) under another name.
require "json"
require "optparse"
require "fileutils"
require "open3"
require "etc"

ROUND = __dir__
SRC = ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench"))
COPIES = ENV.fetch("COPIES_DIR", "/tmp/rb4/copies")
EXT = ENV.fetch("CG_EXT_DIR", "/tmp/rb4/ext")
HEAP = { "RUBY_GC_HEAP_0_INIT_SLOTS" => "1000000", "RUBY_GC_HEAP_1_INIT_SLOTS" => "250000",
         "RUBY_GC_HEAP_2_INIT_SLOTS" => "100000", "RUBY_GC_HEAP_3_INIT_SLOTS" => "20000",
         "RUBY_GC_HEAP_4_INIT_SLOTS" => "10000" }.freeze

cmd = ARGV.shift
opts = { reps: 3, jobs: 4, warmup: 5, itrs: 5, variant: "base", env: {}, from: 2 }
OptionParser.new do |o|
  o.on("--out DIR") { opts[:out] = File.expand_path(_1) }
  o.on("--ruby PATH") { opts[:ruby] = _1 }
  o.on("--valgrind") { opts[:valgrind] = true }
  o.on("--reps N", Integer) { opts[:reps] = _1 }
  o.on("--jobs N", Integer) { opts[:jobs] = _1 }
  o.on("--warmup N", Integer) { opts[:warmup] = _1 }
  o.on("--itrs N", Integer) { opts[:itrs] = _1 }
  o.on("--variant NAME") { opts[:variant] = _1 }
  o.on("--rubyopt OPTS") { opts[:rubyopt] = _1 }
  o.on("--env LIST") { opts[:env] = _1.split(",").to_h { |kv| kv.split("=", 2) } }
  o.on("--no-heap") { opts[:no_heap] = true }
  o.on("--markdown") { opts[:markdown] = true }
  o.on("--from N", Integer) { opts[:from] = _1 }
  o.on("--copies-prefix P") { opts[:prefix] = _1 }
end.parse!
out = opts.fetch(:out)

def script_for(bench)
  dir = File.join(SRC, "benchmarks")
  return "benchmarks/#{bench}.rb" if File.file?(File.join(dir, "#{bench}.rb"))
  return "benchmarks/#{bench}/benchmark.rb" if File.file?(File.join(dir, bench, "benchmark.rb"))
  base, suffix = bench.split("-", 2)
  path = "benchmarks/#{base}/#{suffix}.rb"
  File.file?(File.join(SRC, path)) ? path : abort("no script for #{bench}")
end

def parse_cg(prefix)
  files = Dir["#{prefix}.*"].select { _1 =~ /\.\d+\z/ }.sort_by { _1[/\d+\z/].to_i }
  irs = files.map { |f| Integer(File.foreach(f).find { _1.start_with?("summary:", "totals:") }.split[1]) }
  files.each { File.delete(_1) }
  File.delete(prefix) if File.exist?(prefix)
  irs
end

case cmd
when "run"
  FileUtils.mkdir_p(out)
  prefix = opts[:prefix] || "w"
  copies = opts[:jobs].times.map do |i|
    path = File.join(COPIES, "#{prefix}#{i}")
    unless File.directory?(path)
      system("git", "-C", SRC, "worktree", "add", "--detach", "-q", path, "HEAD", exception: true)
    end
    path
  end
  jobs = ARGV.product((1..opts[:reps]).to_a)
  queues = copies.map { Queue.new }
  # Rep r of every benchmark goes to worker (index + r) % jobs.
  jobs.each_with_index { |(bench, rep), i| queues[(ARGV.index(bench) + rep) % copies.size] << [bench, rep] }
  queues.each(&:close)
  threads = copies.each_with_index.map do |copy, w|
    Thread.new do
      while (bench, rep = queues[w].pop)
        name = "#{bench}~#{opts[:variant]}~#{rep}"
        result = File.join(out, "#{name}.json")
        next if File.exist?(result)
        env = { "RUBY_BENCH_DIR" => copy, "WARMUP_ITRS" => opts[:warmup].to_s, "MIN_BENCH_ITRS" => opts[:itrs].to_s,
                "MIN_BENCH_TIME" => "0", "HARNESS" => "default", "RESULT_JSON_PATH" => File.join(out, "#{name}.result.json"),
                "OUT_CSV_PATH" => File.join(out, "#{name}.csv"), "CG_DUMP" => opts[:valgrind] ? "1" : "0",
                "RUBYOPT" => opts[:rubyopt] }
        env.merge!(HEAP) unless opts[:no_heap]
        env.merge!(opts[:env])
        cg = File.join(out, "#{name}.cg")
        vg = opts[:valgrind] ? ["valgrind", "--tool=callgrind", "--callgrind-out-file=#{cg}", "--dump-instr=no",
                                "--dump-line=no", "--compress-pos=no"] : []
        cmdline = ["setarch", Etc.uname[:machine], "-R", *vg, opts.fetch(:ruby), "-I", EXT,
                   "-r", File.join(ROUND, "cg_harness.rb"), script_for(bench)]
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        log, status = Open3.capture2e(env, *cmdline, chdir: copy)
        secs = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
        File.write(File.join(out, "#{name}.log"), log)
        stats = log.scan(/^CGSTAT (.*)$/).map { _1[0].split.map(&:to_i) }
        times = log.scan(/^\s*#(\d+):\s+(\d+)ms/).map { _1[1].to_i }
        irs = opts[:valgrind] ? parse_cg(cg) : []
        rec = { bench:, variant: opts[:variant], rep:, worker: w, ok: status.success?, secs: secs.round(1),
                irs:, times:, stats: }
        File.write(result, JSON.generate(rec))
        warn format("%-28s %s rep %d w%d %s %.0fs", bench, opts[:variant], rep, w, status.success? ? "ok" : "FAIL", secs)
      end
    end
  end
  threads.each(&:join)
when "summary"
  recs = Dir[File.join(out, "*.json")].reject { _1.end_with?(".result.json") }.map { JSON.parse(File.read(_1)) }
  recs.group_by { _1.values_at("bench", "variant") }.sort.each do |(bench, variant), rs|
    rs = rs.select { _1["ok"] }.sort_by { _1["rep"] }
    next puts("#{bench} #{variant}: no successful runs") if rs.empty?
    from = opts[:from] # index into irs: 0 boot, 1.. iterations
    key = rs.first["irs"].any? ? "irs" : nil
    series = rs.map { |r| key ? r["irs"][from..] : r["stats"].each_cons(2).map { |a, b| b[1] - a[1] }[(from - 1)..] }
    n = series.map(&:size).min
    # process A/A: mean per iteration of each process, max/min - 1
    means = series.map { _1.first(n).sum.to_f / n }
    aa = (means.max / means.min - 1) * 100
    # per iteration index: spread across processes
    per_itr = (0...n).map { |i| col = series.map { _1[i] }; (col.max.to_f / col.min - 1) * 100 }
    # within process: spread across iterations
    within = series.map { |s| (s.first(n).max.to_f / s.first(n).min - 1) * 100 }
    allocs = rs.map { |r| r["stats"].each_cons(2).map { |a, b| b[1] - a[1] }[(from - 1)..].first(n).sum / n.to_f }
    alloc_aa = allocs.min.positive? ? (allocs.max / allocs.min - 1) * 100 : 0
    puts format("%-26s %-8s n=%d procs=%d mean %.6g  A/A %.4f%%  max-itr %.4f%%  within %.4f%%  allocs A/A %.4f%%",
                bench, variant, n, rs.size, means.sum / means.size, aa, per_itr.max, within.max, alloc_aa)
  end
else
  abort "usage: audit.rb run|summary"
end
