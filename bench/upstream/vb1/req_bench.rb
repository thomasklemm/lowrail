# frozen_string_literal: true

# VB1 request mix, modeled on ruby-bench's railsbench: production-mode app, posts table with railsbench's schema
# (100 rows), routes /posts (HTML table of every post), /posts.json and /posts/1../posts/100, sampled with
# railsbench's seed. Scaffold-like ERB views with a layout; JSON via render json:. File-backed SQLite. The layout
# leaves out railsbench's csrf_meta_tags: its random token made one tree's runs differ by up to 3% (0.17% without).
#   RAILS=<tree> BUNDLE_GEMFILE=<suite> IRWIN_DIR=... N=200 valgrind --tool=callgrind --instr-atstart=no ... \
#     ruby [--yjit|--zjit] req_bench.rb
# Warmup runs the 2,000-request sequence once, then (under a JIT) windows of its first 500 until three in a row
# change no JIT counter; the measured window is the sequence's first N requests, the same on every tree.
require "bundler/setup"
require "json"
require "tmpdir"
require "digest"
# STATS=1 (with --yjit-stats or --zjit-stats, no Valgrind): JIT counters per call of the window instead of Ir.
STATS = ENV["STATS"] == "1"
if STATS
  module IrWin
    def self.instr_on = nil
    def self.zero = (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : RubyVM::YJIT).reset_stats!
    def self.dump(_) = nil
  end
  COUNTERS = %i[send_iseq_block_arg_type send_fallback_send_block_arg_not_nil dynamic_send_count
    num_send_dynamic yjit_insns_count zjit_insn_count side_exit_count]
  def stats_per_call(n)
    all = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats : RubyVM::YJIT.runtime_stats
    all.slice(*COUNTERS).transform_values { |v| v.fdiv(n).round(2) }
  end
else
  $LOAD_PATH.unshift(ENV.fetch("IRWIN_DIR"))
  require "irwin"
end
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

N = Integer(ENV.fetch("N", "200"))
YJIT = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
ZJIT = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
ROOT = Dir.mktmpdir("vb1-req")
ENV["RAILS_ENV"] = "production"
# No pool reaper thread (see attr_bench.rb).
ENV["DATABASE_URL"] = "sqlite3:#{ROOT}/db.sqlite3?reaping_frequency=0"

{
  "app/views/layouts/application.html.erb" => <<~ERB,
    <!DOCTYPE html>
    <html><head><title>Railsbench</title><%= csp_meta_tag %></head>
    <body><%= yield %></body></html>
  ERB
  "app/views/posts/index.html.erb" => <<~ERB,
    <p id="notice"><%= notice %></p>
    <h1>Posts</h1>
    <table>
      <thead><tr><th>Title</th><th>Body</th><th>Published</th><th colspan="3"></th></tr></thead>
      <tbody>
        <% @posts.each do |post| %>
          <tr>
            <td><%= post.title %></td>
            <td><%= post.body %></td>
            <td><%= post.published %></td>
            <td><%= link_to 'Show', post %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  ERB
  "app/views/posts/show.html.erb" => <<~ERB,
    <p id="notice"><%= notice %></p>
    <p><strong>Title:</strong> <%= @post.title %></p>
    <p><strong>Body:</strong> <%= @post.body %></p>
    <p><strong>Published:</strong> <%= @post.published %></p>
    <p><%= @post.created_at %> <%= @post.updated_at %></p>
    <%= link_to 'Back', posts_path %>
  ERB
}.each do |path, body|
  FileUtils.mkdir_p(File.dirname("#{ROOT}/#{path}"))
  File.write("#{ROOT}/#{path}", body)
end

class BenchApp < Rails::Application
  config.root = ROOT
  config.load_defaults 8.1
  config.eager_load = true
  config.enable_reloading = false
  config.consider_all_requests_local = false
  config.logger = Logger.new(nil)
  config.log_level = :fatal
  config.secret_key_base = "x" * 64
  config.hosts.clear
  config.public_file_server.enabled = false
  config.action_controller.perform_caching = false
  config.active_record.dump_schema_after_migration = false
end

Rails.application.initialize!
Rails.application.routes.draw { resources :posts, only: [:index, :show] }

class Post < ActiveRecord::Base; end

class PostsController < ActionController::Base
  def index
    @posts = Post.all
    respond_to do |format|
      format.html
      format.json { render json: @posts }
    end
  end

  def show
    @post = Post.find(params[:id])
  end
end

rails = File.expand_path(ENV.fetch("RAILS")) + "/"
abort "Active Record not loaded from #{rails}" unless ActiveRecord::Base.method(:find).source_location.first.start_with?(rails)

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :title
    t.text :body
    t.boolean :published
    t.timestamps
  end
end
now = Time.utc(2026, 11, 14)
100.times do |i|
  Post.create!(title: "Post #{i}", body: "Body of post #{i}. " * 10, published: i.even?, created_at: now, updated_at: now)
end
Post.connection.clear_query_cache

APP = Rails.application
routes = ["/posts", "/posts.json"] + (1..100).map { |i| "/posts/#{i}" }
rng = Random.new(0x1be52551fc152997)
VISITS = Array.new(2000) { routes.sample(random: rng) }
WINDOW = VISITS.first(N)

def visit(paths)
  paths.each do |path|
    env = Rack::MockRequest.env_for("https://localhost#{path}")
    status, _, body = APP.call(env)
    raise "HTTP #{status} for #{path}" unless status == 200
    body.close if body.respond_to?(:close)
  end
end

def jit_counters
  if YJIT
    RubyVM::YJIT.runtime_stats.values_at(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  elsif ZJIT
    RubyVM::ZJIT.stats.values_at(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  else
    []
  end
end

# Same bytes on every tree: the probe checks the responses, not only the status.
probe = ["/posts", "/posts.json", "/posts/7"].map do |path|
  _, _, body = APP.call(Rack::MockRequest.env_for("https://localhost#{path}"))
  s = +""; body.each { |part| s << part }; body.close if body.respond_to?(:close)
  s
end

visit(VISITS)
flat = 0
if YJIT || ZJIT
  30.times do
    before = jit_counters
    visit(VISITS.first(500))
    flat = jit_counters == before ? flat + 1 : 0
    break if flat == 3
  end
end
IrWin.instr_on
index_requests = WINDOW.count { |p| p.start_with?("/posts") && !p.match?(%r{/posts/\d}) }
[["_empty", []], ["requests", WINDOW]].each do |name, paths|
  GC.start
  GC.disable
  allocs = GC.stat(:total_allocated_objects)
  gcs = GC.count
  jit = jit_counters
  IrWin.zero
  visit(paths)
  IrWin.dump(name)
  stats = stats_per_call(N) if STATS
  delta = jit_counters.zip(jit).map { |a, b| a - b }
  allocs = GC.stat(:total_allocated_objects) - allocs
  gcs = GC.count - gcs
  GC.enable
  gate = (YJIT || ZJIT) ? (flat == 3 && delta.all?(&:zero?) ? "pass" : "fail") : "n/a"
  puts JSON.generate(case: name, n: N, objects: allocs.fdiv(N).round(2), gc: gcs, gate: gate, jit_delta: delta,
    index_requests: index_requests, **(STATS ? { stats: stats } : {}), probe_sha: (Digest::SHA256.hexdigest(probe.join("\n"))[0, 16]))
end
FileUtils.rm_rf(ROOT)
