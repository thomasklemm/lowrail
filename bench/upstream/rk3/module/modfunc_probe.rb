module M
  private
  def un(s); "M:#{s}"; end
end
module U
  module_function
  def other; end
  include M
  module_function :un
end
class Q; include M; end
class Q2 < Q; def un(s); "Q2:" + super; end; public :un; end
class C; include U; def go; un("c"); end; end
p U.un("x"), U.respond_to?(:un), U.public_methods(false).include?(:un), U.singleton_class.public_method_defined?(:un)
p U.private_instance_methods(false).include?(:un), U.private_method_defined?(:un), U.public_method_defined?(:un)
p C.new.go, (C.new.un("y") rescue $!.class), Q.private_method_defined?(:un), Q2.new.un("z")
p U.method(:un).owner, U.instance_method(:un).owner, U.method(:un).arity
