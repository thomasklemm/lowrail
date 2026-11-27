# frozen_string_literal: true

# The Rails 8 default stack's own loops, per operation: solid_queue (enqueue, poll, claim, perform, finish),
# solid_cache (read, write, fetch, read_multi), solid_cable (broadcast, writer flush, listener poll) and
# Turbo Streams broadcasts, in a `rails new` app on Rails main in production. See
# docs/upstream/solid-stack-census.md.
#   ruby -rbundler/setup harness.rb objects OUT_JSON      objects per op (two GC-free windows)
#   ruby -rbundler/setup harness.rb cpu OUT_JSON          under script/cpu-census's patched Callgrind
#   ruby -rbundler/setup harness.rb alloc OUT_JSON        allocation sites per op (traced, GC off)
# Environment: APP (the app dir), DB=pg for PostgreSQL, ONLY="name|name", WARMUP, OPS (ops per window).
require "json"
require "digest"

APP = ENV.fetch("APP")
ENV["RAILS_ENV"] = "production"
ENV["SECRET_KEY_BASE_DUMMY"] = "1"
mode, output = ARGV
raise "fresh output required" if File.exist?(output)
require File.join(APP, "config/environment")

srand(42)
Rails.logger.level = :info

# Primary-database records the stack works on: Fizzy-like cards with a user.
conn = ActiveRecord::Base.connection
unless conn.table_exists?(:cards)
  conn.create_table(:users) { |t| t.string :name; t.timestamps }
  conn.create_table(:cards) { |t| t.references :user; t.string :title; t.text :description; t.timestamps }
end
User.reset_column_information
Card.reset_column_information
user = User.first || User.create!(name: "Kevin McConnell")
if Card.count < 50
  text = "Customers on the annual plan see the old renewal date after switching boards. Steps to reproduce: " * 6
  50.times { |i| Card.create!(user: user, title: "Renewal date is stale after board switch #{i}", description: text) }
end
card = Card.order(:id).first
cards = Card.order(:id).limit(20).to_a

# Solid Queue: a worker and dispatcher as `bin/jobs` builds them, registered, without their threads.
SolidQueue::Process.where(name: %w[census-worker census-cycler census-loomio census-dispatcher]).delete_all
worker = SolidQueue::Worker.new(queues: "*", threads: 3, polling_interval: 0.1, name: "census-worker")
worker.send(:register)
cycler = SolidQueue::Worker.new(queues: "*", threads: 3, polling_interval: 0.1, name: "census-cycler")
cycler.send(:register)
loomio_queues = %w[search_index default mailers low active_storage* action_mailbox* solid_queue_recurring]
loomio = SolidQueue::Worker.new(queues: loomio_queues, threads: 3, polling_interval: 1, name: "census-loomio")
loomio.send(:register)
dispatcher = SolidQueue::Dispatcher.new(polling_interval: 1, batch_size: 500, name: "census-dispatcher")
in_executor = ->(&block) { worker.send(:wrap_in_app_executor, &block) }

# Solid Cable: the server's adapter with its writer thread stopped (so the queue isn't drained concurrently), and
# a listener with Fizzy-like subscriptions whose thread is stopped, polled on this thread as `listen` does.
pubsub = ActionCable.server.pubsub
broadcaster = pubsub.send(:broadcaster)
broadcaster.send(:thread).kill
listener = ActionCable::SubscriptionAdapter::SolidCable.const_get(:Listener).new(pubsub, pubsub.send(:pubsub_executor))
listener.shutdown
streams = 20.times.map { |i| "Z2lkOi8vc3RhY2thcHAvQ2FyZC8#{i}" }
delivered = 0
streams.each { |s| listener.add_subscriber(s, ->(_) { delivered += 1 }, nil) }
# One iteration of the listener's own loop: `interruptible` just yields (no semaphore), and the sleep that ends the
# iteration throws out of `listen`. The same stubs on both sides; the poll itself runs unchanged.
def listener.interruptible = yield
def listener.sleep(_) = throw(:polled)
listen_once = -> { catch(:polled) { listener.send(:listen) } }
listen_once.call

