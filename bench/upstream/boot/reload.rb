# frozen_string_literal: true

# Development-mode reload pass: boot in development, warm one page, change one
# app file, then time and profile the next request (the reload plus the work
# it makes lazy again), against the same request without a change.
#   ruby reload.rb APP FILE OUT_JSON      (FILE relative to the app root)
# Run in a disposable census copy with the census env, RAILS_ENV=development.
# FILE gets one appended comment line, which is removed again at exit.
kind_app, file, out = ARGV
abort "usage: reload.rb APP FILE OUT_JSON" unless out
raise "fresh output required" if File.exist?(out)
$LOAD_PATH.unshift(Dir[File.join(Gem.default_dir, "gems/stackprof-0.2.28/lib")].first || abort("stackprof 0.2.28 not installed"))
require "stackprof"
require "bundler/setup"
require_relative "probe_paths"
require_relative "../rails_main_census_4"

ENV.update("RAILS_ENV" => "development", "RACK_ENV" => "development", "LOWRAIL" => "0")
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
require File.expand_path("config/application")
# As the census harness does: the JIT is the run's mode, not the app's config.yjit.
Rails.application.config.yjit = ENV.fetch("CENSUS_MODE", "interpreter") == "yjit"
require File.expand_path("config/environment")
booted = Process.clock_gettime(Process::CLOCK_MONOTONIC)
raise "reloading is off" unless Rails.application.config.enable_reloading
raise "#{file} missing" unless File.exist?(file)
Rails.application.config.hosts.clear
Rails.logger.level = :fatal
ActiveRecord::Base.logger = nil

path, headers = BootPaths::PATHS.fetch(kind_app)
client = RailsMainCensus4::Client.new
get = -> { client.get(path, headers: headers || {}, expect: [200]) }
clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
time = ->(&blk) { t = clock.(); blk.call; ((clock.() - t) * 1000).round(1) }

first = time.() { get.() }
warm = 5.times.map { time.() { get.() } }
original = File.read(file)
at_exit { File.write(file, original) }
results = []
3.times do |i|
  # A real edit: the watcher sees a new mtime and content; sleep past mtime granularity.
  sleep 1.1
  File.write(file, original + "\n# reload probe #{i}\n")
  # The evented watcher (listen) notices asynchronously; wait until a reloader sees the change.
  deadline = clock.() + 10
  sleep 0.05 until Rails.application.reloaders.any?(&:updated?) || clock.() > deadline
  raise "change to #{file} not detected" unless Rails.application.reloaders.any?(&:updated?)
  objects = GC.stat(:total_allocated_objects)
  StackProf.start(mode: :wall, interval: 250, raw: true) if i == 2
  ms = time.() { get.() }
  profile = (StackProf.stop; StackProf.results) if i == 2
  results << { ms:, objects: GC.stat(:total_allocated_objects) - objects }
  after = time.() { get.() }
  results.last[:next_ms] = after
  if profile
    frames = profile[:frames].transform_values { [_1[:name], _1[:file], _1[:line]] }
    raw = profile[:raw]
    stacks = []
    j = 0
    while j < raw.size
      len = raw[j]
      stacks << [raw[j + 1, len], raw[j + 1 + len]]
      j += len + 2
    end
    results.last[:profile] = { mode: profile[:mode], interval: profile[:interval], samples: profile[:samples], frames:, stacks: }
  end
end
result = { app: kind_app, file:, ruby: RUBY_DESCRIPTION, boot_ms: ((booted - started) * 1000).round, first_ms: first,
  warm_ms: warm, reloads: results.map { _1.except(:profile) },
  watcher: Rails.application.config.file_watcher.name }
File.write(out, JSON.generate(result.merge(app: kind_app, profile: results.last[:profile])) + "\n")
puts JSON.generate(result)
