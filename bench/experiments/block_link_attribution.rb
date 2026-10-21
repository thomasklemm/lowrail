# frozen_string_literal: true

# Offline analysis of EXISTING dumps only. Never boots an app or starts a
# counter. Native self costs cannot recover interpreted Ruby methods/sites.
require "json"
require "digest"

module BlockLinkAttribution
  module_function

  def self_costs(path)
    functions, objects = {}, {}
    costs = Hash.new(0)
    object = function = nil
    inclusive = false
    total = nil
    resolve = lambda do |table, value|
      if (match = /\A\((\d+)\)(?: (.*))?\z/.match(value))
        table[match[1]] = match[2] if match[2]
        table.fetch(match[1])
      else
        value
      end
    end
    File.foreach(path, chomp: true) do |line|
      case line
      when /\Aevents: (.*)/ then raise "Ir-only dump required" unless Regexp.last_match(1) == "Ir"
      when /\Apositions: (.*)/ then raise "line-only positions required" unless Regexp.last_match(1) == "line"
      when /\A(ob|cob)=(.*)/
        kind, value = Regexp.last_match(1), Regexp.last_match(2)
        name = resolve.call(objects, value)
        object = name if kind == "ob"
      when /\A(fn|cfn)=(.*)/
        kind, value = Regexp.last_match(1), Regexp.last_match(2)
        name = resolve.call(functions, value)
        # Callgrind recursion clones are contexts, not different C functions.
        function = name.sub(/'\d+\z/, "") if kind == "fn"
      when /\Acalls=/ then inclusive = true
      when /\Atotals: (\d+)\z/ then total = Integer(Regexp.last_match(1))
      when /\A(?:[+-]?\d+|\*) (\d+)\s*\z/
        if inclusive
          inclusive = false
        else
          raise "cost outside a function" unless object && function
          costs[[object, function]] += Integer(Regexp.last_match(1))
        end
      end
    end
    raise "self costs do not reconcile: #{path}" unless total && !inclusive && costs.values.sum == total
    [costs, total]
  end

  def report(export, raw)
    workers = export.fetch("workers")
    dumps = export.fetch("dumps")
    audits = {}
    parsed = dumps.to_h do |name, expected|
      path = File.join(raw, name)
      raise "dump pin changed: #{name}" unless Digest::SHA256.file(path).hexdigest == expected.fetch("sha256")
      costs, total = self_costs(path)
      raise "export total changed" unless total == expected.fetch("self_Ir")
      audits[name] = total
      [name, costs]
    end
    modes = %w[total no_gc].to_h do |mode|
      by_arm = %w[off_a off_b on].to_h do |arm|
        sum = Hash.new(0)
        6.times do |round|
          key = "#{round}-#{arm}"
          windows = workers.fetch(key).fetch("windows")
          indices = windows.each_index.select { windows[_1].fetch("mode") == mode }
          raise "N0/N10 pair required" unless indices.map { windows[_1].fetch("requests") }.sort == [0, 10]
          indices.each do |index|
            window = windows.fetch(index)
            name = "#{key}.callgrind.#{index + 1}"
            raise "window mismatch" unless audits.fetch(name) == window.fetch("instructions")
            sign = window.fetch("requests").zero? ? -1 : 1
            parsed.fetch(name).each { |function, cost| sum[function] += sign * cost }
          end
        end
        [arm, sum]
      end
      keys = by_arm.values.flat_map(&:keys).uniq
      rows = keys.map do |object, function|
        key = [object, function]
        {"object" => File.basename(object), "function" => function,
          "off_a_Ir" => by_arm.fetch("off_a")[key] / 60.0,
          "off_b_Ir" => by_arm.fetch("off_b")[key] / 60.0,
          "on_Ir" => by_arm.fetch("on")[key] / 60.0,
          "on_minus_off_a_Ir" => (by_arm.fetch("on")[key] - by_arm.fetch("off_a")[key]) / 60.0,
          "off_b_minus_off_a_Ir" => (by_arm.fetch("off_b")[key] - by_arm.fetch("off_a")[key]) / 60.0}
      end.sort_by { -_1.fetch("on_minus_off_a_Ir").abs }
      delta = rows.sum { _1.fetch("on_minus_off_a_Ir") }
      expected = export.fetch("per_round").sum { _1.fetch("on").fetch("instructions_#{mode}") - _1.fetch("off_a").fetch("instructions_#{mode}") } / 6
      raise "decomposition mismatch" unless (delta - expected).abs < 0.001
      control = rows.sum { _1.fetch("off_b_minus_off_a_Ir") }
      expected_control = export.fetch("per_round").sum { _1.fetch("off_b").fetch("instructions_#{mode}") - _1.fetch("off_a").fetch("instructions_#{mode}") } / 6
      raise "A/A decomposition mismatch" unless (control - expected_control).abs < 0.001
      changed = rows.reject { _1.fetch("on_minus_off_a_Ir").zero? && _1.fetch("off_b_minus_off_a_Ir").zero? }
      [mode, {"net_Ir_per_vector" => delta, "off_b_minus_off_a_Ir_per_vector" => control,
        "unchanged_functions_omitted" => rows.size - changed.size,
        "native_functions" => changed}]
    end
    hits = export.fetch("preregistered").fetch("expected_hits_per_iteration")
    {"format" => 1, "scope" => "offline native self-cost decomposition; not a new cohort, causal profile or per-site price",
      "normalization" => "sum of six rounds' N10-minus-N0 self costs, divided by 60 vectors; arithmetic mean, not published paired-ratio median",
      "per_site_Ir_unavailable_reason" => "interpreted Ruby methods and ERB/block sites have no distinct symbols in these native dumps",
      "per_site" => hits.map { |site, count| {"site" => site, "hits_per_vector" => count,
        "hits_per_N10_window" => count * 10,
        "saved_Ir" => count.zero? ? 0 : nil, "added_Ir" => count.zero? ? 0 : nil} },
      "dump_count" => audits.size, "modes" => modes}
  end
end

if $PROGRAM_NAME == __FILE__
  export, raw, output = ARGV
  abort "usage: block_link_attribution.rb N10_EXPORT_JSON RAW_DUMP_DIR NEW_JSON" unless output
  raise "new output required" if File.exist?(output)
  report = BlockLinkAttribution.report(JSON.parse(File.read(export)), raw)
  report["input_export_sha256"] = Digest::SHA256.file(export).hexdigest
  report["analyzer_sha256"] = Digest::SHA256.file(__FILE__).hexdigest
  File.write(output, JSON.pretty_generate(report) + "\n")
  puts "reconciled #{report.fetch('dump_count')} dumps; total net #{report.dig('modes', 'total', 'net_Ir_per_vector')} Ir/vector"
end
