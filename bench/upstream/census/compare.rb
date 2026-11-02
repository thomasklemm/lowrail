# frozen_string_literal: true

# Census deltas (census 4's census_4_compare.rb and census 5's per-app table,
# for any modes). Per app and mode: median GC-enabled objects per operation,
# LABEL - BASE, summarized as workloads moved by <= -1.0, median and min delta.
# The SQL control counts workloads whose masked SQL differs from BASE.
require "json"

module CensusCompare
  MODE = /-(interpreter|yjit|zjit)\.json\z/

  module_function

  def median(a) = a.sort[a.size / 2]

  def per_workload(root, label, file)
    JSON.parse(File.read(File.join(root, label, file)))["workloads"].to_h { [_1["workload"], _1] }
  end

  def files(root, base) = Dir[File.join(root, base, "*.json")].map { File.basename(_1) }.grep(MODE).sort

  # Same lines as census_4_compare.rb, then the SQL control per mode. BASE and
  # LABEL may be LABEL:MODE to compare modes (e.g. base2:interpreter base2:yjit).
  def report(root, base, labels, detail: false)
    out = []
    bdir, bmode = base.split(":", 2)
    labels.each do |label|
      out << "== #{label} vs #{base}"
      ldir, lmode = label.split(":", 2)
      all = Hash.new { |h, k| h[k] = [] }
      sql = Hash.new { |h, k| h[k] = [0, 0] }
      files(root, bdir).each do |file|
        fmode = file[MODE, 1]
        next if bmode && fmode != bmode
        other = lmode ? file.sub(MODE, "-#{lmode}.json") : file
        next unless File.exist?(File.join(root, ldir, other))
        b = per_workload(root, bdir, file)
        a = per_workload(root, ldir, other)
        deltas = b.keys.to_h { [_1, (median(a.fetch(_1)["gc_enabled_objects_per_op"]) - median(b.fetch(_1)["gc_enabled_objects_per_op"])).round(1)] }
        moved = deltas.count { _2 <= -1.0 }
        mode = lmode && lmode != fmode ? "#{fmode}>#{lmode}" : fmode
        all[mode].concat(deltas.values)
        b.each do |name, w|
          next unless w["sql"] && a[name]["sql"]
          sql[mode][0] += 1
          sql[mode][1] += 1 if w["sql"]["digest"] != a[name]["sql"]["digest"]
        end
        text = deltas.map { |w, d| "#{w} #{format("%+.1f", d)}" }.join("; ")
        out << format("%-30s moved %2d/%2d median %+6.1f min %+7.1f | %s", file.delete_suffix(".json"), moved, deltas.size,
          median(deltas.values), deltas.values.min, detail ? text : "")
      end
      all.each do |mode, d|
        out << format("ALL %-11s workloads %3d  median %+5.1f  moved<=-1: %3d  moved>=+1: %3d", mode, d.size, median(d),
          d.count { _1 <= -1.0 }, d.count { _1 >= 1.0 })
      end
      sql.each { |mode, (n, changed)| out << format("SQL %-11s workloads %3d  changed SQL: %3d", mode, n, changed) }
    end
    out.join("\n") + "\n"
  end

  # Markdown table of per-app medians, one column per comparison, modes joined
  # by " / " (census 5's table). columns: [[from, to], ...]; the first is A/A.
  def markdown(root, columns, names, modes)
    apps = files(root, columns.first.last).map { _1.sub(MODE, "") }.uniq.sort
    all = Hash.new { |h, k| h[k] = [] }
    fmt = ->(v) { format("%+.1f", v).sub("-", "−") }
    out = ["| App | #{names.join(" | ")} |", "| --- |#{" ---: |" * columns.size}"]
    apps.each do |app|
      cells = columns.map do |from, to|
        modes.map do |mode|
          file = "#{app}-#{mode}.json"
          next "–" unless [from, to].all? { File.exist?(File.join(root, _1, file)) }
          a = per_workload(root, from, file)
          b = per_workload(root, to, file)
          d = a.keys.map { (median(b.fetch(_1)["gc_enabled_objects_per_op"]) - median(a.fetch(_1)["gc_enabled_objects_per_op"])).round(1) }
          all[[from, to, mode]].concat(d)
          fmt.(median(d))
        end.join(" / ")
      end
      out << "| #{app} | #{cells.join(" | ")} |"
    end
    totals = columns.map { |c| modes.map { fmt.(median(all[[*c, _1]]) || 0) }.join(" / ") }
    out << "| **All workloads** | #{totals.map { "**#{_1}**" }.join(" | ")} |"
    moved = columns.map do |c|
      modes.map { |m| d = all[[*c, m]]; "#{d.count { _1 <= -1 }} / #{d.count { _1 >= 1 }}" }.join(" · ")
    end
    out << "| Moved ≤ −1 / ≥ +1 | #{moved.join(" | ")} |"
    out.join("\n") + "\n"
  end
end
