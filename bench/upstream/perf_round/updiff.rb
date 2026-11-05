# ruby updiff.rb OLD.json NEW.json [self|incl] [N] [grep]  -> methods that cost more in NEW, per unit
require "json"
old, new, by, n, re = ARGV
by ||= "self"; n = (n || 40).to_i; re = re && Regexp.new(re)
def load(p, by)
  h = Hash.new(0)
  JSON.parse(File.read(p))["methods"].each { |m| h["#{m["file"]} #{m["method"].gsub(/#<Class:0x\h+>/, "#<Class>").gsub(/_\d+_\d+\z/, "")}"] += m[by] }
  h
end
a, b = load(old, by), load(new, by)
rows = (a.keys | b.keys).map { |k| [k, a[k], b[k], b[k] - a[k]] }
rows.select! { _1[0] =~ re } if re
rows.sort_by { -_1[3] }.first(n).each { |k, x, y, d| printf("%+12.1fM %10.1fM %10.1fM  %s\n", d / 1e6, x / 1e6, y / 1e6, k) }
