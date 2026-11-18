# script/upstream-bench check of its JIT-flat gate: the second case redefines a method inside every measured
# window, so each of its JIT cells must say "not JIT-flat, no claim"; the first, on another class, must pass.
class Flat
  def value = 1
end

class Redefined
  def value = 1
end

flat = Flat.new
redefined = Redefined.new

UpstreamBench.report("flat.value") { flat.value }
UpstreamBench.report("redefine, then redefined.value") do
  Redefined.class_eval { def value = 1 }
  redefined.value
end
