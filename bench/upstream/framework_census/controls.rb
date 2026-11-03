# frozen_string_literal: true

# Framework census behavior controls: observable results for edge cases of the
# candidate paths, printed one per line. Run under each label's Rails with
#   script/census controls --script bench/upstream/framework_census/controls.rb base2 LABEL...
# (blog bundle); every label's output must equal the base's.
require "action_controller"
require "action_view"
require "active_support/core_ext/module/attribute_accessors_per_thread"
require "active_support/subscriber"
require "active_support/log_subscriber"

def show(label, value) = puts("#{label}: #{value.inspect}")

def safely
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

# -- thread_mattr_accessor ---------------------------------------------------
class Current
  thread_mattr_accessor :user
  thread_mattr_accessor :roles, default: ["admin"]
  thread_mattr_reader :only_reader
  thread_mattr_writer :only_writer
end
class SubCurrent < Current; end
class OtherCurrent
  thread_mattr_accessor :user, instance_accessor: false
end
module CurrentModule
  thread_mattr_accessor :request_id
end

def key_names
  state = Thread.current.active_support_execution_state || {}
  owners = { Current.object_id => "Current", SubCurrent.object_id => "SubCurrent",
    OtherCurrent.object_id => "OtherCurrent", CurrentModule.object_id => "CurrentModule" }
  state.keys.grep(/\Aattr_/).map { |k| k.sub(/_(\d+)\z/) { "_#{owners.fetch(Integer($1), "?")}" } }.sort
end

show "initial", [Current.user, SubCurrent.user, Current.roles, SubCurrent.roles, Current.new.roles]
show "default frozen", [Current.roles.frozen?, Current.roles.equal?(SubCurrent.roles)]
Current.user = "a"
show "after Current=", [Current.user, SubCurrent.user, OtherCurrent.user, Current.new.user]
SubCurrent.user = "b"
OtherCurrent.user = "o"
CurrentModule.request_id = "r1"
show "after SubCurrent=", [Current.user, SubCurrent.user, OtherCurrent.user, CurrentModule.request_id]
Current.roles = nil
show "nil overrides default", [Current.roles, SubCurrent.roles]
inst = Current.new
inst.user = "via instance"
show "instance writer", [Current.user, inst.user]
Current.only_writer = "w"
show "reader/writer only", [Current.only_reader, Current.respond_to?(:only_writer), Current.new.respond_to?(:only_reader)]
show "other thread", Thread.new { [Current.user, SubCurrent.user, Current.roles, (Current.user = "t"), Current.user] }.value
show "after thread", [Current.user, SubCurrent.user]
show "state keys", key_names
key = "attr_user_#{Current.object_id}"
show "state key frozen", ActiveSupport::IsolatedExecutionState.key?(key) && Thread.current.active_support_execution_state.keys.find { _1 == key }.frozen?
ActiveSupport::IsolatedExecutionState.isolation_level = :fiber
Current.user = "fiber main"
show "fiber isolation", [Fiber.new { [Current.user, (Current.user = "f"), Current.user] }.resume, Current.user]
ActiveSupport::IsolatedExecutionState.isolation_level = :thread
show "invalid name", safely { Class.new { thread_mattr_accessor :"1bad" } }

# -- ActiveSupport::Subscriber -------------------------------------------------
LOG = []
class ControlSubscriber < ActiveSupport::Subscriber
  def render(event) = LOG << [:render, event.name, event.payload[:n]]
  def sql(event) = LOG << [:sql, event.name, event.payload[:n]]
  def start_processing(event) = LOG << [:start_processing, event.name]
  private def hidden(event) = LOG << [:hidden, event.name]
end
ControlSubscriber.attach_to :control
class DottedSubscriber < ActiveSupport::Subscriber
  def deliver(event) = LOG << [:deliver, event.name]
end
DottedSubscriber.attach_to :"mail.control"
class ControlLogSubscriber < ActiveSupport::LogSubscriber
  def query(event) = LOG << [:query, event.name, event.payload[:n]]
