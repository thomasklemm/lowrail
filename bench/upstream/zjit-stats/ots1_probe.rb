# Interpolation whose profile saw only Strings, then gets nil: does the guard recompile?
def f(name, content) = "<#{name}>#{content}</#{name}>"
def run(n, content)
  r = nil
  i = 0
  while i < n
    r = f("div", content)
    i += 1
  end
  r
end
run(100, "x")
s0 = RubyVM::ZJIT.stats
p run(10_000, nil)
s1 = RubyVM::ZJIT.stats
%i[exit_guard_type_failure side_exit_count compiled_iseq_count].each { |k| puts "#{k} #{s1[k].to_i - s0[k].to_i}" }
