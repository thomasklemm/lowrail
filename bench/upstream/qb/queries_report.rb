# frozen_string_literal: true

# QB1: summary of queries.rb receipts.
#   ruby queries_report.rb RECEIPT.json...           markdown tables
#   ruby queries_report.rb --shapes N RECEIPT.json   the N most frequent uncached shapes per app
# Per request means the mean over a workload's measured requests; app columns
# are the mean over its workloads, so every workload weighs the same.
require "json"

module QBQueries
  module_function

  def load(path) = JSON.parse(File.read(path))

  def per_request(d)
    d["workloads"].map do |w|
      n = w["requests"].size
      qs = w["requests"].flat_map { _1["queries"] }
      { name: w["name"], n: n, queries: qs, counts: w["requests"].map { _1["counts"] } }
    end
  end

  def group(origin)
    case origin
    when /\Aassociation reader \(/ then "association reader, skips cache"
    when "association reader" then "association reader, cached"
    when /\Arelation (find|find_by|find_by!|first|last|take)\z/ then "relation finder (scoped find/find_by/first)"
    when /\Acalc / then "count/exists?/pluck"
    when /\Arelation load/ then origin
    when /\Aother/ then "other"
    else origin
    end
  end

  def mean_table(title, apps, &key)
    names = apps.map { _1["app"] + (_1["set"] == "ce2" ? " (CE2)" : "") }
    rows = Hash.new { |h, k| h[k] = Array.new(apps.size, 0.0) }
    apps.each_with_index do |d, i|
      ws = per_request(d)
      ws.each do |w|
        w[:queries].each { |q| k = key.call(q) and rows[k][i] += 1.0 / w[:n] / ws.size }
      end
    end
    out = +"#{title}\n\n| | #{names.join(" | ")} |\n|---|#{"---:|" * names.size}\n"
    rows.sort_by { -_2.sum }.each { |k, v| out << "| #{k} | #{v.map { format("%.1f", _1) }.join(" | ")} |\n" }
    tot = apps.each_with_index.map { |_, i| rows.values.sum { _1[i] } }
    out << "| **total** | #{tot.map { format("%.1f", _1) }.join(" | ")} |\n\n"
  end

  # Reads built per query (not statement cache), over each workload's last
  # request: is the shape identical in the next request (always, for a
  # repeated page), repeated inside the request with other binds, shared with
  # another workload of the app, and served by the query cache anyway.
  def repeat_table(apps)
    out = +"Repetition of reads built per query (share of those queries)\n\n| | built reads/request | shape repeats on the next request | shape repeats within the request | binds differ within the request | shape also on another page | query cache hit |\n|---|---:|---:|---:|---:|---:|---:|\n"
    apps.each do |d|
      ws = d["workloads"].map { |w| [w["name"], w["requests"][-1]["queries"], w["requests"][-2]["queries"]] }
      built = ->(qs) { qs.reject { _1["origin"] == "write" || _1["path"] == "statement_cache" } }
      pages = Hash.new { |h, k| h[k] = {} }
      ws.each { |name, qs, _| built.(qs).each { pages[_1["shape"]][name] = true } }
      tot = within = differ = shared = cached = nextreq = 0
      ws.each do |name, qs, prev|
        b = built.(qs)
        prev_shapes = built.(prev).map { _1["shape"] }.tally
        by = b.group_by { _1["shape"] }
        b.each do |q|
          tot += 1
          nextreq += 1 if prev_shapes[q["shape"]]
          within += 1 if by[q["shape"]].size > 1
          differ += 1 if by[q["shape"]].map { _1["binds"] }.uniq.size > 1 || by[q["shape"]].map { _1["sql"] }.uniq.size > 1
          shared += 1 if pages[q["shape"]].size > 1
          cached += 1 if q["cached"]
        end
      end
      pct = ->(x) { tot.zero? ? 0 : 100.0 * x / tot }
      out << format("| %s | %.1f | %.0f%% | %.0f%% | %.0f%% | %.0f%% | %.0f%% |\n", d["app"] + (d["set"] == "ce2" ? " (CE2)" : ""),
        tot.fdiv(ws.size), pct.(nextreq), pct.(within), pct.(differ), pct.(shared), pct.(cached))
    end
    out << "\n"
  end

  def counters_table(apps)
    keys = %w[relation_copy merge where_hash exec_scope build_arel compile_arel find_target association_scope]
    out = +"Work per request (mean over workloads)\n\n| | #{keys.join(" | ")} |\n|---|#{"---:|" * keys.size}\n"
    apps.each do |d|
      ws = per_request(d)
      vals = keys.map { |k| ws.sum { |w| w[:counts].sum { _1.fetch(k, 0) }.fdiv(w[:n]) } / ws.size }
      out << "| #{d["app"]}#{" (CE2)" if d["set"] == "ce2"} | #{vals.map { format("%.1f", _1) }.join(" | ")} |\n"
    end
    out << "\n"
  end

  def shapes(d, top)
    ws = per_request(d)
    tally = Hash.new { |h, k| h[k] = { n: 0.0, origins: Hash.new(0), assoc: Hash.new(0), scopes: Hash.new(0) } }
    ws.each do |w|
      w[:queries].each do |q|
        next if q["path"] == "statement_cache" || q["origin"] == "write"
        t = tally[q["shape"]]
        t[:n] += 1.0 / w[:n]
        t[:origins][q["origin"]] += 1
        t[:assoc][q["assoc"]] += 1 if q["assoc"]
        Array(q["scopes"]).each { |s| t[:scopes][s[1].to_s.sub(%r{.*/\.corpus/[^/]+/}, "")] += 1 }
      end
    end
    tally.sort_by { -_2[:n] }.first(top).map do |shape, t|
      format("%5.1f/req  %s%s%s\n           %s", t[:n], t[:origins].max_by(&:last)&.first,
        t[:assoc].empty? ? "" : " #{t[:assoc].max_by(&:last).first}", t[:scopes].empty? ? "" : " scope #{t[:scopes].keys.first(2).join(",")}",
        shape[0, 220])
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if (i = ARGV.index("--shapes"))
    top = Integer(ARGV.delete_at(i + 1)); ARGV.delete_at(i)
    ARGV.each { |p| d = QBQueries.load(p); puts "== #{d["app"]} #{d["set"]}"; puts QBQueries.shapes(d, top) }
  else
    apps = ARGV.map { QBQueries.load(_1) }
    puts QBQueries.mean_table("Queries per request by path", apps) { _1["path"] }
    puts QBQueries.mean_table("Queries per request by origin (reads)", apps) { _1["origin"] == "write" ? nil : QBQueries.group(_1["origin"]) }
    puts QBQueries.mean_table("Association readers that skip the statement cache, by reason", apps) { _1["origin"][/\Aassociation reader \((.*)\)\z/, 1] }
    puts QBQueries.mean_table("Writes per request by path", apps) { _1["origin"] == "write" ? _1["path"] : nil }
    puts QBQueries.repeat_table(apps)
    puts QBQueries.counters_table(apps)
  end
end
