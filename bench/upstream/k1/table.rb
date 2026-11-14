# frozen_string_literal: true

# Markdown tables from run.sh output: ruby table.rb DIR [MODE...]
# Per mode and width: Ir per call on main, the A/A (main2 against main), the fix against main and, when present,
# 8-1-stable (s81) against main, objects per call, and the JIT blocks compiled in the measured windows (gate: 0).
require "json"

dir = ARGV.shift
modes = ARGV.empty? ? %w[interp yjit] : ARGV
pct = ->(a, b) { a && b && b.positive? ? format("%+.2f%%", 100.0 * (a - b) / b) : "–" }
load = ->(tree, mode, w) do
  path = File.join(dir, "#{tree}-#{mode}-w#{w}.jsonl")
  File.exist?(path) ? File.readlines(path).to_h { |l| r = JSON.parse(l); [r["case"], r] } : {}
end

modes.each do |mode|
  [5, 30, 100, 300].each do |w|
    main, main2, fix, s81 = %w[main main2 fix s81].map { load.(_1, mode, w) }
    next if main.empty?
    puts "### #{mode}, #{w} columns\n\n"
    puts "| case | main Ir | A/A | fix | 8.1 vs main | objects main → fix | JIT blocks main/main2/fix |"
    puts "|---|---:|---:|---:|---:|---|---|"
    main.each do |name, m|
      next if name == "_empty"
      f, a, s = fix[name], main2[name], s81[name]
      jit = [m, a, f].map { _1 ? _1["jit_blocks"] : "–" }.join("/")
      gate = [m, a, f].compact.all? { _1["jit_blocks"].zero? } ? "" : " rejected (JIT)"
      puts "| #{name} | #{m['ir']} | #{pct.(a&.dig('ir'), m['ir'])} | #{pct.(f&.dig('ir'), m['ir'])}#{gate} | " \
        "#{pct.(s&.dig('ir'), m['ir'])} | #{m['objects']} → #{f ? f['objects'] : '–'} | #{jit} |"
    end
    puts
  end
end
