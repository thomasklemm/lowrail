# frozen_string_literal: true

require "digest"
require "json"

# Opt-in screen instrumentation, never installed by the ordinary benchmark.
# Cache/reaper callbacks are charged equally to all arms. Large snapshots and
# loaded-feature enumeration stay outside allocation/instruction endpoints.
module ScreenClock
  def self.install(epoch)
    raise "clock already installed" if @epoch
    @epoch = Integer(epoch)
    Time.singleton_class.prepend(Clock)
  end

  def self.epoch = @epoch

  module Clock
    def now(**options)
      Time.at(ScreenClock.epoch, **options)
    end
  end
end

class WindowAudit
  attr_reader :events
  attr_writer :cache

  class << self
    attr_accessor :active
  end

  module Reaper
    def reap
      WindowAudit.active&.record("connection_pool.reap")
      super
    end

    def flush(*args)
      WindowAudit.active&.record("connection_pool.flush")
      super
    end
  end

  def initialize(cache:)
    @cache = cache
    @events = Hash.new(0)
    @active = false
    @subscription = ActiveSupport::Notifications.monotonic_subscribe(/\Acache_.*\.active_support\z/) do |name, _, _, _, payload|
      if @active
        # Hash the key: cache keys can carry private user/tenant data.
        key = Digest::SHA256.hexdigest(payload[:key].to_s)
        @events[[name, key, payload[:hit]].join("/")] += 1
      end
    end
  end

  def record(event)
    @events[event] += 1 if @active
  end

  # Rails' own maintenance lock; no pool/config changes or killed threads.
  # This is a synchronous request screen, not a background-maintenance price.
  def with_reapers_deferred
    pools = ActiveRecord::Base.connection_handler.connection_pool_list(:all)
    @reaper_control = {"kind" => "pool_reaper_locks", "pools" => pools.size,
      "scope" => "asynchronous maintenance deferred outside request windows"}
    locked = pools.reverse.reduce(-> { yield }) do |inner, pool|
      -> { pool.reaper_lock(&inner) }
    end
    locked.call
  end

  def cache_snapshot
    if @cache.class.name == "ActiveSupport::Cache::FileStore"
      root = @cache.instance_variable_get(:@cache_path).chomp("/")
      files = Dir[File.join(root, "**/*")].select { File.file?(_1) }.sort.to_h do |path|
        [path.delete_prefix(root + "/"), Digest::SHA256.file(path).hexdigest]
      end
      {"kind" => "file_bytes", "files" => files, "sha256" => Digest::SHA256.hexdigest(JSON.generate(files))}
    elsif @cache.class.name == "ActiveSupport::Cache::NullStore"
      {"kind" => "null_store"}
    else
      {"kind" => @cache.class.name, "unavailable" => "no byte-level snapshot adapter; event mix only"}
    end
  end

  def before(window)
    @events.clear
    window[:background] = {"cache_before" => cache_snapshot, "epoch" => ScreenClock.epoch,
      "reaper_control" => @reaper_control}
    window[:coverage_before] = NativeBench.counts if ENV["SCREEN_COVERAGE"] == "1"
    @features = $LOADED_FEATURES.dup
    WindowAudit.active = self
    @active = true
  end

  def after(window)
    @active = false
    WindowAudit.active = nil
    window.fetch(:background).merge!("cache_after" => cache_snapshot, "events" => @events.dup,
      "lazy_loads" => $LOADED_FEATURES - @features,
      "gc" => %i[minor_gc_count major_gc_count].to_h { [_1, window.fetch(:after).fetch(_1) - window.fetch(:before).fetch(_1)] })
    window[:coverage_after] = NativeBench.counts if ENV["SCREEN_COVERAGE"] == "1"
  end

  def close
    ActiveSupport::Notifications.unsubscribe(@subscription)
  end
end
