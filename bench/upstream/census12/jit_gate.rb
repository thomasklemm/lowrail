# frozen_string_literal: true

# Every YJIT measured window of the given cpu-census labels with its gate
# counters, as TSV: rejected windows are recorded, never rerun.
#   ruby jit_gate.rb DIR LABEL...
require "json"

dir, *labels = ARGV
keys = %w[compiled_iseq_count compiled_block_count invalidation_count code_gc_count]
puts %w[label app workload jit_flat warmup].concat(keys).join("\t")
labels.each do |label|
  Dir["#{dir}/#{label}/*-yjit.json"].sort.each do |path|
    run = JSON.parse(File.read(path))
    run["workloads"].each do |w|
      puts [label, run["app"], w["workload"], w["jit_flat"], w["warmup"], *keys.map { w["jit_delta"][_1] }].join("\t")
    end
  end
end
