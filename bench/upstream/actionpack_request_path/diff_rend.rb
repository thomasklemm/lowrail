# Differential for ActionController::Renderers::All#_all_renderers: render results and renderer lists.
require "bundler/setup"
RAILS = ENV.fetch("RAILS")
%w[activesupport actionpack actionview activemodel].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "action_controller"
require "action_view"
ITER = Integer(ENV["ITER"] || 30)
out = []

ActionController::Renderers.add(:csv) { |obj, opts| send_data obj.to_s, type: "text/csv" }
ActionController::Renderers.add(:shout) { |obj, opts| self.content_type = "text/plain"; obj.to_s.upcase }

class BaseC < ActionController::Base
  self.view_paths = []
  def action_with(opts) = render(**opts)
end
class OwnC < BaseC
  use_renderers :csv_custom
  def _render_with_renderer_csv_custom(obj, opts) = "own:#{obj}"
end
class ApiC < ActionController::API
  def action_with(opts) = render(**opts)
end
class MetalC < ActionController::Metal
  include AbstractController::Rendering
  include ActionController::Rendering
  include ActionController::Renderers
  use_renderers :json
  def action_with(opts) = render(**opts)
end

OPTS = [
  { json: { a: 1 } }, { xml: { a: 1 } }, { js: "alert(1)" }, { plain: "hi" }, { html: "<b>x</b>".html_safe },
  { body: "raw" }, { markdown: "# x" }, { svg: "<svg/>" }, { csv: "a,b" }, { shout: "loud" }, { csv_custom: "z" },
  { json: { a: 1 }, xml: { b: 2 } }, { xml: { b: 2 }, json: { a: 1 } }, { shout: "s", json: 1 }, { json: 1, callback: "cb" },
  { inline: "<%= 1 + 1 %>" }, { json: nil }, {},
]

def run(klass, opts)
  env = Rack::MockRequest.env_for("/x")
  req = ActionDispatch::Request.new(env)
  c = klass.new
  c.set_request!(req)
  c.set_response!(klass.make_response!(req))
  r = c.action_with(opts.dup)
  [c.response_body.respond_to?(:join) ? c.response_body.join : c.response_body.inspect, c.response.media_type, r.class]
rescue => e
  [e.class, e.message[0, 160]]
end

[BaseC, OwnC, ApiC, MetalC].each do |k|
  c = k.new
  list = c._all_renderers
  out << "#{k} all=#{list.to_a.inspect} class=#{list.class} frozen=#{list.frozen?} same_as_all=#{list.equal?(ActionController::Renderers.all)}"
  OPTS.each_with_index do |o, i|
    res = nil
    ITER.times { res = run(k, o) }
    out << "#{k} #{i} #{o.keys.inspect} => #{res.inspect}"
  end
end

# Renderers added and removed after classes are loaded are seen on the next render.
ActionController::Renderers.add(:late) { |obj, _| "late:#{obj}" }
out << "after add late: #{run(BaseC, { late: 1 }).inspect} #{BaseC.new._all_renderers.to_a.inspect}"
ActionController::Renderers.remove(:late)
out << "after remove late: #{run(BaseC, { late: 1 }).inspect} #{BaseC.new._all_renderers.to_a.inspect}"
ActionController::Renderers.remove(:shout)
out << "after remove shout: #{run(BaseC, { shout: 1 }).inspect}"
puts out
