# frozen_string_literal: true

# Reports for docs/upstream/zjit-not-equal.md from run.sh output.
#   ruby report.rb count OUT_DIR/NAME.json [TOP]   generic `!=` sends per iteration: targets, top sites
#   ruby report.rb cg OUT_DIR/NAME.json            Ir per iteration: whole program and the `!=` region
require "json"

kind, path, top = ARGV
data = JSON.parse(File.read(path))
short = ->(s) { s.gsub(%r{/\S*?/(?:gems|benchmarks)/}, "") }
num = ->(v) { v.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }

if kind == "count"
  top = Integer(top || 8)
  stats = data.fetch("per_itr")
  # from, site, receiver class, target
  rows = data.fetch("rows").map { |key, n| [key.split("\t"), n] }
  sum = ->(list) { list.sum { _2 } }
  puts "#{File.basename(path, ".json")}: #{data["ruby"]}"
  puts "all sends #{num.(stats["send_count"])}, dynamic sends #{num.(stats["dynamic_send_count"])}, " \
       "send_polymorphic #{num.(stats["send_fallback_send_polymorphic"])}, " \
       "send_polymorphic_fallback #{num.(stats["send_fallback_send_polymorphic_fallback"])}, " \
       "send_megamorphic #{num.(stats["send_fallback_send_megamorphic"])}"
  rows.group_by { [_1[0][0], _1[0][3]] }.each do |(from, target), list|
    puts "generic != from #{from} to #{target}: #{num.(sum.(list))} per iteration"
    sites = list.group_by { _1[0][1] }
    by_classes = sites.group_by { |_, l| l.size }.transform_values { |s| s.sum { |_, l| sum.(l) } }.sort
    puts "  by receiver classes seen at the site: #{by_classes.map { |k, n| "#{k}: #{num.(n)}" }.join(", ")}"
    sites.sort_by { |_, l| -sum.(l) }.first(top).each do |site, l|
      classes = l.sort_by { -_2 }.map { |f, n| "#{f[2]} #{num.(n)}" }
      puts "  #{num.(sum.(l)).rjust(7)}  #{short.(site)}  (#{classes.first(4).join(", ")}#{", ..." if classes.size > 4})"
    end
  end
else
  base = path.sub(/\.json\z/, ".cg")
  totals = Dir["#{base}.*"].to_h { [_1[/\d+\z/].to_i, File.foreach(_1).grep(/\Atotals:/).first.split[1].to_i] }
  k = data.fetch("itrs")
  whole = nil
  puts "#{File.basename(path, ".json")}: JIT-flat #{data["jit_flat"]}, #{k} iterations per window"
  data.fetch("windows").each_with_index do |w, i|
    ir = totals.fetch(i + 2) - (w["region"] ? 0 : totals.fetch(1))
    whole ||= ir
    share = w["region"] ? format(" %.3f%%", 100.0 * ir / whole) : ""
    regions = w["region"] ? format(", %s regions/itr, %.0f Ir each, %d left by a jump", num.(w["regions"].fdiv(k)), w["regions"].zero? ? 0 : ir.fdiv(w["regions"]), w["left_by_jump"]) : ""
    puts format("  %-28s %15s Ir/itr%s%s, %d GCs%s", w["region"] ? "generic != to BasicObject#!=" : "whole program", num.(ir.fdiv(k)), share, regions, w["gcs"], w["jit_unchanged"] ? "" : ", JIT CHANGED")
  end
end
