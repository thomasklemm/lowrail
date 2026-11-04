# frozen_string_literal: true

# Wall ns per call of tag_micro.rb cases for Rails variants, one process per run,
# pinned to one CPU, variant order rotated each round, median over rounds:
#   ruby ns_variants.rb RUBY "FLAGS" CPU ROUNDS N "CASES" VARIANT...
ruby, flags, cpu, rounds, n, cases, *variants = ARGV
script = File.join(__dir__, ENV.fetch("SCRIPT", "tag_micro.rb"))
cases.split.each do |c|
  runs = Hash.new { |h, k| h[k] = [] }
  Integer(rounds).times do |r|
    variants.rotate(r).each do |v|
      env = { "BUNDLE_GEMFILE" => File.expand_path("~/w/avb/#{v}/Gemfile"), "WARMUP" => "20000", "ROUNDS" => "1" }
      out = IO.popen(env, ["taskset", "-c", cpu, ruby, *flags.split, script, c, n, "ns"], &:read)
      runs[v] << Float(out)
    end
  end
  med = runs.transform_values { |a| a.sort[a.size / 2] }
  base = med[variants.first]
  puts ([c] + variants.map { |v| format("%s=%.1f (%+.1f%%)", v, med[v], 100 * (med[v] / base - 1)) }).join("\t")
end
