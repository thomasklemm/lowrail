# ruby honor.rb SHAPE KIND ; KIND def (refinement defines foo) or undef (refinement undefs foo)
shape, kind = ARGV
class P; def foo = :p; end
module M; end
case shape
when "mod_def" then M.class_eval { def foo = :m }; K = Class.new(P) { include M }; T = M
when "cls_def" then K = Class.new(P) { def foo = :k }; T = K
when "cls_inh" then K = Class.new(P); T = K
end
R = kind == "def" ? Module.new { refine(T) { def foo = :refined } } : Module.new { refine(T) { def foo = 1; undef_method :foo } }
using R
o = K.new
r = { "call" => -> { o.foo }, "send" => -> { o.send(:foo) }, "public_send" => -> { o.public_send(:foo) },
      "method" => -> { o.method(:foo).call }, "respond_to" => -> { o.respond_to?(:foo) }, "sym_proc" => -> { [o].map(&:foo)[0] } }
puts r.map { |k, l| "#{k}=#{(l.() rescue $!.class).inspect}" }.join(" ")
