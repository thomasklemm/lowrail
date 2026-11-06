# frozen_string_literal: true

require "json"
require "digest"
require_relative "../stack_map/report"

base, output = ARGV
raise "usage: export.rb PRIVATE_DIRECTORY OUTPUT_JSON" unless base && output
rows = Dir[File.join(base, "results/*.json")].sort.filter_map do |path|
  next if File.basename(path).include?("smoke")
  data = JSON.parse(File.read(path))
  n = data.fetch("count")
  counter = data.fetch("counter")
  client = JSON.parse(File.read("#{path}.client"))
  delta = data.fetch("jit_before").to_h { |key, value| [key, data.fetch("jit_after").fetch(key) - value] }
  slots = ->(key) { data.fetch(key).transform_values { _1.fetch("heap_eden_slots") } }
  row = { id: File.basename(path), source: data.fetch("source"), ruby: data.fetch("ruby"),
    app: data.fetch("app"), threads: data.fetch("threads"), counter: counter, count: n,
    yjit: data.fetch("yjit"), jit_delta: delta, jit_flat: delta.values.all?(&:zero?),
    allocations_per_request: (data.fetch("stats_after").fetch("total_allocated_objects") -
      data.fetch("stats_before").fetch("total_allocated_objects")).fdiv(n),
    gc_runs: data.fetch("stats_after").fetch("count") - data.fetch("stats_before").fetch("count"),
    heap_slots_before: slots.call("pools_before"), heap_slots_after: slots.call("pools_after"),
    client: client, measurement_sha256: Digest::SHA256.file(path).hexdigest }
  row[:heap_capacity_unchanged] = row[:heap_slots_before] == row[:heap_slots_after]
  if counter == "callgrind"
    dump = "#{path}.callgrind.1"
    row[:ir_per_request] = Integer(File.read(dump).scan(/^totals: (\d+)/).last.fetch(0)).fdiv(n)
    row[:profile_sha256] = Digest::SHA256.file(dump).hexdigest
  elsif counter == "stacks"
    layers = StackMapReport.ruby_stacks("#{path}.stacks")
    row[:ir_per_request] = data.fetch("window").fetch("work_ir").fdiv(n)
    row[:samples] = data.fetch("window")
    row[:layers] = layers.slice(:exclusive, :inclusive)
    raw = JSON.parse(File.read("#{path}.stacks"))
    owners = Hash.new(0)
    raw.fetch("stacks").each do |stack, count|
      frame = stack.map { |id, _| raw.fetch("frames").fetch(id) }.find do |file, label, _|
        file != "<cfunc>" && !file.to_s.start_with?("<internal:")
      end
      owners[frame[1]] += count if frame
    end
    row[:top_ruby_owners] = owners.sort_by { -_2 }.first(30).to_h
    row[:profile_sha256] = Digest::SHA256.file("#{path}.stacks").hexdigest
  else
    metric = counter == "native" ? :cpu_us_per_request : :instrumented_cpu_us_per_request
    row[metric] = data.fetch("cpu_s") * 1_000_000 / n
    row[:system_us_per_request] = data.fetch("system_s") * 1_000_000 / n
    if counter == "perf"
      layers_path = "#{path}.layers"
      layers = if File.exist?(layers_path)
        JSON.parse(File.read(layers_path), symbolize_names: true)
      else
        StackMapReport.perf("#{path}.perf").tap { File.write(layers_path, JSON.generate(_1)) }
      end
      row[:layers] = layers.slice(:samples, :lost_samples, :exclusive, :inclusive_lower_bound, :dsos, :leaves)
      checksum, status = Open3.capture2("sudo", "sha256sum", "#{path}.perf")
      raise "perf checksum failed" unless status.success?
      row[:profile_sha256] = checksum.split.fetch(0)
    elsif counter == "strace"
      syscalls = {}
      File.foreach("#{path}.strace") do |line|
        fields = line.split
        next unless fields.first&.match?(/\A\d+\.\d+\z/) && fields.last.match?(/\A[a-z_][a-z_0-9]*\z/)
        next if fields.last == "total"
        syscalls[fields.last] = { calls: Integer(fields.fetch(3)), per_request: Integer(fields.fetch(3)).fdiv(n),
          errors: fields.size == 6 ? Integer(fields.fetch(4)) : 0 }
      end
      row[:syscalls] = syscalls
      row[:profile_sha256] = Digest::SHA256.file("#{path}.strace").hexdigest
    end
  end
  row
end
pairs = rows.filter_map do |row|
  next unless row[:id].end_with?("-a.json")
  twin = rows.find { _1[:id] == row[:id].sub(/-a.json\z/, "-aa.json") }
  next unless twin
  metric = %i[ir_per_request cpu_us_per_request instrumented_cpu_us_per_request].find { row.key?(_1) }
  { a: row[:id], aa: twin[:id], metric: metric, delta_percent: 100 * (twin.fetch(metric) / row.fetch(metric) - 1),
    jit_flat: row[:jit_flat] && twin[:jit_flat],
    heap_capacity_unchanged: row[:heap_capacity_unchanged] && twin[:heap_capacity_unchanged],
    admission: "diagnostic single pair; no confidence interval or speed claim" }
end
failures = Dir[File.join(base, "results/*.json.service.log")].sort.filter_map do |log|
  path = log.delete_suffix(".service.log")
  next if File.exist?(path) || !File.exist?("#{path}.info") || path.include?("smoke")
  { id: File.basename(path), result: "server started; no complete measurement",
    logs: Dir["#{path}*.log"].sort.to_h { [File.basename(_1), Digest::SHA256.file(_1).hexdigest] } }
end
probes = %w[release puma].to_h { [_1, JSON.parse(File.read(File.join(base, "#{_1}-probe.json")))] }
File.write(output, JSON.pretty_generate(windows: rows, pairs: pairs, failed_attempts: failures, probes: probes) + "\n")
puts "Exported #{rows.size} windows and #{pairs.size} same-base pairs; diagnostic only"
