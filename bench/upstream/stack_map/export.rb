# frozen_string_literal: true

require "json"
require "digest"

base, output = ARGV
raise "usage: export.rb PRIVATE_DIRECTORY OUTPUT_JSON" unless base && output
root = File.expand_path("../../..", __dir__)
units = { "railsbench" => 2000, "lobsters" => 114, "shipit" => 57,
  "erubi-rails" => 10000, "blog" => 500, "writebook" => 500 }
clean = ->(text) {
  text.gsub(File.join(File.expand_path(base), "rails"), "RAILS")
    .gsub(File.join(File.expand_path(base), "ruby-bench"), "RUBY_BENCH")
    .gsub(File.join(root, ".corpus"), "CORPUS").gsub(ENV.fetch("HOME"), "$HOME")
}
rows = []
units.each do |app, default_per_op|
  %w[interpreter yjit].each do |mode|
    %w[callgrind perf].each do |counter|
      labels = app == "shipit" && counter == "callgrind" ? %w[a2 aa2] : %w[a aa]
      labels.each do |label|
        path = File.join(base, "#{app}-#{mode}-#{counter}-#{label}.json")
        next unless File.exist?(path)
        data = JSON.parse(File.read(path))
        layers = JSON.parse(File.read(path.sub(/\.json\z/, ".layers.json")))
        raise "unreconciled layers: #{path}" unless layers.fetch("exclusive").values.sum == layers.fetch("samples")
        per_op = %w[blog writebook].include?(app) && counter == "callgrind" ? 20 : default_per_op
        count = data.fetch("ops") * per_op
        delta = data["jit_delta"] || data.fetch("jit_before").to_h { |k, v| [k, data.fetch("jit_after").fetch(k) - v] }
        row = { app: app, mode: mode, counter: counter, label: label, unit: app == "erubi-rails" ? "render" : "request",
          units: count, ruby: data.fetch("ruby"), yjit: data.fetch("yjit"), jit_delta: delta,
          jit_flat: delta.values.all?(&:zero?), samples: layers.fetch("samples"),
          samples_per_unit: layers.fetch("samples").fdiv(count), lost_samples: layers["lost_samples"],
          exclusive_samples: layers.fetch("exclusive"), inclusive_samples: layers["inclusive"],
          inclusive_lower_bound: layers["inclusive_lower_bound"],
          top_leaves: layers.fetch("leaves").first(30).to_h.transform_keys { clean.call(_1) },
          source_sha256: Digest::SHA256.file(path).hexdigest,
          profile_sha256: Digest::SHA256.file(counter == "perf" ? "#{path}.perf" : "#{path}.stacks").hexdigest,
          heap_window_capacity_verified: false }
        if counter == "callgrind"
          row[:ir_per_unit] = data.fetch("window").fetch("work_ir").fdiv(count)
          row[:objects_per_unit] = data.fetch("objects", data["objects_per_op"]) / per_op.to_f
          row[:sampling] = data.fetch("window")
        else
          row[:objects_per_unit] = data.fetch("objects_per_op") / per_op.to_f
        end
        rows << row
      end
    end
  end
end
File.write(output, JSON.pretty_generate(rows) + "\n")
puts "Exported #{rows.size} windows; every exclusive partition reconciles"
