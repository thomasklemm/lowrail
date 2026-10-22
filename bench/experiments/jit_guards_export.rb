# frozen_string_literal: true

# Compact already-published receipts, never measurements. The immutable original
# remains recoverable with git show; keep all decision/counter/window records.
require "json"
require "digest"
require_relative "ar_request_sites_db"

module JitGuardsExport
  module_function

  def digest(value) = Digest::SHA256.hexdigest(JSON.generate(value))

  def compact(value, inventories)
    case value
    when Hash
      value.to_h do |key, item|
        case key
        when "trace", "clock_reads", "wall_clock_reads"
          [key, {"count" => item.size, "sha256" => digest(item), "omitted" => "entropy trace; see original export"}]
        when "workflow"
          [key, JSON.generate(item).bytesize > 2048 ? {"sha256" => digest(item), "omitted" => "workflow detail; see original export"} : item]
        when "pins", "input_pins"
          next [key, item] unless item.is_a?(Hash)
          generated, retained = item.partition { |path, _| path.include?("/generated/") }.map(&:to_h)
          [key, compact(retained, inventories).merge("omitted_generated_catalog" => {
            "count" => generated.size, "sha256" => digest(generated.sort), "recovery" => "original export"})]
        when "inventory"
          hash = digest(item)
          inventories[hash] = item
          ["inventory_sha256", hash]
        else
          [key, compact(item, inventories)]
        end
      end
    when Array
      value.map { compact(_1, inventories) }
    when String
      value.gsub("/home/user/workspace/repo", "$REPO").gsub("/tmp/lowrail-y", "$SCRATCH")
        .gsub("/home/user/.local/share/mise/installs/ruby/4.0.7", "$RUBY_HOME")
    else
      value
    end
  end

  def publish(path, original_commit)
    bytes = File.read(path)
    source = JSON.parse(bytes)
    raise "already compacted" if source.key?("original_export")
    inventories = {}
    result = compact(source, inventories)
    result["format"] = 2
    result["original_export"] = {"commit" => original_commit, "path" => path,
      "sha256" => Digest::SHA256.hexdigest(bytes), "recovery" => "git show COMMIT:PATH",
      "pins_scope" => "historical measuring runtime, never current branch HEAD"}
    result["inventories"] = inventories unless inventories.empty?
    if result.key?("interpreter")
      result["measurement_commits"] = {"interpreter" => source.fetch("interpreter").fetch("protocol").fetch("source_sha"),
        "rps" => source.fetch("rps").fetch("measured_source")}
    end
    File.write(path, JSON.pretty_generate(result) + "\n")
  end

  # Preserve the collector schema; omit only private/verbose captures. The raw
  # receipt is deliberately private because it contains SQL bind values.
  def publish_control(input, output)
    bytes = File.read(input)
    report = JSON.parse(bytes)
    report.fetch("workers").each_value do |worker|
      worker.fetch("cases").each_value do |seeds|
        seeds.each_value do |row|
          row.delete("sql_trace")
          row.delete("sql_capture")
          row.fetch("db_audit").fetch("columns").select! { |column, _| DirectSiteDB::EXCLUSIONS.key?(column) }
        end
      end
    end
    inventories = {}
    result = compact(report, inventories)
    result.merge!("format" => 2, "inventories" => inventories,
      "scope" => "public projection of unified collector; no timing; raw DB and response/SQL gates remain separate",
      "replay_receipt_sha256" => Digest::SHA256.hexdigest(bytes),
      "raw_receipt_recovery" => "private: contains SQL and bind values; public projection is the durable receipt",
      "omitted_fields" => ["sql_trace", "sql_capture", "db_audit.columns except declared exclusion"])
    File.write(output, JSON.pretty_generate(result) + "\n")
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "control"
    abort "usage: jit_guards_export.rb control PRIVATE_RECEIPT PUBLIC_EXPORT" unless ARGV.size == 3
    JitGuardsExport.publish_control(ARGV[1], ARGV[2])
  else
    commit, *paths = ARGV
    abort "usage: jit_guards_export.rb ORIGINAL_EXPORT_COMMIT EXPORT..." if paths.empty?
    paths.each { JitGuardsExport.publish(_1, commit) }
  end
end
