# frozen_string_literal: true

# Census 9: per-call Ir and objects of request-path calls that changed since
# census 8, for a Rails checkout in RAILS (lib directories, no bundle). Same
# measurement as attr_micro.rb (IrCount under census 8's patched Callgrind,
# --instr-atstart=no; N calls after WARM warmup calls, fixed heap from the caller).
# Prints CASE Ir/call objects/call jit, where jit is the YJIT blocks compiled in the
# measured window (0 = JIT-flat).
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c9/ext/ir_count.so"))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.boolean :published, default: true; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body; t.timestamps }
end
class Author < ActiveRecord::Base; has_many :posts; has_many :comments, through: :posts; end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  scope :published, -> { where(published: true) }
end
class Comment < ActiveRecord::Base; belongs_to :post; end
AUTHOR = Author.create!(name: "a")
3.times { |i| AUTHOR.posts.create!(title: "t#{i}") }
POST = Post.first
3.times { POST.comments.create!(body: "c") }

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) { resources :comments } }
class View < ActionView::Base
  include ROUTES.url_helpers
end
VIEW = View.empty
# Forgery protection on, as in an app view; the token itself is a stub, so only
# the helper's own work is counted.
class CsrfView < View
  def protect_against_forgery? = true
  def form_authenticity_token(form_options: {}) = "tok"
  def request_forgery_protection_token = :authenticity_token
end
CSRF = CsrfView.empty
CSRF.output_buffer = ActionView::OutputBuffer.new
VIEW.output_buffer = ActionView::OutputBuffer.new
# _set_vary_header on a rendered HTML response: no Vary yet, and the Vary that
# the CSRF Sec-Fetch-Site check sets first in apps that use it.
class VaryController < ActionController::Base; end
VARY_REQ = ActionDispatch::Request.new(Rack::MockRequest.env_for("/posts", "HTTP_ACCEPT" => "text/html,application/xhtml+xml"))
VARY_RES = ActionDispatch::Response.new
VARY = VaryController.new.tap { _1.set_request!(VARY_REQ); _1.set_response!(VARY_RES) }
A = Post.where(author_id: 1)
P20 = (1..20).to_h { ["k#{_1}", "v#{_1}"] }.freeze
VARY_LONG = (1..200).map { "X-H#{_1}" }.join(", ").freeze
P2000 = (1..2000).to_h { ["k#{_1}", "v#{_1}"] }.freeze
P200 = (1..200).to_h { ["k#{_1}", "v#{_1}"] }.freeze
LABEL_1MB = ("a<b " * 262_144).freeze
B = Post.order(:id)

CASES = {
  "merge" => -> { A.merge(B) },
  "merge_scope" => -> { Post.published.merge(Post.where(title: "t1")) },
  "assoc_reader" => -> { AUTHOR.posts.reset; AUTHOR.posts.to_a },
  "assoc_through" => -> { AUTHOR.comments.reset; AUTHOR.comments.to_a },
  "assoc_scope_where" => -> { AUTHOR.posts.where(title: "t1").to_a },
  "button_to" => -> { VIEW.button_to("Delete", VIEW.post_path(1), method: :delete) },
  "button_to_patch" => -> { VIEW.button_to("Save", VIEW.post_path(1), method: :patch, class: "b", data: { turbo: false }) },
  "button_to_params20" => -> { VIEW.button_to("Go", VIEW.posts_path, params: P20) },
  "button_to_params200" => -> { VIEW.button_to("Go", VIEW.posts_path, params: P200) },
  "button_to_1mb_label" => -> { VIEW.button_to(LABEL_1MB, VIEW.post_path(1), method: :delete) },
  "csrf_button_to" => -> { CSRF.button_to("New", CSRF.posts_path) },
  "csrf_button_to_delete" => -> { CSRF.button_to("Delete", CSRF.post_path(1), method: :delete) },
  "csrf_button_to_get" => -> { CSRF.button_to("Show", CSRF.post_path(1), method: :get) },
  "csrf_button_to_block" => -> { CSRF.button_to(CSRF.post_path(1), method: :patch) { "Save" } },
  "csrf_button_to_form_opts" => -> { CSRF.button_to("Up", CSRF.posts_path, form: { multipart: true, "data-turbo" => "false" }, form_class: "f") },
  "csrf_button_to_remote" => -> { CSRF.button_to("Go", CSRF.posts_path, remote: true) },
  "csrf_button_to_params20" => -> { CSRF.button_to("Go", CSRF.posts_path, params: P20) },
  "csrf_button_to_params2000" => -> { CSRF.button_to("Go", CSRF.posts_path, params: P2000) },
  "csrf_form_tag" => -> { CSRF.form_tag(CSRF.posts_path) { "x" } },
  "vary_header" => -> { VARY_RES.headers.delete("Vary"); VARY.send(:_set_vary_header) },
  "vary_header_existing" => -> { VARY_RES.headers["Vary"] = "Sec-Fetch-Site"; VARY.send(:_set_vary_header) },
  "vary_header_long" => -> { VARY_RES.headers["Vary"] = VARY_LONG; VARY.send(:_set_vary_header) },
  "link_to" => -> { VIEW.link_to("x", VIEW.post_path(1), class: "a") },
  "path_helper" => -> { VIEW.post_comment_path(POST, 1) },
}.freeze

n = Integer(ENV.fetch("N", "300"))
warm = Integer(ENV.fetch("WARM", "300"))
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
IrCount.start if IrCount.running?
(ARGV.empty? ? CASES.keys : ARGV).each do |name|
  fn = CASES.fetch(name)
  # The 1 MB label and 2,000-param cases run a tenth as often.
  calls = name.end_with?("1mb_label", "2000") ? [n / 10, 5].max : n
  [warm, calls].min.times { fn.() }
  # JIT-flat: warm until three windows in a row compile nothing (at most 30), as in attr_micro.rb.
  if yjit
    flat = 0
    30.times do
      b = blocks.()
      calls.times { fn.() }
      flat = blocks.() == b ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  calls.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  jit = blocks.() - b0
  GC.enable
  puts format("%-20s %12.1f %8.2f %d", name, (i1 - i0).fdiv(calls), (o1 - o0).fdiv(calls), jit)
  $stdout.flush
end
