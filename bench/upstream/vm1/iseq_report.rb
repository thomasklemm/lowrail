# frozen_string_literal: true

# Interpreted instructions per request by ISEQ, from jit_stats.rb runs on the
# VM1 measurement build (APP.json plus APP.N.iseq.tsv per window).
#   ruby iseq_report.rb [--top N] [--app APP] DIR...
# "compiled" ISEQs have YJIT entry code, so their interpreted instructions
# follow a side exit or an exception; the others never got entry code (below
# the call threshold, rejected as cold, or not compilable).
require "json"

top = ARGV.include?("--top") ? Integer(ARGV[ARGV.index("--top") + 1]) : 30
only = ARGV.include?("--app") ? ARGV[ARGV.index("--app") + 1] : nil
dirs = ARGV.each_with_index.reject { |a, i| a.start_with?("--") || ARGV[i - 1]&.start_with?("--") && i > 0 }.map(&:first)
TYPES = %w[top method block class rescue ensure eval main plain].freeze
SHORT = %r{\A.*/(gems|bundler/gems)/|\A.*/\.corpus/}

per_app = {}
dirs.each do |dir|
  set = File.basename(dir).start_with?("ce2-") ? "CE2 " : ""
  Dir["#{dir}/*.json"].sort.each do |path|
    j = JSON.parse(File.read(path))
    app = set + j["app"]
    next if only && app != only
    windows = j["windows"]
    iseqs = Hash.new { |h, k| h[k] = { insns: 0.0, compiled: false, calls: 0 } }
    totals = Hash.new(0.0)
    windows.each do |w|
      tsv = path.sub(/\.json\z/, ".#{w["index"]}.iseq.tsv")
      next unless File.exist?(tsv)
      File.foreach(tsv, chomp: true) do |line|
        _ptr, insns, calls, compiled, type, lineno, file, label = line.split("\t", 8)
        insns = insns.to_f / w["requests"] / windows.size
        next if insns == 0
        key = "#{label}@#{file.sub(SHORT, "")}:#{lineno}"
        e = iseqs[key]
        e[:insns] += insns
        e[:compiled] ||= compiled == "1"
        e[:calls] = [e[:calls], calls.to_i].max
        e[:type] = TYPES[type.to_i]
        totals[compiled == "1" ? :compiled : :not_compiled] += insns
      end
      s = w["stats"]
      totals[:vm_insns] += s.fetch("vm_insns_count", 0) / windows.size
      totals[:yjit_insns] += s.fetch("yjit_insns_count", 0) / windows.size
    end
    per_app[app] = { totals: totals, iseqs: iseqs }
  end
end

per_app.each do |app, d|
  t = d[:totals]
  sum = t[:compiled] + t[:not_compiled]
  share = 100 * t[:vm_insns] / (t[:vm_insns] + t[:yjit_insns])
  puts format("%s: interpreted %.0f insns/request (%.1f%% of retired; per-ISEQ sum %.0f), not compiled %.1f%%, after exits %.1f%%",
    app, t[:vm_insns], share, sum, 100 * t[:not_compiled] / sum, 100 * t[:compiled] / sum)
  d[:iseqs].sort_by { -_2[:insns] }.first(top).each do |k, e|
    puts format("  %9.0f %5.1f%% %-12s %-6s calls=%-9d %s", e[:insns], 100 * e[:insns] / sum, e[:compiled] ? "after-exit" : "interpreted", e[:type], e[:calls], k)
  end
end
