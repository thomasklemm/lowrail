# frozen_string_literal: true

# Named bench completion boundary for Solid Cable 3.0.5. NOT the blog's 4.1.0
# writer-drain certificate: 3.0.5 broadcast + TrimJob.perform_now are synchronous.
require_relative "../../fixtures/corpus/blog_production"

class FizzyLinkCompletion305 < BlogProduction::Completion
  SOURCES = {
    "actioncable:lib/action_cable.rb" => "ff9b2a44d4e088bbb19455386619da308a17d44df98cdb827572a7da0aa9247b",
    "actioncable:lib/action_cable/server/base.rb" => "f427cc28f1770ee0ee55a8e5aaf024cde517b00ff564054be37155c5bd341d54",
    "actioncable:lib/action_cable/server/broadcasting.rb" => "480b4b5afd2a5770ce3b98e6c3115cd52e0445a42860ec840552706f00cf74a3",
    "actioncable:lib/action_cable/server/connections.rb" => "33e315222519b6fe9d66e723811b1075bc7b3f272588a5ad3a5b99d6c4daa0f6",
    "solid_cable:lib/action_cable/subscription_adapter/solid_cable.rb" => "5e0cb7e8f836413185263d77801a62196b49b0df528d1e1600a3d3b7320aa205",
    "solid_cable:lib/solid_cable.rb" => "3d96c86f755129a7e0bd56ea578235b3a5950e6c2e0a0f8255237e43e306e1b0",
    "solid_cable:app/models/solid_cable/message.rb" => "2e72e6816964caca2234ab7c84c276163c3f6aeaf761e295e45b72b077d16984",
    "solid_cable:app/jobs/solid_cable/trim_job.rb" => "b200f8590f8f1f1a88be9030dc435ebf83e0fa4dc6360a396e808a9898246e2d",
    "activejob:lib/active_job/execution.rb" => "4f59c2db707c74ef937cc033a5f1179a9d52951b09484e422681be203fd8cbda",
    "solid_queue:lib/active_job/queue_adapters/solid_queue_adapter.rb" => "c0638271d7d1d51d2b5e67c48e41f68d621bd507a0e7463f6cda01f55ed10bbe"
  }.freeze

  def drain
    versions = %w[actioncable solid_cable solid_queue].to_h { [_1, Gem.loaded_specs.fetch(_1).version.to_s] }
    raise "unsupported completion versions" unless versions == {"actioncable" => "8.1.4", "solid_cable" => "3.0.5", "solid_queue" => "1.1.2"}
    sources = SOURCES.to_h { |key, _| [key, Digest::SHA256.file(BlogProduction::Entropy.source_path(key)).hexdigest] }
    raise "unsupported 3.0.5 completion source inventory" unless sources == SOURCES
    reasons = []
    server = Lowrail.loaded_constant("ActionCable")&.instance_variable_get(:@server)
    adapter = server&.instance_variable_get(:@pubsub)
    if adapter
      reasons << "unsupported Cable adapter" unless adapter.class.name == "ActionCable::SubscriptionAdapter::SolidCable"
      reasons << "existing Cable listener is outside synchronous completion" if adapter.instance_variable_get(:@listener)
    end
    if server && %i[@worker_pool @event_loop @heartbeat_timer].any? { server.instance_variable_get(_1) }
      reasons << "existing Cable worker/event-loop/heartbeat is outside synchronous completion"
    end
    job_adapter = Lowrail.loaded_constant("ActiveJob::Base")&._queue_adapter
    reasons << "unsupported job adapter" if job_adapter && job_adapter.class.name != "ActiveJob::QueueAdapters::SolidQueueAdapter"
    require "sqlite3"
    queue = SQLite3::Database.new(File.join(@root, "queue.sqlite3"), readonly: true)
    begin
      pending = queue.execute("SELECT id,class_name FROM solid_queue_jobs WHERE finished_at IS NULL ORDER BY id")
      states = %w[ready claimed scheduled blocked failed].to_h do |state|
        [state, queue.get_first_value("SELECT COUNT(*) FROM solid_queue_#{state}_executions")]
      end
      processes = queue.get_first_value("SELECT COUNT(*) FROM solid_queue_processes")
      reasons << "unfinished Solid Queue work; no supervisor in Rack fixture" if pending.any? || states.values.any?(&:positive?)
      reasons << "external queue process outside completion boundary" if processes.positive?
    ensure
      queue.close
    end
    {"adapter" => "fizzy-solid-cable-3.0.5-synchronous-v1", "reasons" => reasons,
      "versions" => versions, "sources" => sources, "pending_jobs" => pending,
      "queue_states" => states, "queue_processes" => processes,
      "cable" => adapter ? "synchronous_broadcast_only" : "not_started"}
  end
end
