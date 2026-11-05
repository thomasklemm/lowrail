# Control preload (RUBYOPT=-r.../freeze.rb, loaded after cg_harness.rb defines
# run_benchmark): freezes the clock with ActiveSupport's travel_to for the
# whole benchmark run, at FREEZE_AT (default 2026-07-01 12:00 UTC).
module FreezeClock
  def run_benchmark(*args, **kw, &block)
    require "active_support/testing/time_helpers"
    extend ActiveSupport::Testing::TimeHelpers
    travel_to(Time.utc(*ENV.fetch("FREEZE_AT", "2026-07-01-12").split("-").map(&:to_i))) { super }
  end
end
Object.prepend(FreezeClock)
