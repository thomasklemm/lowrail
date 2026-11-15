# Callgrind: instructions and objects per javascript_importmap_tags call, with or without a nonce.
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null \
#     ruby bin/rails runner imp336_ir.rb   (NONCE=1, N=calls, YJIT=1 keeps YJIT on)
abort "yjit #{RubyVM::YJIT.enabled?}" if RubyVM::YJIT.enabled? != !!ENV["YJIT"]
env = Rack::MockRequest.env_for("https://localhost/")
if ENV["NONCE"]
  env["action_dispatch.content_security_policy"] = ActionDispatch::ContentSecurityPolicy.new { |policy| policy.script_src :self }
  env["action_dispatch.content_security_policy_nonce_generator"] = ->(request) { SecureRandom.base64(16) }
  env["action_dispatch.content_security_policy_nonce_directives"] = %w[script-src]
end
controller = ApplicationController.new
controller.request = ActionDispatch::Request.new(env)
view = controller.view_context
f = -> { view.javascript_importmap_tags }
n = Integer(ENV.fetch("N", "200"))
(ENV["YJIT"] ? 2000 : 50).times { f.call }
GC.start; GC.disable
o = GC.stat(:total_allocated_objects)
c = RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0
[f].cycle(n, &:call)
warn "objects=#{(GC.stat(:total_allocated_objects) - o).fdiv(n)} compiled=#{(RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0) - c}"
