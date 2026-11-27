# frozen_string_literal: true

# SCB1 body numbers: one solid_cable listener poll as the listener thread runs it (`listen` for one iteration: an executor
# run, the poll with polling logs silenced), with 20 subscribed streams, idle and with one new message. For script/upstream-bench with
# --gems solid_cable and the released Rails gems via --with.
require "rails"
require "active_record/railtie"
require "action_cable/engine"
require "solid_cable"
require "tmpdir"
require "logger"

db = File.join(Dir.mktmpdir("sc1"), "cable.sqlite3")
class SC1App < Rails::Application
  config.eager_load = false
  config.logger = ActiveSupport::Logger.new(IO::NULL)
  config.secret_key_base = "x" * 64
end
Rails.application.config.paths.add "config/database", with: File.join(Dir.mktmpdir("sc1"), "database.yml")
File.write(Rails.application.config.paths["config/database"].first, "test:\n  adapter: sqlite3\n  database: #{db}\n")
Rails.env = "test"
SolidCable.configure(polling_interval: "0.1.seconds", silence_polling: true, message_retention: "1.day")
Rails.application.initialize!
ActiveRecord::Base.logger = ActiveSupport::Logger.new(IO::NULL)
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :solid_cable_messages do |t|
    t.binary :channel, null: false, limit: 1024
    t.binary :payload, null: false, limit: 536_870_912
    t.datetime :created_at, null: false
    t.integer :channel_hash, null: false, limit: 8
    t.index :channel
    t.index :channel_hash
    t.index :created_at
  end
end

server = ActionCable::Server::Base.new
adapter = ActionCable::SubscriptionAdapter::SolidCable.new(server)
listener = ActionCable::SubscriptionAdapter::SolidCable.const_get(:Listener).new(adapter, Concurrent::ImmediateExecutor.new)
listener.shutdown
streams = 20.times.map { |i| "Z2lkOi8vYXBwL0NhcmQv#{i}" }
delivered = 0
streams.each { |s| listener.add_subscriber(s, ->(_) { delivered += 1 }, nil) }
payload = %("<turbo-stream action=\\"replace\\" target=\\"card_1\\"><template>#{"<p>Renewal date is stale</p>" * 30}</template></turbo-stream>")

# One iteration of the listener's own loop: `interruptible` just yields (no semaphore), and the sleep that ends the
# iteration throws out of `listen`. The same stubs on both sides; the poll itself runs unchanged.
def listener.interruptible = yield
def listener.sleep(_) = throw(:polled)
poll = -> { catch(:polled) { listener.send(:listen) } }
poll.call

UpstreamBench.report("listener poll, idle") { poll.call }
UpstreamBench.report("listener poll, one message") do
  SolidCable::Message.broadcast(streams[3], payload)
  poll.call
end
