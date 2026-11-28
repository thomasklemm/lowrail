# Compares wall cohorts (results.json from script/upstream-bench) pairwise: xxlarge reference vs a1.large rerun.
require "json"
Q = 0.1
def med(xs) = (s = xs.sort; n = s.size; n.odd? ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2.0)
def sd(xs) = (m = xs.sum / xs.size; Math.sqrt(xs.sum { (_1 - m)**2 } / (xs.size - 1)))
def pc(x) = format("%+.2f%%", x * 100)
def stats(file)
  j = JSON.parse(File.read(file))
  j["wall"].to_h do |name, c|
    calls = c["calls"]
    est = c["rounds"].map { |r| r.transform_values { |w| Math.log(w["cpu"].sort[((w["cpu"].size - 1) * Q).round] / calls) } }
    aa = est.map { _1["base2"] - _1["base"] }
    ch = est.flat_map { [_1["candidate"] - _1["base"], _1["candidate"] - _1["base2"]] }
    procs = est.flat_map { _1.values }
    # within-process: median window / p10 window, how much a process's windows vary
    within = c["rounds"].flat_map { |r| r.values.map { |w| s = w["cpu"].sort; med(s) / s[((s.size - 1) * Q).round] - 1 } }
    wins = c.dig("jit", "windows") || []
    moved = (c.dig("jit", "moved") || []).map { _1[/\Ar\d+ \w+/] }.uniq
    [name, { change: c["change"], ci: c["change_ci"], aa: c["aa"], aa_ci: c["aa_ci"], claim: c["claim"],
      flat: "#{wins.size - moved.size}/#{wins.size}", sd_aa: sd(aa), sd_change: sd(ch),
      sd_base_proc: sd(est.flat_map { [_1["base"], _1["base2"]] }), within: med(within), base_us: Math.exp(med(est.map { (_1["base"] + _1["base2"]) / 2 })) * 1e6 }]
  end
end
ARGV.each_slice(3) do |label, ref, large|
  a, b = stats(ref), stats(large)
  a.each_key do |name|
    puts "## #{label}: #{name}"
    { "xxlarge" => a[name], "a1.large" => b[name] }.each do |k, s|
      next puts("#{k}: missing") unless s
      w = s[:ci][1] - s[:ci][0]; aw = s[:aa_ci][1] - s[:aa_ci][0]
      inside = k == "a1.large" ? (a[name][:ci][0] <= s[:change] && s[:change] <= a[name][:ci][1]) : nil
      puts format("%-9s base %.2f µs change %s [%s, %s] w=%.2fpp | A/A %s [%s, %s] w=%.2fpp | claim=%s flat=%s | sd(A/A round)=%.2f%% sd(change ratio)=%.2f%% sd(base proc)=%.2f%% within-proc med/p10=%.2f%%%s",
        k, s[:base_us], pc(s[:change]), pc(s[:ci][0]), pc(s[:ci][1]), w * 100, pc(s[:aa]), pc(s[:aa_ci][0]), pc(s[:aa_ci][1]), aw * 100,
        s[:claim], s[:flat], s[:sd_aa] * 100, s[:sd_change] * 100, s[:sd_base_proc] * 100, s[:within] * 100,
        inside.nil? ? "" : " | inside xxl CI: #{inside}")
    end
  end
end
