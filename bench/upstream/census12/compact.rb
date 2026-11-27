# frozen_string_literal: true

# Compact copy of a cpu-census label for the repository: per workload its Ir/op,
# objects, GC share, JIT gate counters, and every method and line with at least
# MIN self Ir/op (default 5000, cpu_rank's reach; lines at 4x that), gzipped JSON per label and mode.
# Methods are [file, method, first line, self Ir/op, inclusive Ir/op]; lines
# [file, line, method, Ir/op, samples with a C frame on top, samples].
#   ruby compact.rb DIR LABEL MODE OUT_DIR [MIN]
require "json"
require "zlib"

dir, label, mode, out, min = ARGV
min = Float(min || 5000)
runs = Dir["#{dir}/#{label}/*-#{mode}.json"].sort.map do |path|
  run = JSON.parse(File.read(path))
  { app: run["app"], ruby: run["ruby"], rails: run["rails"], adapter: run["adapter"], lock_sha256: run["lock_sha256"],
    workloads: run["workloads"].map do |w|
      w.slice("workload", "kind", "ops", "warmup", "ir_per_op", "gc_ir_per_op", "objects_per_op", "gc_runs", "jit_delta", "jit_flat")
        .merge("methods" => w["methods"].select { _1["self_ir_per_op"] >= min }.map { [_1["file"], _1["method"], _1["line"], _1["self_ir_per_op"].round, _1["incl_ir_per_op"].round] },
          "sites" => w["sites"].select { _1["ir_per_op"] >= 4 * min }.map { [_1["file"], _1["line"], _1["method"], _1["ir_per_op"].round, _1["native"], _1["samples"]] })
    end }
end
meta = File.exist?("#{dir}/#{label}/meta.json") ? JSON.parse(File.read("#{dir}/#{label}/meta.json")) : nil
Zlib::GzipWriter.open(File.join(out, "#{label}-#{mode}.json.gz")) { _1.write(JSON.generate(label: label, mode: mode, min_ir: min, meta: meta, runs: runs)) }
