# frozen_string_literal: true

# Compares probe.rb outputs: BASE and BASE2 (two runs of the base, the A/A) against HEAD, per app.
#   ruby probe_compare.rb BASE_DIR BASE2_DIR HEAD_DIR
# A workload counts only when the A/A agrees on it; then any difference between BASE and HEAD is listed.
require "json"

base_dir, aa_dir, head_dir = ARGV
totals = Hash.new(0)
Dir[File.join(base_dir, "*.json")].sort.each do |path|
  app = File.basename(path, ".json")
  runs = [base_dir, aa_dir, head_dir].map do |dir|
    file = File.join(dir, "#{app}.json")
    File.exist?(file) ? JSON.parse(File.read(file)).fetch("workloads") : nil
  end
  if runs.last.nil?
    puts "#{app}: no head run"
    next
  end
  base, aa, head = runs
  stats = Hash.new(0)
  base.each do |name, b|
    a, h = aa[name], head[name]
    next stats[:missing] += 1 unless a && h
    %w[bodies records].each do |part|
      bv = part == "bodies" ? [b["bodies"], b["error"]] : b["records"].except("classes")
      av = part == "bodies" ? [a["bodies"], a["error"]] : a["records"].except("classes")
      hv = part == "bodies" ? [h["bodies"], h["error"]] : h["records"].except("classes")
      next stats[:"#{part}_unstable"] += 1 unless bv == av
      stats[:"#{part}_compared"] += 1
      next if bv == hv
      stats[:"#{part}_differ"] += 1
      puts "#{app} #{name} #{part} differ"
      if part == "records"
        rows_b, rows_h = b["record_rows"], h["record_rows"]
        first = rows_b.zip(rows_h).index { _1 != _2 } || [rows_b.size, rows_h.size].min
        puts "  base (#{rows_b.size}): #{rows_b[first].inspect[0, 600]}"
        puts "  head (#{rows_h.size}): #{rows_h[first].inspect[0, 600]}"
      else
        puts "  base: #{bv.inspect[0, 400]}"
        puts "  head: #{hv.inspect[0, 400]}"
      end
    end
  end
  stats.each { |k, v| totals[k] += v }
  puts "#{app}: #{stats.sort.map { |k, v| "#{k}=#{v}" }.join(" ")}"
end
puts "ALL: #{totals.sort.map { |k, v| "#{k}=#{v}" }.join(" ")}"
