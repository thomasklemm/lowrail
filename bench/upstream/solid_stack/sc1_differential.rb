# frozen_string_literal: true

# SCB1 differential: the solid_cable listener's polls on main and on the branch, driven through the same script of
# subscriptions, broadcasts (single and batched, several channels, a subscriber added and removed mid-stream) and
# polls, each poll one iteration of `listen` itself, with and without polling logs silenced. Prints one line
# per step: what each subscriber received, last_id, the channels' last ids and the SQL the poll ran (without its
# binds' values). Run once per side and diff the outputs:
#   APP=~/w/stackapp BUNDLE_GEMFILE=$APP/Gemfile.main ruby -rbundler/setup sc1_differential.rb > main.txt
#   APP=~/w/stackapp BUNDLE_GEMFILE=$APP/Gemfile.cand ruby -rbundler/setup sc1_differential.rb > cand.txt
require "json"

ENV["RAILS_ENV"] = "production"
ENV["SECRET_KEY_BASE_DUMMY"] = "1"
require File.join(ENV.fetch("APP"), "config/environment")
Rails.logger.level = :debug
ActiveRecord::Base.logger = ActiveSupport::Logger.new(IO::NULL)

SolidCable::Message.delete_all
# Ids keep counting across runs; report them relative to the last one before this run.
base = SolidCable::Message.connection.select_value("SELECT MAX(id) FROM solid_cable_messages").to_i
base = SolidCable::Message.insert({ created_at: Time.current, channel: "base", payload: "base", channel_hash: 0 }).rows.dig(0, 0) || base
pubsub = ActionCable.server.pubsub
listener = ActionCable::SubscriptionAdapter::SolidCable.const_get(:Listener)
  .new(pubsub, Concurrent::ImmediateExecutor.new)
listener.shutdown
# One iteration of the listener's own loop: `interruptible` just yields (no semaphore), and the sleep that ends the
# iteration throws out of `listen`. The same stubs on both sides; the poll itself runs unchanged.
def listener.interruptible = yield
def listener.sleep(_) = throw(:polled)

received = Hash.new { |h, k| h[k] = [] }
callbacks = {}
subscribe = lambda do |name|
  callbacks[name] = ->(payload) { received[name] << payload }
  listener.add_subscriber(name, callbacks[name], nil)
end
queries = []
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  queries << [payload[:name], payload[:sql], payload[:cached] ? "cached" : "run", payload[:binds].size] unless payload[:name] == "SCHEMA"
end

step = 0
poll = lambda do |label, silence: true|
  queries.clear
  SolidCable.configuration.instance_variable_set(:@silence_polling, silence)
  catch(:polled) { listener.send(:listen) }
  channels = listener.send(:channels)
  relative = ->(id) { id.zero? ? 0 : id - base }
  state = { step: step += 1, label: label, last_id: relative.(listener.send(:last_id)),
    channels: channels.keys.sort.map { [_1, relative.(channels[_1])] }, received: received.sort.to_h, sql: queries }
  puts JSON.generate(state)
end
broadcast = ->(name, payload) { SolidCable::Message.broadcast(name, payload) }

subscribe.("cards")
subscribe.("boards")
poll.("idle, two channels")
broadcast.("cards", "c1")
poll.("one message")
broadcast.("boards", "b1")
broadcast.("cards", "c2")
broadcast.("unsubscribed", "u1")
poll.("three messages, one unsubscribed", silence: false)
subscribe.("late")
broadcast.("late", "l1")
poll.("late subscriber")
SolidCable::Message.broadcast_batch(5.times.map { SolidCable::BatchedBroadcaster::Message.new(channel: %w[cards boards late][_1 % 3], payload: "batch #{_1}") })
poll.("batch of five")
listener.remove_subscriber("boards", callbacks["boards"])
broadcast.("boards", "b2")
broadcast.("cards", "c3")
poll.("after unsubscribe")
poll.("idle again")
# A poll inside an outer `cache` block, as it would run if called from code that enabled the query cache itself.
ActiveRecord::Base.cache do
  SolidCable::Message.cache do
    broadcast.("cards", "c4")
    poll.("inside an outer cache block")
    poll.("inside an outer cache block, idle")
  end
end
200.times { |i| subscribe.("stream-#{i}") }
broadcast.("stream-7", "s7")
poll.("202 channels")
