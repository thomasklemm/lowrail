# frozen_string_literal: true

# Cachegrind instructions per iteration for ANALYZE variants of ruby-bench's
# database benchmarks (round 4). Like actionview_cpu/ruby_bench_ir.rb, but each
# variant is its own ruby-bench tree (~/rb4/<variant>, same path length):
# base-a/base-b are main, anlz-a/anlz-b add the ANALYZE lines.
#   ruby ir.rb run OUT_DIR   then   ruby ir.rb summary OUT_DIR
# Ir per iteration = (run with LONG iterations - run with 1) / (LONG - 1),
# both after WARMUP iterations, interpreter, fixed heap (docs/bench.md).
require "open3"
require "fileutils"

ROOT = File.expand_path("~/rb4")
RUBY = File.expand_path("~/.local/share/mise/installs/ruby/4.0.9/bin/ruby")
BENCHES = ENV.fetch("BENCHES", "railsbench,activerecord,sequel").split(",")
VARIANTS = %w[base-a base-b anlz-a anlz-b]
WARMUP, LONG = 2, 4
HEAP = { "RUBY_GC_HEAP_0_INIT_SLOTS" => "1000000", "RUBY_GC_HEAP_1_INIT_SLOTS" => "250000",
         "RUBY_GC_HEAP_2_INIT_SLOTS" => "100000", "RUBY_GC_HEAP_3_INIT_SLOTS" => "20000",
         "RUBY_GC_HEAP_4_INIT_SLOTS" => "10000" }

cmd, out = ARGV
out = File.expand_path(out)
case cmd
when "run"
  FileUtils.mkdir_p(out)
  queue = Queue.new
  # Longest first so the slow railsbench runs start early.
  BENCHES.product([LONG, 1], VARIANTS).each { queue << _1 }
  queue.close
  Integer(ENV.fetch("JOBS", "4")).times.map do
    Thread.new do
      while (bench, itrs, variant = queue.pop)
        name = "#{bench}-#{variant}-#{itrs}"
        next if File.exist?(File.join(out, "#{name}.ir"))
        env = HEAP.merge("WARMUP_ITRS" => WARMUP.to_s, "MIN_BENCH_ITRS" => itrs.to_s, "MIN_BENCH_TIME" => "0",
                         "HARNESS" => "default", "OUT_CSV_PATH" => File.join(out, "#{name}.csv"))
        env["DATABASE_URL"] = "sqlite3:#{File.join(out, "#{name}.sqlite3")}" if bench == "railsbench"
        vg = %w[valgrind --tool=cachegrind --cache-sim=no --branch-sim=no --cachegrind-out-file=/dev/null]
        log, status = Open3.capture2e(env, *vg, RUBY, "benchmarks/#{bench}/benchmark.rb", chdir: File.join(ROOT, variant))
        File.write(File.join(out, "#{name}.log"), log)
        ir = log[/I\s+refs:\s+([\d,]+)/, 1]
        abort "#{name} failed (#{status}); see #{name}.log" unless status.success? && ir
        File.write(File.join(out, "#{name}.ir"), ir.delete(",") + "\n")
        warn "#{name}: #{ir}"
      end
    end
  end.each(&:join)
when "summary"
  ir = ->(b, v, n) { Integer(File.read(File.join(out, "#{b}-#{v}-#{n}.ir"))) }
  puts "| benchmark | variant | Ir per iteration | against base-a |", "| --- | --- | ---: | ---: |"
  BENCHES.each do |b|
    per = VARIANTS.to_h { |v| [v, (ir.(b, v, LONG) - ir.(b, v, 1)) / (LONG - 1).to_f] }
    per.each { |v, x| puts format("| %s | %s | %.0f | %s |", b, v, x, v == "base-a" ? "–" : format("%+.3f%%", (x / per["base-a"] - 1) * 100)) }
  end
end
