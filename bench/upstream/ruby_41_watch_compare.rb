# frozen_string_literal: true

# Ruby 4.1 regression watch: compare census 4 runs between two Rubies, with
# an A/A pair on each side.
#   ruby SCRIPT ROOT OLD_A OLD_B NEW_A NEW_B MODE [NEW_MODE] [--sites N] [--tsv]
# Workloads: median GC-enabled objects per operation, and traced bytes per
# operation (ObjectSpace.memsize_of at the end of the traced window, so
# out-of-slot storage counts). Noise is the larger A/A delta of the two Rubies.
# Sites: mean objects and bytes per operation over every workload, grouped by
# source line, then by file, so a moved line does not read as a new site.
require "json"

root, old_a, old_b, new_a, new_b, mode, new_mode = ARGV.reject { _1.start_with?("--") || _1 =~ /\A\d+\z/ }
new_mode ||= mode
limit = Integer(ARGV[ARGV.index("--sites") + 1]) if ARGV.include?("--sites")
limit ||= 25
median = ->(a) { a.sort[a.size / 2] }

load_label = lambda do |label, m|
  Dir[File.join(root, label, "*-#{m}.json")].sort.flat_map do |file|
    run = JSON.parse(File.read(file))
    run["workloads"].map do |w|
      [[run["app"], w["workload"]], {
        objects: median.(w["gc_enabled_objects_per_op"]),
        bytes: w["enumerated_bytes"].to_f / w["ops"],
        gc: w["gc_windows"]&.sum { _1["count"] }.to_i,
        sites: w["sites"] }]
    end
  end.to_h
end

runs = { oa: load_label.(old_a, mode), ob: load_label.(old_b, mode), na: load_label.(new_a, new_mode), nb: load_label.(new_b, new_mode) }
keys = runs.values.map(&:keys).reduce(:&)
abort "no common workloads" if keys.empty?

puts "== workloads (#{keys.size}) #{old_a}/#{old_b} #{mode} -> #{new_a}/#{new_b} #{new_mode}"
rows = keys.map do |key|
  o = runs[:oa][key]; o2 = runs[:ob][key]; n = runs[:na][key]; n2 = runs[:nb][key]
  d_obj = ((n[:objects] + n2[:objects]) - (o[:objects] + o2[:objects])) / 2.0
  noise_obj = [(o2[:objects] - o[:objects]).abs, (n2[:objects] - n[:objects]).abs].max
  d_bytes = ((n[:bytes] + n2[:bytes]) - (o[:bytes] + o2[:bytes])) / 2.0
  noise_bytes = [(o2[:bytes] - o[:bytes]).abs, (n2[:bytes] - n[:bytes]).abs].max
  { key: key, old: (o[:objects] + o2[:objects]) / 2.0, d_obj: d_obj, noise_obj: noise_obj,
    old_bytes: (o[:bytes] + o2[:bytes]) / 2.0, d_bytes: d_bytes, noise_bytes: noise_bytes,
    gc_old: o[:gc] + o2[:gc], gc_new: n[:gc] + n2[:gc] }
end
real = ->(d, noise, floor) { d.abs >= floor && d.abs > 2 * noise }
rows.sort_by { -_1[:d_obj] }.each do |r|
  flag = real.(r[:d_obj], r[:noise_obj], 2.0) ? (r[:d_obj].positive? ? "MORE" : "LESS") : ""
  bflag = real.(r[:d_bytes], r[:noise_bytes], 1024.0) ? (r[:d_bytes].positive? ? "BYTES+" : "BYTES-") : ""
  puts format("%-6s %-6s %-48s objs %8.1f %+8.1f (aa %5.1f, %+6.2f%%)  bytes %9.0f %+8.0f (aa %6.0f, %+6.2f%%)  gc %d->%d",
    flag, bflag, r[:key].join(" ")[0, 48], r[:old], r[:d_obj], r[:noise_obj], 100 * r[:d_obj] / r[:old],
    r[:old_bytes], r[:d_bytes], r[:noise_bytes], 100 * r[:d_bytes] / r[:old_bytes], r[:gc_old], r[:gc_new])
end
d = rows.map { _1[:d_obj] }
db = rows.map { _1[:d_bytes] }
puts format("ALL objects: median %+.1f, mean %+.2f%%, real more %d, real less %d | bytes: median %+.0f, mean %+.2f%%, more %d, less %d",
  median.(d), 100 * d.sum / rows.sum { _1[:old] }, rows.count { real.(_1[:d_obj], _1[:noise_obj], 2.0) && _1[:d_obj] > 0 },
  rows.count { real.(_1[:d_obj], _1[:noise_obj], 2.0) && _1[:d_obj] < 0 }, median.(db), 100 * db.sum / rows.sum { _1[:old_bytes] },
  rows.count { real.(_1[:d_bytes], _1[:noise_bytes], 1024.0) && _1[:d_bytes] > 0 },
  rows.count { real.(_1[:d_bytes], _1[:noise_bytes], 1024.0) && _1[:d_bytes] < 0 })

# Sites, averaged over the A/B runs of each Ruby, mean per workload.
site_totals = lambda do |a, b, group|
  t = Hash.new { |h, k| h[k] = [0.0, 0.0, Hash.new(0.0)] }
  [a, b].each do |run|
    keys.each do |key|
      run[key][:sites].each do |s|
        # Gem paths carry the Ruby ABI directory (4.0.0 vs 4.1.0+N).
        file = s["file"].sub(%r{\AGEM/[^/]+/(bundler/)?gems/}, "GEM/")
        k = group == :line ? "#{file}:#{s["line"]}" : file
        t[k][0] += s["objects_per_op"] / 2.0 / keys.size
        t[k][1] += s["bytes_per_op"].to_f / 2.0 / keys.size
        t[k][2][s["class"]] += s["objects_per_op"]
      end
    end
  end
  t
end
%i[line file].each do |group|
  old_t = site_totals.(runs[:oa], runs[:ob], group)
  new_t = site_totals.(runs[:na], runs[:nb], group)
  aa_o = site_totals.(runs[:oa], runs[:oa], group)
  aa_o2 = site_totals.(runs[:ob], runs[:ob], group)
  all = (old_t.keys | new_t.keys).map do |k|
    o = old_t.fetch(k, [0.0, 0.0, {}]); n = new_t.fetch(k, [0.0, 0.0, {}])
    noise = (aa_o.fetch(k, [0.0])[0] - aa_o2.fetch(k, [0.0])[0]).abs
    classes = (n[2].empty? ? o[2] : n[2]).sort_by { -_2 }.first(2).map(&:first).join(",")
    [k, o[0], n[0] - o[0], o[1], n[1] - o[1], noise, classes]
  end
  puts "== sites by #{group}: mean objects/bytes per workload, new - old (top #{limit} each way)"
  [all.sort_by { -_1[2] }.first(limit), all.sort_by { _1[2] }.first(limit)].each do |list|
    list.each do |k, o, dlt, ob, dbt, noise, cls|
      puts format("  %+8.2f obj (old %8.2f, aa %5.2f)  %+9.0f B (old %9.0f)  %-70s %s", dlt, o, noise, dbt, ob, k[0, 70], cls)
    end
    puts "  --"
  end
  puts "== sites by #{group}: largest byte growth"
  all.sort_by { -_1[4] }.first(limit).each do |k, o, dlt, ob, dbt, _noise, cls|
    puts format("  %+9.0f B (old %9.0f)  %+8.2f obj  %-70s %s", dbt, ob, dlt, k[0, 70], cls)
  end
end
