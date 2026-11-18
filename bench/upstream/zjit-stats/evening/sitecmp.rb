# sitecmp.rb OLD.tsv NEW.tsv PATTERN [N]: compare trace sample counts per (reason, site), paths normalized
norm = ->(s) { s.gsub(%r{/home/user/rb/[^/]+/lib/ruby/(gems/[^/]+/gems/|[^/]+/)}, "").gsub(%r{/home/user/w/rbc/[^/]+/benchmarks/}, "").gsub(/0x\h+/, "0x").gsub(/___\d+_\d+/, "") }
load = ->(f) { h = Hash.new(0); (f.end_with?(".gz") ? IO.popen(["zcat", f]) : File.open(f)).each_line.drop(1).each { |l| c, r, s, n = l.chomp.split("\t"); h[[r, norm[s]]] += n.to_i }; h }
old, new = load[ARGV[0]], load[ARGV[1]]
pat = Regexp.new(ARGV[2]); n = Integer(ARGV[3] || 25)
keys = (old.keys | new.keys).select { |r, _| r =~ pat }
keys.sort_by { |k| -[old[k], new[k]].max }.first(n).each { |k| puts [old[k], new[k], k[0], k[1]].join("\t") }
