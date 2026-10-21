# frozen_string_literal: true

module BlogProduction
  # Terminal, untimed boundary for this closed Rack worker, never a runtime
  # feature. No more requests may run afterwards. A quiet queue is not a drain.
  class Completion
    DEADLINE_SECONDS = 2.0
    SOURCES = {
      "actioncable:lib/action_cable.rb" => "ff9b2a44d4e088bbb19455386619da308a17d44df98cdb827572a7da0aa9247b",
      "actioncable:lib/action_cable/server/base.rb" => "f427cc28f1770ee0ee55a8e5aaf024cde517b00ff564054be37155c5bd341d54",
      "solid_cable:lib/action_cable/subscription_adapter/solid_cable.rb" => "9ad4ab7bad574fc1b5f53396a6563f5a7a70d74b2ed6cffcf3b61e3d2b719499",
      "solid_cable:lib/solid_cable/batched_broadcaster.rb" => "7456a1b0e79d467ecd9bfa99df8375564f246af0ac441053c78d35a0d8754eb0",
      "solid_cable:lib/solid_cable/trimming.rb" => "ecfe9b44ad2d28c55a95d3c1d83d53354e46199cfcb0f65eaac58e5350f2a84b",
      "solid_queue:lib/active_job/queue_adapters/solid_queue_adapter.rb" => "bc0667666abf9d7fe0432bf2657d05bfefc66ddf9cec177236a43493212aa288"
    }.freeze

    attr_reader :reported_errors

    def initialize(root = Dir.pwd)
      @root = root
      @reported_errors = []
    end

    # Solid Cable rescues writer/trim errors into Rails.error. Joining that
    # thread must not turn a swallowed failure into successful completion.
    def report(error, handled:, severity:, context:, source:)
      reported_errors << {"class" => error.class.name, "message" => error.message,
        "handled" => handled, "severity" => severity.to_s, "source" => source}
    end

    def finish(deadline_seconds: DEADLINE_SECONDS)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = {"status" => "refused", "deadline_seconds" => deadline_seconds, "reasons" => []}
      if deadline_seconds.positive?
        # Bound the entire operation, including SQLite lock waits. Do not use
        # Timeout, interrupt a DB transaction, kill a thread, or drop work.
        task = Thread.new do
          Thread.current.report_on_exception = false
          begin
            drain
          rescue StandardError, ScriptError => error
            {"reasons" => ["#{error.class}: #{error.message}"]}
          end
        end
        remaining = deadline_seconds - (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
        if remaining.positive? && task.join(remaining)
          result.merge!(task.value)
        else
          result["reasons"] << "async completion deadline exceeded; work not interrupted, no completed snapshot"
        end
      else
        result["reasons"] << "async completion deadline exceeded; no completed snapshot"
      end
      result["reported_errors"] = reported_errors.dup
      result["reasons"] << "Rails.error reported an application/background failure" if reported_errors.any?
      result["status"] = "completed" if result.fetch("reasons").empty?
      result
    end

    def drain
      sources = SOURCES.to_h { |key, _| [key, Digest::SHA256.file(Entropy.source_path(key)).hexdigest] }
      raise "unsupported async completion source inventory" unless sources == SOURCES
      reasons = []
      # Read existing ivars only: ActionCable.server/pubsub would instantiate
      # components that a read-only request may never have used.
      server = Lowrail.loaded_constant("ActionCable")&.instance_variable_get(:@server)
      adapter = server&.instance_variable_get(:@pubsub)
      cable = "not_started"
      if adapter
        raise "unsupported Cable adapter #{adapter.class.name}" unless adapter.class.name == "ActionCable::SubscriptionAdapter::SolidCable"
        reasons << "Cable listener/subscriber delivery is not certified by the writer drain" if adapter.instance_variable_get(:@listener)
        broadcaster = adapter.instance_variable_get(:@broadcaster)
        if broadcaster
          # Public terminal shutdown closes the input queue, joins the writer
          # (including an in-flight batch), then joins accepted trim work.
          broadcaster.shutdown
          cable = "writer_and_accepted_trims_joined"
        end
      end
      if server && (server.instance_variable_get(:@worker_pool) || server.instance_variable_get(:@event_loop))
        reasons << "Cable connection worker/event loop completion is not certified"
      end
      job_adapter = Lowrail.loaded_constant("ActiveJob::Base")&._queue_adapter
      if job_adapter && job_adapter.class.name != "ActiveJob::QueueAdapters::SolidQueueAdapter"
        reasons << "unsupported ActiveJob adapter #{job_adapter.class.name}; delayed/recursive work not certified"
      end
      # This harness has no queue supervisor. Inspect the closed-world queue
      # with a separate read-only connection, not model/schema warm-up, fake
      # execution, adapter replacement, discard or a queue-empty sleep heuristic.
      require "sqlite3"
      queue = SQLite3::Database.new(File.join(@root, "storage/production_queue.sqlite3"), readonly: true)
      begin
        pending = queue.execute("SELECT id, class_name FROM solid_queue_jobs WHERE finished_at IS NULL ORDER BY id")
        states = %w[ready claimed scheduled blocked failed batch].to_h do |state|
          [state, queue.get_first_value("SELECT COUNT(*) FROM solid_queue_#{state}_executions")]
        end
        processes = queue.get_first_value("SELECT COUNT(*) FROM solid_queue_processes")
        reasons << "Solid Queue jobs unfinished; no supervisor in Rack worker" if pending.any? || states.values.any?(&:positive?)
        reasons << "external Solid Queue processes are outside this boundary" if processes.positive?
      ensure
        queue.close
      end
      {"reasons" => reasons, "sources" => sources, "cable" => cable,
        "job_adapter" => job_adapter&.class&.name, "pending_jobs" => pending,
        "queue_states" => states, "queue_processes" => processes}
    end
  end
end
