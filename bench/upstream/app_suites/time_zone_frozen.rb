# RAILS=path ruby time_zone_frozen.rb -> exit 1 if a TimeZone can't be stubbed (rspec-mocks' allow(Time.zone).to receive(:now))
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "activesupport", path: "#{ENV.fetch("RAILS")}/activesupport"
end
require "active_support"
require "active_support/time"

zone = ActiveSupport::TimeZone["UTC"]
begin
  zone.define_singleton_method(:now) { Time.utc(2022, 3, 15, 11) }
  puts "frozen: #{zone.frozen?}, stubbed now: #{zone.now}"
  exit 0
rescue FrozenError => e
  puts "frozen: #{zone.frozen?}, #{e.class}: #{e.message[0, 60]}"
  exit 1
end
