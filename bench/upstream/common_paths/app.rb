require "objspace"
ENV["DATABASE_URL"] = "sqlite3::memory:"
require "bundler/setup"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

class ProbeApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = true
  config.logger = Logger.new(nil)
  config.log_level = :warn
  config.secret_key_base = "x" * 64
  config.hosts.clear
  config.active_support.deprecation = :silence
end

ProbeApp.initialize!
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :authors do |t|
    t.string :name
    t.timestamps
  end
  create_table :posts do |t|
    t.references :author
    t.string :title
    t.text :body
    t.integer :status, default: 0
    t.timestamps
  end
  create_table :comments do |t|
    t.references :post
    t.text :body
    t.timestamps
  end
end

class Author < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  enum :status, { draft: 0, live: 1 }
  validates :title, presence: true
  scope :published, -> { where(status: :live) }
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

ProbeApp.routes.draw do
  resources :posts do
    resources :comments
  end
  root "posts#index"
end

a = Author.create!(name: "Ann")
3.times { |i| p = a.posts.create!(title: "Post #{i}", body: "Body", status: :live); 2.times { p.comments.create!(body: "c") } }

class ProbeController < ActionController::Base
end

def view_context
  controller = ProbeController.new
  request = ActionDispatch::TestRequest.create
  controller.set_request!(request)
  controller.set_response!(ActionDispatch::TestResponse.new)
  controller.view_context
end

def allocs(n = 200)
  yield
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  n.times { yield }
  after = GC.stat(:total_allocated_objects)
  GC.enable
  (after - before) / n.to_f
end

def sites(n = 50, filter: %r{/work/rails/})
  yield
  counts = Hash.new(0)
  GC.start
  ObjectSpace.trace_object_allocations_start
  GC.disable
  n.times { yield }
  ObjectSpace.trace_object_allocations_stop
  ObjectSpace.each_object do |o|
    f = ObjectSpace.allocation_sourcefile(o) rescue nil
    next unless f
    gen = ObjectSpace.allocation_generation(o)
    next unless gen == GC.count
    counts["#{f.sub(%r{.*/work/rails/}, '')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
  end
  GC.enable
  ObjectSpace.trace_object_allocations_clear
  counts.select { |k, _| k !~ %r{^/} || true }.sort_by { -_2 }.first(25).map { |k, v| [k, (v / n.to_f).round(2)] }
end
