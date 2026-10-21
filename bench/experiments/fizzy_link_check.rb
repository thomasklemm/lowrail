# frozen_string_literal: true

# Untimed comparator. Reports rejections, never launches a measured cohort.
require_relative "fizzy_link_vector"

module FizzyLinkCheck
  module_function

  def cold(paths)
    raise "off/off/on required" unless paths.size == 3
    rows = paths.map { JSON.parse(File.read(_1)) }
    fields = %w[initial_effects steps sql events completed_effects completion loads features ancestry]
    compared = fields.to_h do |field|
      [field, {"off_off" => rows[0].fetch(field) == rows[1].fetch(field),
        "off_on" => rows[0].fetch(field) == rows[2].fetch(field)}]
    end
    controls = {
      "same_clean_harness" => rows.map { _1.fetch("pins") }.uniq.one?,
      "completed_cable_queue" => rows.all? { _1.dig("completion", "status") == "completed" },
      "no_capture_errors" => rows.all? { _1.fetch("errors").empty? },
      "no_undeclared_entropy" => rows.all? { !_1["entropy"] || _1.fetch("entropy").fetch("errors").empty? },
      "same_entropy_trace" => rows.map { _1.dig("entropy", "trace") }.uniq.one?
    }
    rejected_off = compared.any? { |_, facts| !facts.fetch("off_off") }
    status = if controls.values.any? { !_1 }
      "rejected_control"
    elsif rejected_off
      "rejected_off_control"
    elsif compared.any? { |_, facts| !facts.fetch("off_on") }
      "rejected_on_difference"
    else
      "equal_declared_fields"
    end
    previous = {}
    warm = rows.last.fetch("ledgers").map do |ledger|
      counts = ledger.fetch("specimen").fetch("counts")
      delta = counts.to_h { |site, values| [site, values.fetch("hits", 0) - previous.fetch(site, {}).fetch("hits", 0)] }
      previous = counts
      {"phase" => ledger.fetch("phase"), "completed_hits" => delta, "total" => delta.values.sum}
    end
    {"status" => status, "cohort_authorized" => false, "fields" => compared, "controls" => controls,
      "pins" => rows.map { _1.fetch("pins") }, "warm_hits" => warm,
      "sql_events" => rows.map { _1.fetch("sql").size },
      "cached_unavailable_binds" => rows.map { |row| row.fetch("sql").count { Hash === _1["binds"] && _1.dig("binds", "status") == "binds_unavailable" } },
      "compared_payload_fields" => rows.map { _1.fetch("compared_payload_fields") }.uniq,
      "uncovered" => rows.flat_map { _1.fetch("coverage_refusals") }.uniq +
        ["SolidCache background completion is outside the Cable/queue-only adapter; cache SQL/state remain compared, never discarded"],
      "raw_inputs" => paths.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}
  end

  def controls(directory)
    rows = Dir[File.join(directory, "*-on.json")].sort.map do |path|
      on = JSON.parse(File.read(path))
      off = JSON.parse(File.read(path.sub(/-on\.json\z/, "-off.json")))
      {"mode" => on.fetch("mode"), "same_outcomes" => off.fetch("ledgers").map { _1.fetch("outcome") } == on.fetch("ledgers").map { _1.fetch("outcome") },
        "checks" => {"off" => off.fetch("checks"), "on" => on.fetch("checks")},
        "pins" => [off.fetch("pins"), on.fetch("pins")],
        "outcome" => on.fetch("ledgers").last.fetch("outcome")}
    end
    {"pass" => rows.size == BlockLinkControls::MODES.size && rows.all? { |row| row.fetch("same_outcomes") && row.fetch("checks").values.all? { _1.values.all? } },
      "separate_bench_controls_not_Fizzy_coverage" => true, "rows" => rows}
  end
end

if $PROGRAM_NAME == __FILE__
  mode, destination, *paths = ARGV
  abort "usage: fizzy_link_check.rb cold DESTINATION OFF_A OFF_B ON | controls DESTINATION DIRECTORY" unless %w[cold controls].include?(mode)
  require_relative "block_link_controls" if mode == "controls"
  result = mode == "cold" ? FizzyLinkCheck.cold(paths) : FizzyLinkCheck.controls(paths.fetch(0))
  File.write(destination, JSON.pretty_generate(result), perm: 0o600)
  puts JSON.generate(result.slice("status", "pass", "controls", "fields"))
end
