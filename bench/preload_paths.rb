# frozen_string_literal: true

# Campfire preload microbenchmarks, production fixtures, Ruby +YJIT.
# Run inside .corpus/campfire; use bench/preload_runs.rb for interleaving.
require File.expand_path("config/environment", Dir.pwd)
require "json"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT is required" unless RubyVM::YJIT.enabled?

loaded = Message.order(:id).limit(10).preload(creator: :avatar_attachment).to_a
cases = {
  "creator_query" => -> { Message.order(:id).limit(10).preload(creator: :avatar_attachment).to_a },
  "presentation_query" => -> { Message.with_presentation.order(:id).limit(10).to_a },
  "already_loaded_creator" => -> { ActiveRecord::Associations::Preloader.new(records: loaded, associations: { creator: :avatar_attachment }).call },
  "account_first_control" => -> { Account.first }
}
seconds = Float(ENV.fetch("BENCH_SECONDS", "3"))
results = cases.map do |name, block|
  200.times { block.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  n = 0
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = started + seconds
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    block.call
    n += 1
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  { route: name, us_per_req: elapsed / n * 1e6,
    allocs_per_req: (GC.stat(:total_allocated_objects) - before).fdiv(n) }
end
puts JSON.pretty_generate(results)
File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(results))
