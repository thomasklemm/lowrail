# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/cache"
require "active_support/notifications"
require_relative "window_audit"
load File.expand_path("../script/screen", __dir__)
require_relative "screen"

class ScreenTest < Minitest::Test
  def test_prospective_aa_rule_distinguishes_positive_negative_and_either_failed_metric
    [0.07, -0.07, 0.11, -0.11].each do |delta|
      %w[instructions_total instructions_no_gc].each do |changed|
        base = {"instructions_total" => 10_000.0, "instructions_no_gc" => 9_000.0, "allocations" => 53.0}
        control = base.merge(changed => base.fetch(changed) * (1 + delta / 100))
        rows = Array.new(6) { {"off_a" => base, "off_b" => control, "on" => base.transform_values { _1 * 0.9 }} }
        result = ScreenPlatform.summarize(rows)
        assert_equal delta.abs < 0.1, result.fetch(:aa).fetch(:pass), [delta, changed].inspect
        assert_in_delta(-10, result.fetch(:layers).fetch("on").fetch(changed).fetch(:delta_pct).fetch(:median), 1e-9)
        assert_in_delta(-base.fetch(changed) / 10, result.fetch(:layers).fetch("on").fetch(changed).fetch(:delta).fetch(:median), 1e-9)
        refute RequestPairs.summarize(rows, seed: 41231, tolerance: 0.1,
          metrics: ScreenPlatform::METRICS, controls: ScreenPlatform::CONTROLS).fetch(:aa).fetch(:pass)
      end
    end
  end

  def test_actual_cache_events_detect_regeneration_and_same_size_byte_replacement
    Dir.mktmpdir do |dir|
      cache = ActiveSupport::Cache::FileStore.new(dir)
      cache.write("story", "first", expires_in: 60)
      audit = WindowAudit.new(cache: cache)
      cache.fetch("story") # Exercise the observer's real hit signature too.
      observe = ->(&block) {
        window = {unit: "GET /story", mode: "total", requests: 1, before: GC.stat, after: GC.stat}
        audit.before(window)
        block.call
        GC.stat(window.fetch(:after))
        audit.after(window)
        JSON.parse(JSON.generate(window))
      }
      hit = observe.call { assert_equal "first", cache.fetch("story") { flunk "unexpected regeneration" } }
      workers = %w[off_a off_b on].to_h { ["0-#{_1}", {"windows" => [hit]}] }
      assert ScreenPlatform.background(workers).fetch(:pass)
      %w[connection_pool.reap cache_generate.active_support].each do |event|
        different = Marshal.load(Marshal.dump(hit))
        different.fetch("background").fetch("events")[event] = 1
        workers["0-off_b"] = {"windows" => [different]}
        refute ScreenPlatform.background(workers).fetch(:pass)
      end
      unsupported = Marshal.load(Marshal.dump(hit))
      %w[cache_before cache_after].each do |endpoint|
        unsupported.fetch("background")[endpoint] = {"kind" => "OtherStore", "unavailable" => "no adapter"}
      end
      unknown_workers = %w[off_a off_b on].to_h { ["0-#{_1}", {"windows" => [unsupported]}] }
      refute ScreenPlatform.background(unknown_workers).fetch(:pass)
      changed = observe.call { cache.write("story", "other", expires_in: 60) }
      workers["0-off_b"] = {"windows" => [changed]}
      refute ScreenPlatform.background(workers).fetch(:pass)
      refute_equal changed.fetch("background").fetch("cache_before"), changed.fetch("background").fetch("cache_after")
      cache.delete("story")
      regenerated = observe.call { cache.fetch("story", expires_in: 60) { "again" } }
      assert regenerated.fetch("background").fetch("events").keys.any? { _1.start_with?("cache_generate.") }
      audit.close
    end
  end

  def test_clock_preserves_ttl_and_independent_graphs_across_real_elapsed_time
    program = <<~'RUBY'
      require "active_support"
      require "active_support/cache"
      require "tmpdir"
      require ARGV.fetch(0)
      ScreenClock.install(1767312000)
      Dir.mktmpdir do |dir|
        cache = ActiveSupport::Cache::FileStore.new(dir)
        cache.write("story", ["original"], expires_in: 0.01)
        first = cache.read("story")
        first[0].replace("mutation")
        sleep 0.03
        raise "TTL or mutable value changed" unless cache.read("story") == ["original"]
        entry = cache.send(:read_entry, cache.send(:normalize_key, "story", {}))
        raise "wrong remaining TTL" unless (entry.expires_at - Time.now.to_f - 0.01).abs < 0.0001
        raise "timezone option lost" unless Time.now(in: "+03:00").utc_offset == 10800
        puts "fixed TTL; independent values; timezone preserved"
      end
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-e", program, File.expand_path("window_audit.rb", __dir__))
    assert status.success?, output
    assert_includes output, "fixed TTL; independent values; timezone preserved"
  end
end
