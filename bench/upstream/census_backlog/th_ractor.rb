# Clean process: standalone require "action_view", no prior registration.
require "bundler/setup"
%w[activesupport actionview actionpack].each { $LOAD_PATH.unshift File.join(ENV["RAILS"], _1, "lib") }
require "action_view"
T = ActionView::Template
def r(&) = (v = yield; v.inspect) rescue "#{$!.class}: #{$!.message[0, 80]}"
out = []
out << "standalone reg #{r { T.registered_template_handler(:erb).class }} exts #{r { T.template_handler_extensions }}"
out << "ractor-reg #{r { Ractor.new { ActionView::Template.registered_template_handler(:erb).class.name }.value }}"
out << "ractor-exts #{r { Ractor.new { ActionView::Template.template_handler_extensions }.value }}"
out << "ractor-regdef #{r { Ractor.new { ActionView::Template.register_default_template_handler(:rr, ActionView::Template::Handlers::Raw.new.freeze); 1 }.value }}"
# shareable proc registered as default, then read from a Ractor
T.register_default_template_handler(:md, ->(_, s) { s })
out << "proc-default shareable=#{r { Ractor.shareable?(T.handler_for_extension(:zz)) }}"
out << "ractor-reg-md #{r { Ractor.new { ActionView::Template.registered_template_handler(:md).call(nil, "ok") }.value }}"
puts out
