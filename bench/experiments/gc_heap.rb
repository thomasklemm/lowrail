# frozen_string_literal: true

# Bet J measurement only. Invoked through script/rps's existing external Puma
# hook, identically in off-A/on/off-B. Never changes the application's config.
module NativeRps::PumaSetup
  def self.configure(puma:, config:, arm:)
    puma.before_worker_boot do
      snapshot = {"pid" => Process.pid, "gc" => GC.stat, "heaps" => GC.stat_heap,
        "latest_gc" => GC.latest_gc_info, "monotonic_s" => NativeBench.clock,
        "rss" => NativeBench.rss, "config" => GC.config}
      NativeRps.write(File.join(File.dirname(ENV.fetch("PIDFILE")), "worker-boot-#{Process.pid}.json"), snapshot)
    end
  end
end
