# Self Ir per function from a callgrind dump (name compression aware; skips call cost lines).
# usage: cgself.rb A.cg B.cg [ops] -> top function deltas B - A
def load(path)
  names = {}; self_cost = Hash.new(0); fn = nil; skip = false; obj = file = nil
  File.foreach(path) do |l|
    case l
    when /\Acfn=\((\d+)\) (.*)/ then names[$1] = $2.strip
    when /\Afn=\((\d+)\)(?: (.*))?/ then names[$1] = $2.strip if $2; fn = names[$1]
    when /\Afn=(.*)/ then fn = $1.strip
    when /\Acalls=/ then skip = true
    when /\A[+\-*]?\d|\A\+|\A-/
      if skip then skip = false
      else
        c = l.split[1].to_i
        c -= 2**64 if c >= 2**63
        self_cost[fn] += c
      end
    end
  end
  self_cost
end
a, b = load(ARGV[0]), load(ARGV[1])
ops = (ARGV[2] || 1).to_f
puts format("self sum %d -> %d per op", a.values.sum / ops, b.values.sum / ops)
d = (a.keys | b.keys).map { [_1, (b[_1] - a[_1]) / ops, a[_1] / ops] }.sort_by { -_2 }
(d.first(30) + [nil] + d.last(15)).each { |n, x, o| puts n ? format("%+11.0f %11.0f  %s", x, o, n) : "..." }