turbo_html = ApplicationController.render(partial: "cards/card", locals: { card: card }).to_str
stream_html = %(<turbo-stream action="replace" target="card_#{card.id}"><template>#{turbo_html}</template></turbo-stream>)
# Fragment caching stores the rendered String (write_fragment calls to_str).
fragment = ApplicationController.render(partial: "cards/card", collection: Card.order(:id).limit(3)).to_str * 2
notification_html = cards.map { |c| ApplicationController.render(partial: "notifications/notification", locals: { notification: c }).to_str }
store = Rails.cache
fragment_key = "views/cards/_container:#{Digest::MD5.hexdigest("cards/_container")}/cards/#{card.id}"
store.write(fragment_key, fragment)
store.fetch(card) { fragment }
$stderr.puts "sizes: fragment #{fragment.bytesize}, stream #{stream_html.bytesize}, notification #{notification_html.sum(&:bytesize) / 20}"
collection_keys = cards.map { |c| "views/notifications/_notification:#{Digest::MD5.hexdigest("n")}/#{c.cache_key_with_version}" }
cards.each_with_index { |c, i| store.write(collection_keys[i], notification_html[i]) }
miss = 0
batch = 4.times.map { SolidCable::BatchedBroadcaster::Message.new(channel: streams[_1], payload: stream_html.to_json) }

Op = Struct.new(:name, :kind, :call)
OPS = [
  Op.new("queue enqueue (record argument)", :queue, -> { NotifyRecipientsJob.perform_later(card) }),
  Op.new("queue enqueue scheduled (wait 5 min)", :queue, -> { NotifyRecipientsJob.set(wait: 5.minutes).perform_later(card) }),
  Op.new("queue perform_all_later (10 jobs)", :queue, -> { ActiveJob.perform_all_later(cards.first(10).map { NotifyRecipientsJob.new(_1) }) }),
  Op.new("queue worker poll, idle (*)", :queue, -> { in_executor.call { worker.send(:poll) } }),
  Op.new("queue worker poll, idle (7 queues)", :queue, -> { in_executor.call { loomio.send(:poll) } }),
  Op.new("queue dispatcher poll, idle", :queue, -> { in_executor.call { dispatcher.send(:poll) } }),
  Op.new("queue job cycle (enqueue, claim, perform, finish)", :queue, lambda {
    NotifyRecipientsJob.perform_later(card)
    executions = in_executor.call { cycler.send(:claim_executions) }
    raise "claimed #{executions.size}" unless executions.size == 1
    executions.each { |e| in_executor.call { e.perform } }
  }),
  Op.new("cache read hit (4 KB fragment)", :cache, -> { store.read(fragment_key) or raise "miss" }),
  Op.new("cache read miss", :cache, -> { store.read("views/cards/missing/#{miss += 1}") and raise "hit" }),
  Op.new("cache write (4 KB fragment)", :cache, -> { store.write(fragment_key, fragment) or raise "not written" }),
  Op.new("cache fetch hit (record key, versioned)", :cache, -> { store.fetch(card) { raise "miss" } }),
  Op.new("cache fetch miss and write", :cache, -> { store.fetch("views/cards/new/#{miss += 1}") { fragment } }),
  Op.new("cache read_multi (20 fragments)", :cache, -> { store.read_multi(*collection_keys).size == 20 or raise "misses" }),
  Op.new("cable broadcast (Action Cable, solid_cable)", :cable, -> { ActionCable.server.broadcast(streams[0], stream_html) }),
  Op.new("cable writer flush (batch of 4)", :cable, -> { Rails.application.executor.wrap { SolidCable::Message.broadcast_batch(batch) } }),
  Op.new("cable listener poll, idle (20 streams)", :cable, listen_once),
  Op.new("cable listener poll, 1 message", :cable, lambda {
    SolidCable::Message.broadcast(streams[1], stream_html.to_json)
    listen_once.call
  }),
  Op.new("turbo broadcast_refresh_to record", :turbo, -> { card.broadcast_refresh }),
  Op.new("turbo broadcast_replace_to (render partial)", :turbo, -> { card.broadcast_replace_to(:cards) }),
  Op.new("turbo broadcast_prepend_later_to (enqueue)", :turbo, -> { card.broadcast_prepend_later_to(user, :notifications, target: "notifications") }),
  Op.new("turbo ActionBroadcastJob perform (render, broadcast)", :turbo, lambda {
    Turbo::Streams::ActionBroadcastJob.perform_now(card.to_gid_param, action: :replace, target: card, partial: "cards/card", locals: { card: card })
  })
].freeze

ops = OPS
ops = ops.select { ENV["ONLY"].split("|").include?(_1.name) } if ENV["ONLY"]
warmup = Integer(ENV.fetch("WARMUP", "200"))
count = Integer(ENV.fetch("OPS", "20"))

def site_key(file)
  return "<no Ruby source>" if file.nil?
  gems = { "/w/rails-main/" => "RAILS/", "/w/main/" => "GEM/", "/w/rel/" => "GEM/" }
  gems.each { |dir, key| return key + file.split(dir, 2).last if file.include?(dir) }
  return "APP/" + file.split(%r{/stackapp[^/]*/}, 2).last if file.match?(%r{/stackapp[^/]*/})
  return "GEM/" + file.split("/gems/", 2).last if file.include?("/gems/")
  rubylib = RbConfig::CONFIG.fetch("rubylibdir") + "/"
  file.start_with?(rubylib) ? "RUBY/" + file.delete_prefix(rubylib) : file
end

meta = { ruby: RUBY_DESCRIPTION, mode: mode, yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?,
  zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?, adapter: ActiveRecord::Base.connection_db_config.adapter,
  rails: `git -C #{Rails.root.join("../rails-main")} rev-parse HEAD`.strip,
  gems: %w[solid_queue solid_cache solid_cable turbo-rails].to_h { |g| s = Gem.loaded_specs.fetch(g); [g, [s.version.to_s, s.full_gem_path]] },
  warmup: warmup, ops: count }
# Each op starts from empty queue tables, so an idle poll is idle and the queue doesn't grow across ops.
reset = lambda do
  [SolidQueue::ReadyExecution, SolidQueue::ScheduledExecution, SolidQueue::ClaimedExecution, SolidQueue::Job].each(&:delete_all)
end
results = ops.map do |op|
  reset.call
  warmup.times { op.call.call }
  case mode
  when "objects"
    GC.start
    GC.disable
    windows = [count, 2 * count].map do |n|
      before = GC.stat(:total_allocated_objects)
      n.times { op.call.call }
      GC.stat(:total_allocated_objects) - before
    end
    GC.enable
    { workload: op.name, kind: op.kind, objects_per_op: (windows[1] - windows[0]).fdiv(count) }
  when "alloc"
    require "objspace"
    sites = Hash.new(0)
    GC.start
    GC.disable
    ObjectSpace.trace_object_allocations_start
    first = GC.stat(:total_allocated_objects)
    count.times { op.call.call }
    ObjectSpace.each_object do |o|
      gen = ObjectSpace.allocation_generation(o) or next
      next unless gen == GC.count
      file = ObjectSpace.allocation_sourcefile(o) or next
      sites["#{site_key(file)}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
    rescue NoMethodError, TypeError
    end
    ObjectSpace.trace_object_allocations_stop
    total = GC.stat(:total_allocated_objects) - first
    GC.enable
    { workload: op.name, kind: op.kind, objects_per_op: total.fdiv(count),
      sites: sites.sort_by { -_2 }.first(40).map { |k, n| [k, n.fdiv(count)] } }
  when "cpu"
    require ENV.fetch("CENSUS_CPU_EXT")
    GC.start
    before = GC.stat(:total_allocated_objects)
    window = CensusCpu.measure(41231, 8192) { count.times { op.call.call } }
    objects = GC.stat(:total_allocated_objects) - before
    frames, stacks = CensusCpu.stacks
    keys = frames.map { |path, label, first| [site_key(path), label.to_s, first] }
    weight = window[:work_ir].fdiv(window[:signals].nonzero? || 1) / count
    lines = Hash.new(0)
    methods = Hash.new(0)
    stacks.each do |stack, n|
      ruby = stack.index { |id, _| keys[id][0] != "<cfunc>" }
      if ruby
        id, line = stack[ruby]
        lines[[keys[id][0], line, keys[id][1]]] += n
      else
        lines[["<no Ruby frame>", 0, keys[stack[0][0]][1]]] += n
      end
      stack.filter_map { |sid, _| keys[sid] unless keys[sid][0] == "<cfunc>" }.uniq.each { methods[_1] += n }
    end
    { workload: op.name, kind: op.kind, ir_per_op: window[:work_ir].fdiv(count), gc_ir_per_op: window[:gc] * weight,
      objects_per_op: objects.fdiv(count), window: window,
      sites: lines.sort_by { -_2 }.first(60).map { |(f, l, m), n| { file: f, line: l, method: m, ir_per_op: n * weight } },
      methods: methods.sort_by { -_2 }.first(80).map { |(f, m, l), n| { file: f, method: m, line: l, incl_ir_per_op: n * weight } } }
  end.tap { $stderr.puts JSON.generate(_1.slice(:workload, :objects_per_op, :ir_per_op)) }
end
File.write(output, JSON.pretty_generate(meta.merge(workloads: results)) + "\n")
