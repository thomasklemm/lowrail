# A refinement of Kernel#== that is never activated changes `a != b` in the interpreter, not under --zjit.
Module.new { refine(Kernel) { def ==(other) = 1 } }
class A; end
begin
  p(A.new != 1)
rescue NoMethodError => e
  puts "NoMethodError: #{e.message[0, 60]}"
end
begin
  p(nil != 1)
rescue NoMethodError => e
  puts "NoMethodError: #{e.message[0, 60]}"
end
p(A.new == 1)
