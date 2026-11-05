# Summarize harness_gcsplit.rb output: per benchmark, mode and variant, candidate GC metrics over the
# measured iterations, and each variant's difference from base-a in the same round.
# usage: ruby summarize.rb DIR [--per-round]
require "json"

dir = ARGV.fetch(0)
per_round = ARGV.include?("--per-round")

def mean(a) = a.empty? ? nil : a.sum.to_f / a.size
def median(a) = a.empty? ? nil : a.sort[a.size / 2]

# Least-squares fit of per-iteration GC ms on minor and major counts (no intercept).
def fit(rows)
  s11 = s12 = s22 = t1 = t2 = 0.0
  rows.each do |r|
    x1, x2, y = r["minor"], r["major"], r["gc_ns"] / 1e6
    s11 += x1 * x1; s12 += x1 * x2; s22 += x2 * x2; t1 += x1 * y; t2 += x2 * y
  end
  det = s11 * s22 - s12 * s12
  return [nil, nil] if det.abs < 1e-9
  [(t1 * s22 - t2 * s12) / det, (s11 * t2 - s12 * t1) / det]
end

def metrics(d)
  rows = d["itrs"][d["warmup"]..]
  colls = rows.flat_map { |r| r["colls"] || [] }
  minor = colls.select { |c| c[0] == 0 }
  major = colls.select { |c| c[0] == 1 }
  wall = mean(rows.map { |r| r["wall"] * 1000 })
  gc = mean(rows.map { |r| r["gc_ns"] / 1e6 })
  fa, fb = fit(rows)
  {
    "wall ms/itr" => wall,
    "GC ms/itr" => gc,
    "wall-GC ms/itr" => wall - gc,
    "minor/itr" => mean(rows.map { |r| r["minor"] }),
    "major/itr" => mean(rows.map { |r| r["major"] }),
    "ms/minor (prof)" => mean(minor.map { |c| c[1] * 1000 }),
    "ms/major (prof)" => mean(major.map { |c| c[1] * 1000 }),
    "mark ms/minor" => mean(minor.map { |c| c[2].to_f * 1000 }),
    "mark ms/major" => mean(major.map { |c| c[2].to_f * 1000 }),
    "median mark ms/minor" => median(minor.map { |c| c[2].to_f * 1000 }),
    "median mark ms/major" => median(major.map { |c| c[2].to_f * 1000 }),
    "fit ms/minor" => fa,
    "fit ms/major" => fb,
    "probe minor ms" => median(d["probe"]["minor"].map { |g, _| g / 1e6 }),
    "probe major ms" => median(d["probe"]["major"].map { |g, _| g / 1e6 }),
  }
end

runs = Dir["#{dir}/*.json"].map do |f|
  b, m, v, r = File.basename(f, ".json").split(".")
  [[b, m, v, r], metrics(JSON.parse(File.read(f)))]
end.to_h

keys = runs.values.first.keys
pct = ->(x, y) { x && y && y != 0 ? format("%+.1f%%", (x - y) / y * 100) : "–" }
num = ->(x) { x ? format("%.2f", x) : "–" }

runs.keys.map { |b, m, _, _| [b, m] }.uniq.sort.each do |b, m|
  rounds = runs.keys.select { |k| k[0] == b && k[1] == m }.map(&:last).uniq.sort
  puts "## #{b} #{m}"
  puts "| metric | base-a | A/A (base-b) | patch |"
  puts "|---|---:|---:|---:|"
  keys.each do |k|
    cells = rounds.map do |r|
      a = runs[[b, m, "base-a", r]]&.[](k)
      bb = runs[[b, m, "base-b", r]]&.[](k)
      p = runs[[b, m, "patch", r]]&.[](k)
      [num[a], pct[bb, a], pct[p, a]]
    end
    puts "| #{k} | #{cells.map { _1[0] }.join(" / ")} | #{cells.map { _1[1] }.join(" / ")} | #{cells.map { _1[2] }.join(" / ")} |"
  end
  puts
end

# Pooled view: every base-a and base-b process is a base process. For each metric, the spread
# (coefficient of variation) across base processes, the patch effect against the base mean, and the
# effect in units of the standard error of that difference.
puts "## Pooled: base processes (base-a + base-b) vs patch processes"
puts "| bench mode | metric | base CV | patch effect | effect / SE |"
puts "|---|---|---:|---:|---:|"
runs.keys.map { |b, m, _, _| [b, m] }.uniq.sort.each do |b, m|
  keys.each do |k|
    base = runs.select { |(rb, rm, v, _), _| rb == b && rm == m && v.start_with?("base") }.values.map { _1[k] }.compact
    patch = runs.select { |(rb, rm, v, _), _| rb == b && rm == m && v == "patch" }.values.map { _1[k] }.compact
    next if base.size < 2 || patch.empty?
    bm = mean(base)
    sd = Math.sqrt(base.sum { (_1 - bm)**2 } / (base.size - 1))
    eff = (mean(patch) - bm) / bm
    cv = sd / bm
    se = cv * Math.sqrt(1.0 / base.size + 1.0 / patch.size)
    puts "| #{b} #{m} | #{k} | #{format("%.1f%%", cv * 100)} | #{format("%+.1f%%", eff * 100)} | #{se > 0 ? format("%+.1f", eff / se) : "–"} |"
  end
end
