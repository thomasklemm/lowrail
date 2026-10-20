# frozen_string_literal: true

# Exercise real corpus readers, not a synthetic reflection added for a hit.
# From the app: ruby --yjit /abs/lowrail/bench/ar_cached_reader.rb
require File.expand_path("config/environment", Dir.pwd)
require "json"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT required" unless RubyVM::YJIT.enabled?

case Rails.application.class.module_parent_name
when "Campfire"
  if %w[avatar logo].include?(ENV["BENCH_READER"])
    logo = ENV["BENCH_READER"] == "logo"
    owner = (logo ? Account.first : User.active.first) or abort "run campfire_setup.rb first"
    association = owner.association(logo ? :logo_attachment : :avatar_attachment)
    name = "#{owner.class.name}##{association.reflection.name} (reset scope + read; missing attachment is valid)"
  else
    owner = Message.joins(:rich_text_body).first or abort "run campfire_setup.rb first"
    association = owner.association(:rich_text_body)
    name = "Message#rich_text_body (reset scope + read)"
  end
  read = -> {
    association.reset
    association.reset_scope
    association.reader
  }
when "Pingcrm"
  owner = User.find_by!(email: "m0-inertia@example.test").account
  name = "Account#organizations.not_trashed.order(:name).limit(10) (unlowered control)"
  read = -> { owner.organizations.not_trashed.order(:name).limit(10).to_a }
else
  abort "use the prepared Campfire or PingCRM corpus"
end

expected = read.call
abort "fixture missing" unless %w[avatar logo].include?(ENV["BENCH_READER"]) || (expected && (!expected.respond_to?(:empty?) || !expected.empty?))
ActiveRecord::Base.uncached do
  1_000.times { read.call }
  GC.start
  hits = PassProbe.counts if defined?(PassProbe)
  count = 0
  objects = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = started + Float(ENV.fetch("BENCH_SECONDS", "3"))
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    read.call
    count += 1
  end
  rows = [{ route: name, calls: count,
    us_per_req: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1e6 / count,
    allocs_per_req: (GC.stat(:total_allocated_objects) - objects).fdiv(count) }]
  rows.first.merge!(PassProbe.sample(count, hits)) if defined?(PassProbe)
  File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(rows))
  puts JSON.pretty_generate(rows)
end
