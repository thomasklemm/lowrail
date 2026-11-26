# ruby collect.rb APP...: one line per app from /home/user/ft/out/APP (ft.sh/post.sh outputs): outcomes, load order,
# tree, exit codes, plant, false alarms (default and CI job, "now" floor), overhead. Prints Markdown table rows and details.
OUT = "/home/user/ft/out"
def read(app, f) = File.exist?(p = "#{OUT}/#{app}/#{f}") ? File.read(p, invalid: :replace) : ""

ARGV.each do |app|
  outc = read(app, "outcomes.txt")
  same = outc.scan(/^(\S+) = plain$/).flatten
  diff = outc.scan(/^(\S+) DIFFERS \((\d+) lines\)$/)
  total = outc[/^plain\.outcomes: (\d+) outcomes; (.*)$/, 0]
  feats = read(app, "features.txt")
  fdiff = feats.lines.grep(/DIFFERS/).map { _1.split.first(2).join(" ") }
  summ = read(app, "summary.txt")
  trees = summ.scan(/^(\S+) tree unchanged/).size
  changed = summ.scan(/^(\S+) TREE CHANGED/).flatten
  exits = read(app, "exits.txt").lines.map(&:strip).join("; ")
  gate = read(app, "gate.txt")
  now = gate[/^now.*\z/m].to_s
  fa1 = now[/false alarms, default: ([^;]*)/, 1]
  fa2 = now[/false alarms, confirm: ([^;]*)/, 1]
  pc1 = now[/plant caught, default: ([^;]*); with an unrelated line too: (\d+)/, 1]
  unrel = now[/with an unrelated line too: (\d+)/, 1]
  pc2 = now[/plant caught, confirm: (.*)$/, 1]
  oh = read(app, "overhead.txt").strip
  caps = summ.scan(/^(u\d+|planted\d?|seed\d+) exit (\d+) wall ([\d.]+)/)
  puts "## #{app}"
  puts "outcomes: #{same.size} = plain; differ: #{diff.map { _1.join(':') }.join(', ')}; #{total}"
  puts "features differ: #{fdiff.join(', ')}"
  puts "tree unchanged #{trees}; changed: #{changed.join(', ')}"
  puts "exits: #{exits}"
  puts "capture exits: #{caps.map { "#{_1}=#{_2}" }.join(' ')}"
  puts "gate: default #{fa1}; ci #{fa2}; plant #{pc1} (unrelated #{unrel}); plant ci #{pc2}"
  puts "gate error: #{gate.lines.grep(/Error|problems|invalid/).first&.strip}" if gate.include?("Error")
  puts "overhead: #{oh}"
end
