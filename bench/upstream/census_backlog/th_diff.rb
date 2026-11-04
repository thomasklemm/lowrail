require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"
T = ActionView::Template
def r(&) = (v = yield; v.inspect) rescue "#{$!.class}"
sym = Object.new; def sym.to_sym = :erb
priv = Object.new; class << priv; private def to_sym = :erb; end
str = Class.new(String) { def to_sym = :html }.new("erb")
out = []
[:erb, "erb", :html, nil, false, :nope, "", sym, priv, str, 1, Object.new].each_with_index do |e, i|
  out << "reg #{i}: #{r { h = T.registered_template_handler(e); h.equal?(T.handler_for_extension(e)) ? "same-as-hfe" : h.class.name }}"
end
out << "exts #{r { T.template_handler_extensions }} frozen=#{r { T.template_handler_extensions.frozen? }} fresh=#{r { !T.template_handler_extensions.equal?(T.template_handler_extensions) }}"
h = Class.new { def call(t, s) = s }.new
T.register_template_handler :foo, :bar, h
out << "exts+ #{r { T.template_handler_extensions }}"
T.unregister_template_handler :bar
out << "exts- #{r { T.template_handler_extensions }}"
d = ->(_, s) { s }
out << "regdef #{r { T.register_default_template_handler(:mydef, d); nil }}"
out << "def? #{r { T.handler_for_extension(:unknown).equal?(T.registered_template_handler(:mydef)) }} nil-ext #{r { T.handler_for_extension(nil).equal?(T.registered_template_handler(:mydef)) }} callable #{r { T.handler_for_extension(nil).call(nil, "x") }}"
out << "regdef-str #{r { T.register_default_template_handler("strdef", h); T.registered_template_handler(:strdef).equal?(h) && T.handler_for_extension(:zzz).equal?(h) }}"
out << "regdef-noext #{r { T.register_default_template_handler(nil, h) }}"
T.unregister_template_handler :strdef
out << "after-unreg default #{r { T.handler_for_extension(:zzz) }}"
out << "argc #{r { T.registered_template_handler }} #{r { T.register_default_template_handler(:a) }} #{r { T.template_handler_extensions(1) }}"
out << "arity #{[:registered_template_handler, :template_handler_extensions, :register_default_template_handler].map { T.method(_1).arity }}"
puts out
calls = 0
conv = Object.new
conv.define_singleton_method(:to_sym) { (calls += 1) == 1 ? :conv1 : :conv2 }
h2 = Class.new { def call(t, s) = s }.new
puts "regdef-stateful #{r { T.register_default_template_handler(conv, h2).equal?(h2) }} to_sym-calls=#{calls} registered=#{r { T.registered_template_handler(:conv1).equal?(h2) }} default=#{r { T.handler_for_extension(:zzz).equal?(h2) }}"
calls = 0
puts "reg-to_sym-calls #{r { T.registered_template_handler(conv).equal?(h2) }} calls=#{calls}"
