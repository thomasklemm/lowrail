require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"
T = ActionView::Template
def r(&) = (v = yield; v.inspect) rescue "#{$!.class}: #{$!.message[0, 60]}"
out = []
h = Class.new { def call(t, s) = s; def inspect = "H" }.new

# return values
out << "regdef-ret-obj #{r { T.register_default_template_handler(:d1, h).equal?(h) }}"
pr = ->(_, s) { s }
out << "regdef-ret-proc equal-passed=#{r { T.register_default_template_handler(:d2, pr).equal?(pr) }}"
out << "default-is-passed-proc #{r { T.handler_for_extension(:zz).equal?(pr) }}"
out << "registered-is-passed-proc #{r { T.registered_template_handler(:d2).equal?(pr) }}"
out << "registered-frozen #{r { T.registered_template_handler(:d2).frozen? }} shareable=#{r { Ractor.shareable?(T.registered_template_handler(:d2)) }}"

# same proc as default and under another ext, then unregister the other ext
T.register_template_handler :d3, pr
T.unregister_template_handler :d3
out << "default-after-unreg-sibling #{r { T.handler_for_extension(:zz).equal?(T.registered_template_handler(:d2)) }}"

# proc capturing unshareable state
ivar = +"x"
cap = ->(_, s) { ivar + s }
out << "regdef-capturing #{r { T.register_default_template_handler(:d4, cap); T.handler_for_extension(:zz).call(nil, "y") }}"

# extension strings returned: mutable, chilled?
out << "ext-str-frozen #{r { T.template_handler_extensions.first.frozen? }}"
out << "ext-mutate #{r { T.template_handler_extensions.first << "!"; T.template_handler_extensions.first }}"
out << "ext-array-mutate #{r { T.template_handler_extensions << "zzz"; T.template_handler_extensions.include?("zzz") }}"

# hook: does overriding registered_template_handler change handler_for_extension?
T.singleton_class.prepend(Module.new { def registered_template_handler(e) = (e.to_s == "hooked" ? :HOOK : super) })
out << "override-hook #{r { T.handler_for_extension(:hooked) }}"
T.singleton_class.prepend(Module.new { def register_template_handler(*a, h) = (($hooked_reg ||= []) << a; super) })
T.register_default_template_handler(:d5, h)
out << "regdef-calls-register_template_handler #{r { $hooked_reg }}"

# subclass
out << "subclass #{r { Class.new(T).registered_template_handler(:erb).class }}"

# ractor
if defined?(Ractor)
  out << "ractor-reg #{r { Ractor.new { ActionView::Template.registered_template_handler(:erb).class.name }.value }}"
  out << "ractor-exts #{r { Ractor.new { ActionView::Template.template_handler_extensions.size }.value }}"
  out << "ractor-regdef #{r { Ractor.new { ActionView::Template.register_default_template_handler(:rr, ActionView::Template::Handlers::Raw.new.freeze); 1 }.value }}"
end
puts out
