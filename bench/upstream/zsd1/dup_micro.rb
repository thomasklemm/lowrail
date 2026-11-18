# Per-call cost of String#dup on a 20-byte bare String in a compiled loop.
#   valgrind --tool=callgrind ruby --zjit --zjit-call-threshold=2 dup_micro.rb N
# Run with two values of N; (Ir(N2) - Ir(N1)) / (N2 - N1) is the per-call cost.
def run(n, s)
  i = 0
  x = nil
  while i < n
    x = s.dup
    i += 1
  end
  x
end

S = +"twenty bytes string!"
raise unless S.bytesize == 20
10.times { run(50, S) }
run(Integer(ARGV[0]), S)
