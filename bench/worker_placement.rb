# frozen_string_literal: true

# Untimed Linux scheduler observations. Never infer zero migrations from a
# missing proc field, CPU equality, or context-switch counters.
module WorkerPlacement
  def self.snapshot
    threads = Dir["/proc/self/task/[0-9]*"].sort.to_h do |path|
      tid = File.basename(path)
      begin
        stat = File.read("#{path}/stat").rpartition(") ").last.split
        status = File.read("#{path}/status")
        migrations = begin
          text = File.read("#{path}/sched")
          value = text[/^\s*(?:se\.)?nr_migrations\s*:\s*(\d+)/, 1]
          value ? {"count" => Integer(value)} : {"unavailable" => "proc sched has no nr_migrations field"}
        rescue SystemCallError => error
          {"unavailable" => error.class.name}
        end
        [tid, {"birth_ticks" => Integer(stat.fetch(19)), "cpu" => Integer(stat.fetch(36)),
          "allowed_cpus" => status[/^Cpus_allowed_list:\s*([^\n]+)/, 1], "migrations" => migrations}]
      rescue SystemCallError, IndexError, ArgumentError => error
        [tid, {"unavailable" => error.class.name}]
      end
    end
    {"pid" => Process.pid, "threads" => threads,
      "unavailable" => threads.empty? ? "Linux proc task information unavailable" : nil}
  end

  # Compute after every worker exits, outside every counted window. A process
  # envelope includes boot/GC/idle work; a window envelope brackets start/finish
  # client requests. Neither is an exact scheduler or instruction-time trace.
  def self.overlaps!(workers)
    workers.each do |name, worker|
      worker.fetch("windows").each do |window|
        placement = window["placement"]
        next unless placement
        start, finish = placement.fetch("counter_envelope_ns")
        peers, windows = [], []
        workers.each do |other, peer|
          next if other == name
          if (bounds = peer["process_envelope_ns"])
            overlap = [finish, bounds.last].min - [start, bounds.first].max
            peers << {"worker" => other, "overlap_ns" => overlap} if overlap.positive?
          end
          peer.fetch("windows").each_with_index do |entry, i|
            bounds = entry.dig("placement", "counter_envelope_ns")
            next unless bounds
            overlap = [finish, bounds.last].min - [start, bounds.first].max
            windows << {"worker" => other, "window" => i, "overlap_ns" => overlap} if overlap.positive?
          end
        end
        placement["peer_processes"] = peers
        placement["peer_windows"] = windows
        before, after = placement.values_at("before", "after").map { _1.fetch("threads") }
        placement["thread_migrations"] = (before.keys | after.keys).to_h do |tid|
          a, b = before[tid], after[tid]
          delta = if a && b && a["birth_ticks"] && a["birth_ticks"] == b["birth_ticks"] &&
              a.dig("migrations", "count") && b.dig("migrations", "count")
            b.fetch("migrations").fetch("count") - a.fetch("migrations").fetch("count")
          end
          [tid, {"count" => delta && delta >= 0 ? delta : nil,
            "unavailable" => delta && delta >= 0 ? nil : "missing/reused/transient thread or unavailable migration counter"}]
        end
      end
    end
  end
end
