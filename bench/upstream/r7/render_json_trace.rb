require "bundler/setup"
require "action_controller"
require "active_support/core_ext/object/json"
class C < ActionController::Base
  def show; render json: { id: 1, name: "a", email: "e", created_at: nil }; end
  def esc; render json: { id: 1 }, status: :ok; end
end
calls = Hash.new(0)
tp = TracePoint.new(:call, :c_call) { |t| calls[[t.defined_class, t.method_id]] += 1 if t.method_id == :as_json && t.defined_class == Hash }
%w[show esc].each do |a|
  env = Rack::MockRequest.env_for("/")
  C.action(a).call(env)  # warm
  calls.clear; tp.enable { C.action(a).call(Rack::MockRequest.env_for("/")) }
  puts "#{a}: Hash#as_json calls=#{calls.values.sum}"
end
o = nil
C.prepend(Module.new { def render(*a, **k); super; end })
module ActiveSupport::JSON; class << self; prepend(Module.new { def encode(v, o = nil); $o = o; super; end }); end; end
C.action("show").call(Rack::MockRequest.env_for("/")); p $o
