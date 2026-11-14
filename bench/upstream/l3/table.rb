# frozen_string_literal: true

# table.rb DIR MODE: one Markdown table per width from run.sh's TREE-MODE-wWIDTH.jsonl files (trees s81, main,
# main2 and fix). Under YJIT a cell counts only when main, main2 and fix compiled nothing in their windows ("rej"
# otherwise); the 8.1 column says "not flat" when 8.1 compiled.
require "json"

dir, mode = ARGV
fix = ENV.fetch("FIX", "fixA")
widths = Dir["#{dir}/main-#{mode}-w*.jsonl"].map { _1[/-w(\d+)\.jsonl\z/, 1].to_i }.sort
pct = ->(a, b) { format("%+.1f%%", (a.fdiv(b) - 1) * 100) }

widths.each do |width|
  data = %w[s81 main main2].push(fix).to_h do |tree|
    path = "#{dir}/#{tree}-#{mode}-w#{width}.jsonl"
    [tree, File.exist?(path) ? File.readlines(path).to_h { |l| r = JSON.parse(l); [r["case"], r] } : {}]
  end
  puts "### #{mode}, #{width} columns", ""
  puts "| case | 8.1 | main | A/A | fix | fix vs main | main vs 8.1 | fix vs 8.1 | objects 8.1 / main / fix |"
  puts "|---|---:|---:|---:|---:|---:|---:|---:|---|"
  data["main"].each_key do |name|
    next if name == "_empty"
    s81, main, main2, fixed = data.values_at("s81", "main", "main2", fix).map { _1[name] }
    next unless main && main2 && fixed
    if [main, main2, fixed].any? { _1["jit_blocks"].nonzero? }
      puts "| #{name} | | rej | | | | | | |"
      next
    end
    flat81 = s81 && s81["jit_blocks"].zero?
    puts "| #{name} | #{flat81 ? s81["ir"] : "not flat"} | #{main["ir"]} | #{pct.(main2["ir"], main["ir"])} | " \
      "#{fixed["ir"]} | **#{pct.(fixed["ir"], main["ir"])}** | #{flat81 ? pct.(main["ir"], s81["ir"]) : "—"} | " \
      "#{flat81 ? pct.(fixed["ir"], s81["ir"]) : "—"} | #{s81&.dig("objects")} / #{main["objects"]} / #{fixed["objects"]} |"
  end
  puts
end