end
ActiveSupport::LogSubscriber.logger ||= ActiveSupport::Logger.new(IO::NULL)
ControlLogSubscriber.attach_to :control_log
instrument = ->(name, n = nil) { ActiveSupport::Notifications.instrument(name, n: n) { } }
instrument.("render.control", 1)
instrument.("sql.control", 2)
instrument.("start_processing.control")
instrument.("hidden.control")
instrument.("deliver.mail.control")
instrument.("query.control_log", 3)
ControlSubscriber.class_eval { def added(event) = LOG << [:added, event.name] }
instrument.("added.control")
manual = ControlSubscriber.new
regexp = ActiveSupport::Notifications.subscribe(/\Asql\.manual/, manual)
instrument.("sql.manual", 4)
instrument.("sql.manual.extra", 5)
ActiveSupport::Notifications.unsubscribe(regexp)
show "subscriber patterns", ActiveSupport::Subscriber.subscribers.grep(ControlSubscriber).first.patterns.keys.sort
ControlSubscriber.detach_from :control
instrument.("render.control", 6)
instrument.("added.control")
ControlSubscriber.attach_to :control
instrument.("render.control", 7)
show "subscriber log", LOG

# -- URL helpers ------------------------------------------------------------------
def url_context(defaults, url_options)
  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    resources :posts, only: [:index, :show] do
      resources :comments, only: :show
    end
    get "/feed", to: "posts#index", as: :feed, defaults: { format: :xml, host: "route.example" }
    scope "(:locale)" do
      get "/about", to: "pages#about", as: :about
    end
  end
  routes.default_url_options = defaults
  helpers = routes.url_helpers
  Class.new do
    include helpers
    define_method(:url_options) { url_options }
  end.new
end
url_option_sets = [{ host: "opts.example", protocol: "https" }, { host: "opts.example", port: 8080, script_name: "/sub" }, {}]
default_sets = [{}, { host: "defaults.example" }, { host: "defaults.example", protocol: "http", trailing_slash: true },
  { script_name: "/app", anchor: "top" }, { only_path: true, host: "x" }]
default_sets.product(url_option_sets).each do |defaults, url_options|
  t = url_context(defaults, url_options)
  results = [
    -> { t.post_path(1) }, -> { t.post_url(1) }, -> { t.post_comment_url(1, 2) }, -> { t.post_url(1, format: :json) },
    -> { t.posts_url(page: 2) }, -> { t.feed_url }, -> { t.about_url }, -> { t.about_url("de") },
    -> { t.post_url(1, host: "inner.example") }, -> { t.post_url(1, anchor: "c", trailing_slash: true) },
    -> { t.post_url(nil) }, -> { t.post_url(1, original_script_name: "/orig") }
  ].map { |c| safely(&c) }
  show "urls #{defaults.inspect} #{url_options.inspect}", results
end

# -- capture --------------------------------------------------------------------
view = ActionView::Base.empty
view.output_buffer = ActionView::OutputBuffer.new
show "capture", [view.capture { "<b>" }, view.capture { view.output_buffer << "x"; nil }, view.capture(1, 2) { |a, b| "#{a}#{b}" },
  view.capture { view.capture { "inner" } + "outer" }, view.capture { 42 }, view.capture { nil }]
view.content_for(:side) { "one" }
view.content_for(:side) { "two" }
show "content_for", [view.content_for(:side), view.content_for?(:missing)]
show "tags", [view.tag.div { view.tag.span { "x" } }, view.content_tag(:p) { "y" }, view.tag.div("z")]
buffer = ActionView::OutputBuffer.new("pre")
show "buffer capture args", [buffer.capture(:a, :b) { |*args| buffer << args.inspect }, buffer.to_s]
show "buffer capture raise", [safely { buffer.capture { raise "boom" } }, buffer.to_s]
