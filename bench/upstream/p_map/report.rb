# frozen_string_literal: true

# P-MAP report: layer shares of request time from profile.rb receipts.
#   ruby report.rb layers RECEIPT.json...        per-app and per-workload layer table (markdown)
#   ruby report.rb aa A.json AA.json             largest layer-share drift between two runs of one app
#   ruby report.rb sites RECEIPT.json... [--top N] [--layer NAME]  hottest charged methods across receipts
#   ruby report.rb json OUT RECEIPT.json...      machine-readable shares
# Server time per workload window = Puma worker samples while running Ruby,
# plus worker samples blocked inside a request (database I/O with the GVL
# released), plus Puma's reactor and acceptor threads while running, plus GC
# (GC.total_time, which Vernier does not sample). Shares are of that total.
require "json"
require_relative "layers"

module PMapReport
  module_function

  def load(path)
    d = JSON.parse(File.read(path))
    # Newer receipts store stacks as frame indices into a shared frame table.
    if (frames = d.delete("frames"))
      d["stacks"].transform_values! { |ids| ids.map { frames[_1] } }
    end
    d["app_root"] = File.join(File.expand_path("../../../.corpus", __dir__), "")
    d
  end

  # { workload => { layer => ms } } plus totals.
  def attribute(d)
    interval_ms = d["interval_us"] / 1000.0
    stacks = d["stacks"]
    by = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    sites = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    d["threads"].each do |t|
      worker = t["name"].match?(/tp \d+\z/)
      puma = t["name"].match?(/\Apuma (srv|reactor)\z/)
      next unless worker || puma
      t["samples"].each do |stack, category, window, n|
        next if window.nil?
        frames = stacks.fetch(stack.to_s)
        ms = n * interval_ms
        layer = if puma
          next unless category == 0
          "Puma"
        elsif category == 0
          PMapLayers.layer(frames, d["app_root"])
        elsif category == 2
          next # waiting for the GVL (the in-process client holds it)
        elsif PMapLayers.in_request?(frames)
          "DB wait (GVL released)"
        else
          next # idle between requests
        end
        by[window][layer] += ms
        sites[window]["#{layer} | #{PMapLayers.site(frames)}"] += ms if category == 0
      end
    end
    d["windows"].each_with_index do |w, i|
      by[i]["GC"] += w["gc_ns"] / 1e6
    end
    [by, sites]
  end

  # Mean over workloads of each workload's layer share (every workload weighs
  # the same, whatever its latency), and per-request server ms.
  def shares(d)
    by, = attribute(d)
    rows = d["windows"].each_with_index.map do |w, i|
      total = by[i].values.sum
      { name: w["name"], kind: w["kind"], ms_per_request: total / w["requests"], wall_ms_per_request: (w["stop_ns"] - w["start_ns"]) / 1e6 / w["requests"],
        jit_ms_per_request: w.dig("jit", "compile_time_ns").to_f / 1e6 / w["requests"],
        allocated_per_request: w["allocated"].fdiv(w["requests"]),
        shares: by[i].transform_values { 100.0 * _1 / total } }
    end
    layers = rows.flat_map { _1[:shares].keys }.uniq
    mean = layers.to_h { |l| [l, rows.sum { _1[:shares].fetch(l, 0.0) } / rows.size] }
    { app: d["app"], rows: rows, mean: mean }
  end

  def order(layers)
    canon = ["Puma", "Rack", "Middleware", "Request/response", "Routing", "Controller", "Callbacks",
      "AR: query building", "AR: adapter (Ruby)", "AR: driver (C)", "DB wait (GVL released)", "AR: instantiate",
      "AR: attributes/casting", "AR: associations", "AR: write path", "AR: other", "AV: lookup", "AV: render",
      "AV: helpers", "AV: escaping", "App templates", "Serializers (gems)", "JSON", "i18n", "Logging/instrumentation",
      "Cache", "Time/TZ", "concurrent-ruby", "Digest/crypto", "Compression", "AS: other", "App code", "Other gems",
      "Ruby stdlib", "VM/cfunc only", "GC"]
    layers.sort_by { canon.index(_1) || canon.size }
  end

  def layers_table(paths)
    apps = paths.map { shares(load(_1)) }
    layers = order(apps.flat_map { _1[:mean].keys }.uniq)
    out = +"| Layer | #{apps.map { _1[:app] }.join(" | ")} | mean |\n|---|#{"---:|" * (apps.size + 1)}\n"
    layers.each do |l|
      vals = apps.map { _1[:mean].fetch(l, 0.0) }
      out << "| #{l} | #{vals.map { format("%.1f", _1) }.join(" | ")} | #{format("%.1f", vals.sum / vals.size)} |\n"
    end
    out << "\nPer workload (server ms per request, top layers):\n\n"
    apps.each do |a|
      a[:rows].each do |r|
        top = r[:shares].sort_by { -_2 }.first(4).map { |l, v| "#{l} #{v.round(1)}" }.join(", ")
        out << format("%-10s %-34s %7.2f ms (wall %6.2f, jit %.3f, %6.0f obj)  %s\n", a[:app], r[:name][0, 34],
          r[:ms_per_request], r[:wall_ms_per_request], r[:jit_ms_per_request], r[:allocated_per_request], top)
      end
    end
    out
  end

  def aa(a_path, b_path)
    a, b = shares(load(a_path)), shares(load(b_path))
    layers = order((a[:mean].keys | b[:mean].keys))
    drift = layers.map { |l| [l, a[:mean].fetch(l, 0.0), b[:mean].fetch(l, 0.0)] }
    puts "#{a[:app]}: A / AA layer share (mean over workloads)"
    drift.each { |l, x, y| puts format("  %-26s %6.2f %6.2f  %+5.2f pp", l, x, y, y - x) }
    worst = drift.max_by { (_3 - _2).abs }
    puts format("  largest drift: %s %+.2f pp", worst[0], worst[2] - worst[1])
    a[:rows].zip(b[:rows]).each do |x, y|
      puts format("  %-34s %7.2f -> %7.2f ms/request (%+.1f%%)", x[:name][0, 34], x[:ms_per_request], y[:ms_per_request],
        100.0 * (y[:ms_per_request] / x[:ms_per_request] - 1))
    end
  end

  # Inclusive share of every method whose label matches: a running worker
  # sample counts once for each matching method on its stack. Mean over all
  # workloads of the receipts, and the apps it reaches (share ≥ 0.1%).
  def inclusive(paths, pattern, top: 40)
    re = Regexp.new(pattern)
    totals = Hash.new(0.0)
    reach = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    n = 0
    paths.each do |path|
      d = load(path)
      by, = attribute(d)
      interval_ms = d["interval_us"] / 1000.0
      per = Hash.new { |h, k| h[k] = Hash.new(0.0) }
      d["threads"].each do |t|
        next unless t["name"].match?(/tp \d+\z/)
        t["samples"].each do |stack, category, window, cnt|
          next if window.nil? || category != 0
          d["stacks"].fetch(stack.to_s).map(&:first).uniq.each { per[window][_1] += cnt * interval_ms if _1.match?(re) }
        end
      end
      d["windows"].each_index do |i|
        total = by[i].values.sum
        n += 1
        per[i].each do |label, ms|
          totals[label] += 100.0 * ms / total
          reach[label][d["app"]] += 100.0 * ms / total / d["windows"].size
        end
      end
    end
    totals.sort_by { -_2 }.first(top).each do |k, v|
      apps = reach[k].select { _2 >= 0.1 }.map { |a, s| "#{a} #{s.round(2)}" }.join(", ")
      puts format("%6.2f  %-60s %s", v / n, k[0, 60], apps)
    end
  end

  # Methods charged in share points: each workload's share, averaged over all
  # workloads of the given receipts (apps weigh by their workload count).
  def sites(paths, top: 40, layer: nil, by_method: false)
    totals = Hash.new(0.0)
    reach = Hash.new { |h, k| h[k] = [] }
    n = 0
    paths.each do |path|
      d = load(path)
      by, sites = attribute(d)
      d["windows"].each_index do |i|
        total = by[i].values.sum
        n += 1
        sites[i].each do |k, ms|
          next if layer && !k.start_with?(layer)
          # Method level: the owner method without its line or leaf cfunc.
          k = k.sub(/\A(.*? \| )(?:.* ← )?(.*?) \((.*):\d+\)\z/, '\1\2 (\3)') if by_method
          totals[k] += 100.0 * ms / total
          reach[k] |= [d["app"]]
        end
      end
    end
    totals.sort_by { -_2 }.first(top).each { |k, v| puts format("%6.2f  %-24s %s", v / n, reach[k].join(","), k) }
  end
end

if $PROGRAM_NAME == __FILE__
  case ARGV.shift
  when "layers" then puts PMapReport.layers_table(ARGV)
  when "aa" then PMapReport.aa(*ARGV)
  when "sites"
    top = (i = ARGV.index("--top")) ? Integer(ARGV.slice!(i, 2)[1]) : 40
    layer = (i = ARGV.index("--layer")) ? ARGV.slice!(i, 2)[1] : nil
    by_method = !ARGV.delete("--by-method").nil?
    PMapReport.sites(ARGV, top: top, layer: layer, by_method: by_method)
  when "inclusive"
    top = (i = ARGV.index("--top")) ? Integer(ARGV.slice!(i, 2)[1]) : 40
    pattern = ARGV.shift
    PMapReport.inclusive(ARGV, pattern, top: top)
  when "json"
    out = ARGV.shift
    File.write(out, JSON.pretty_generate(ARGV.map { PMapReport.shares(PMapReport.load(_1)) }) + "\n")
  else abort "usage: report.rb layers|aa|sites|json ..."
  end
end
