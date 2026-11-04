# usage: ruby inputs.rb CONST INDEX...  prints generated inputs without loading Rails
src = File.read(File.join(__dir__, "harness.rb")).split("# ---- Load Rails").first
OUT = nil; ARGV_SAVE = ARGV.dup; ARGV.clear
eval(src.sub(/^OUT = ARGV.shift\n/, "").sub(/^ONLY = ARGV\n/, "ONLY = []\n"), binding, "harness.rb")
c = Object.const_get(ARGV_SAVE.shift)
ARGV_SAVE.each { |i| puts "#{i}: #{c[Integer(i)].inspect}" }
