# frozen_string_literal: true

# Reports for docs/upstream/zjit-symbol-block.md from zs1_run.sh output.
#   ruby zs1_report.rb count OUT_DIR/NAME.json [TOP]   Symbol block sends and yields per iteration, by type, top sites
#   ruby zs1_report.rb cg OUT_DIR/NAME.json            Ir per iteration: whole program and each region mask
require "json"

kind, path, top = ARGV
data = JSON.parse(File.read(path))
short = ->(s) { s.gsub(%r{/\S*?/(?:gems|benchmarks|rails-vb1|rails-main)/}, "") }
num = ->(v) { v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }

if kind == "count"
  top = Integer(top || 8)
  stats = data.fetch("per_itr")
  sends, yields = data.fetch("rows").map { |key, n| [key.split("\t"), n] }.partition { _1[0][0] == "send" }
  # send:  _, arg|fwd, send|super, callee type, callee, definition, symbol, site, jit|interp
  # yield: _, iseq|cfunc|proc|other, yielder, target type, target, definition, symbol, site, at, jit|interp|-
  sum = ->(rows) { rows.sum { _2 } }
  by = ->(rows, &key) { rows.group_by { key.(_1[0]) }.transform_values(&sum).sort_by { -_2 } }
  puts "#{File.basename(path, ".json")}: #{data["ruby"]}"
  puts "all sends #{num.(stats["send_count"] || 0)}, dynamic sends #{num.(stats["dynamic_send_count"] || 0)}, " \
       "send_block_arg_not_nil #{num.(stats["send_fallback_send_block_arg_not_nil"] || 0)}, " \
       "rb_vm_invokeblock calls #{num.(stats["ccall_rb_vm_invokeblock"] || 0)}"
  puts "Symbol block sends #{num.(sum.(sends))} (#{by.(sends) { _1[1] }.map { "#{_1} #{num.(_2)}" }.join(", ")}; " \
       "#{by.(sends) { _1[8] }.map { "#{_1} #{num.(_2)}" }.join(", ")})"
  by.(sends) { [_1[1], _1[3]] }.each { |(how, type), n| puts "  #{how} #{type}: #{num.(n)}" }
  puts "Symbol handler yields #{num.(sum.(yields))}"
  by.(yields) { [_1[1], _1[2].split.first, _1[9]] }.each { |(k, yielder, jit), n| puts "  #{k} from #{yielder} (#{jit}): #{num.(n)}" }
  puts "  target types: #{by.(yields) { _1[3] }.map { "#{_1} #{num.(_2)}" }.join(", ")}"
  groups = {
    "sends, ISEQ callee" => sends.select { _1[0][3].start_with?("ISEQ") },
    "sends, other callee" => sends.reject { _1[0][3].start_with?("ISEQ") },
    "yields from a Ruby yield" => yields.select { _1[0][1] == "iseq" },
    "yields from C" => yields.reject { _1[0][1] == "iseq" }
  }
  groups.each do |title, rows|
    puts "top #{title} (#{num.(sum.(rows))}):"
    merged = rows.group_by { |f, _| f[0] == "send" ? [f[4], f[6], f[7]] : [f[2], f[4], f[6], f[7]] }.transform_values(&sum)
    merged.sort_by { -_2 }.first(top).each do |f, n|
      line = f.size == 3 ? "#{f[0]}(&:#{f[1]}) at #{f[2]}" : "#{f[0]} -> #{f[1]} (&:#{f[2]}) from #{f[3]}"
      puts "  #{num.(n).rjust(7)}  #{short.(line)}"
    end
  end
else
  base = path.sub(/\.json\z/, ".cg")
  totals = Dir["#{base}.*"].to_h { [_1[/\d+\z/].to_i, File.foreach(_1).grep(/\Atotals:/).first.split[1].to_i] }
  k = data.fetch("itrs")
  names = {0 => "whole program", 1 => "send, ISEQ callee", 2 => "send, other callee", 4 => "yield, invokeblock", 8 => "yield, from C"}
  whole = nil
  puts "#{File.basename(path, ".json")}: JIT-flat #{data["jit_flat"]}, #{k} iterations per window"
  data.fetch("windows").each_with_index do |w, i|
    ir = totals.fetch(i + 2) - (w["mask"].zero? ? totals.fetch(1) : 0)
    whole ||= ir
    share = w["mask"].zero? ? "" : format(" %.3f%%", 100.0 * ir / whole)
    regions = w["mask"].zero? ? "" : format(", %s regions/itr, %.0f Ir each, %d left by a jump", num.(w["regions"].fdiv(k)), w["regions"].zero? ? 0 : ir.fdiv(w["regions"]), w["left_by_jump"])
    puts format("  %-20s %15s Ir/itr%s%s, %d GCs%s", names.fetch(w["mask"]), num.(ir.fdiv(k)), share, regions, w["gcs"], w["jit_unchanged"] ? "" : ", JIT CHANGED")
  end
end
