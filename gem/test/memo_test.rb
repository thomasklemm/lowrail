# frozen_string_literal: true

require_relative "test_helper"

class MemoTest < Minitest::Test
  include LowrailTest

  PRELUDE = <<~'RUBY'
    # Isolated runtime-unit fixture, explicitly accepting the production tier.
    ENV["RAILS_ENV"] = "production"
    ENV["LOWRAIL_SEALED"] = "1"
    require "json"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    require "lowrail/memo"
    require "lowrail/memo_facts"
    require "lowrail/stats"
    Lowrail::Stats.enable!
    cert = Lowrail::MemoFacts.build
    raise cert.fetch("decline") if cert["decline"]
    unit = { "id" => 0, "kind" => "file", "file" => "/memo.rb", "pass" => "memo/uri_join",
      "facts" => cert.fetch("facts"), "memo" => cert }
    manifest = Lowrail::Manifest.new({ "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
      "compile_option" => "", "files" => {}, "units" => [unit],
      "tier" => "sealed-v1", "rails_env" => "production" }, "/tmp")
    Lowrail::Guard.install(manifest, Lowrail::Stats::STATE)
    Lowrail::Passes::Memo.install(manifest.units)
    def joined(base, relative)
      Lowrail::Memo.join(0, URI, base, relative) { |r, b, u| r.join(b, u) }
    end
    def outcome
      uri = yield
      [uri.class.name, uri.to_s, uri.instance_variables.to_h { |n|
        v = uri.instance_variable_get(n)
        [n, v.is_a?(String) ? [v, v.encoding.name, v.frozen?] : v]
      }]
    rescue StandardError => e
      [e.class.name, e.message]
    end
  RUBY

  def test_keys_fresh_returns_errors_and_guarded_fallback
    out = ruby_json(PRELUDE + <<~'RUBY')
      base = +"https://one.test:444/a/b"
      url = +"../assets/first.js?x=2#fragment"
      original = outcome { URI.join(base, url) }
      first = joined(base, url)
      first.path.replace("/poison")
      first.host.replace("poison.test")
      first.query.replace("poison")
      first.freeze
      raise "changed inputs" unless base == "https://one.test:444/a/b" && url == "../assets/first.js?x=2#fragment"
      raise "shared return" unless outcome { joined(base, url) } == original
      raise "wrong host key" unless joined("http://two.test:8080/root/", url).host == "two.test"
      url.replace("/assets/other.js")
      raise "mutable key" unless joined(base, url).path == "/assets/other.js"
      raise "old key poisoned" unless joined(base, "../assets/first.js?x=2#fragment").path == "/assets/first.js"
      # Force the thread turns possible before/after the intrinsic returns.
      %i[before after].product(%i[bytes encoding]).each do |turn, change|
        saved = "/during-#{turn}-#{change}"
        input = saved.dup
        other = change == :bytes ? "/replacement-#{turn}" : saved.dup.force_encoding(Encoding::US_ASCII)
        expected = outcome { URI.join(base, saved) }
        ready, done = Queue.new, Queue.new
        worker = Thread.new { ready.pop; input.replace(other); done << true }
        actual = outcome do
          Lowrail::Memo.join(0, URI, base, input) do |r,b,u|
            if turn == :before
              ready << true
              done.pop
            end
            value = r.join(b,u)
            if turn == :after
              ready << true
              done.pop
            end
            value
          end
        end
        worker.join
        raise "changed during URI computation: #{turn}/#{change}" unless actual == expected
        2.times do
          raise "old URI key poisoned" unless outcome { joined(base, saved) } == expected
          raise "new URI key poisoned" unless outcome { joined(base, other) } == outcome { URI.join(base, other) }
        end
      end
      cases = ["", "?q=x y", "#f", "//cdn.test:99/assets/x", "https://cdn.test/root/x", "http:opaque",
        "a/../../b", "/%ff", "mailto:x@y", "has space", "\xFF".b, nil, URI("/relative")]
      bases = ["https://a.test/a/../b/", "http://u:p@[::1]:8080/root/", "https://a.test".b]
      bases.product(cases).each do |b, r|
        expected = outcome { URI.join(b, r) }
        2.times { raise "difference: #{[b,r].inspect}" unless outcome { joined(b, r) } == expected }
      end
      # ASCII string equality ignores compatible encodings; the memo must not.
      [Encoding::US_ASCII, Encoding::UTF_8, Encoding::ASCII_8BIT].each do |enc|
        r = "/encoding".dup.force_encoding(enc)
        2.times { raise "encoding" unless outcome { joined(base, r) } == outcome { URI.join(base, r) } }
      end
      hits = Lowrail::Stats.unit_hits.fetch("0")
      # An instrumentation wrapper is observable, even if its return is stable.
      wrapper = Module.new do
        def merge(other)
          $events += 1
          super
        end
      end
      $events = 0
      URI::Generic.prepend(wrapper)
      3.times { joined(base, "/assets/other.js") }
      raise "lost events" unless $events == 3
      wrapper.send(:remove_method, :merge)
      2.times { joined(base, "/assets/other.js") }
      raise "did not recover" unless Lowrail::Stats.unit_hits.fetch("0") > hits
      old_port = URI::HTTPS::DEFAULT_PORT
      URI::HTTPS.send(:remove_const, :DEFAULT_PORT)
      URI::HTTPS.const_set(:DEFAULT_PORT, 9443)
      raise "stale config" unless joined("https://port.test", "/a").port == 9443
      URI::HTTPS.send(:remove_const, :DEFAULT_PORT)
      URI::HTTPS.const_set(:DEFAULT_PORT, old_port)
      # Encoding is a runtime key; a Ruby override must not collapse encodings.
      encoding = String.instance_method(:encoding)
      String.define_method(:encoding) { Encoding::US_ASCII }
      ["/encoding-key".dup, "/encoding-key".b].each do |r|
        actual = joined(base, r).path
        original = URI.join(base, r).path
        raise "overridden encoding collapsed keys" unless encoding.bind_call(actual) == encoding.bind_call(original)
      end
      String.define_method(:encoding, encoding)
      # A string subclass/conversion object may mutate or emit notifications.
      custom = Object.new
      def custom.to_str = ($conversions += 1; "/custom")
      def custom.instance_of?(*) = raise("must not call argument reflection overrides")
      $conversions = 0
      2.times { joined(base, custom) }
      raise "lost conversion" unless $conversions == 2
      # Same bytes and line counts do not make a stale implementation safe.
      cert["sources"].values.first["sha256"] = "0" * 64
      Lowrail::Passes::Memo.install(manifest.units)
      before = Lowrail::Stats.unit_hits.fetch("0")
      2.times { raise "fallback result" unless joined(base, "/stale").path == "/stale" }
      raise "stale source reused" unless before == Lowrail::Stats.unit_hits.fetch("0")
      puts JSON.generate({ hits: hits, events: $events, conversions: $conversions })
    RUBY
    assert_operator out.fetch("hits"), :>, 10
    assert_equal 3, out.fetch("events")
    assert_equal 2, out.fetch("conversions")
  end

  def test_build_refuses_an_existing_observable_implementation
    out = ruby_json(<<~'RUBY')
      require "json"
      require "lowrail/memo_facts"
      URI.singleton_class.prepend(Module.new do
        def join(*)
          warn "observable"
          super
        end
      end)
      puts JSON.generate(Lowrail::MemoFacts.build)
    RUBY
    assert_match(/uncertified/, out.fetch("decline"))
  end

  def test_dispatch_configuration_reflection_and_tracing_boundaries
    out = ruby_json(PRELUDE + <<~'RUBY')
      2.times { joined("http://one.test", "/x") }
      wrapper = Module.new do
        def inject(*)
          $injects += 1
          super
        end
      end
      $injects = 0
      Array.prepend(wrapper)
      3.times { joined("http://one.test", "/x") }
      raise "lost Array#inject effects" unless $injects == 3
      raise "certified observable inject" unless Lowrail::MemoFacts.build["decline"].include?("Array#inject")
      wrapper.send(:remove_method, :inject)
      2.times { joined("http://one.test", "/x") }
      URI::HTTP.class_eval do
        def instance_variables = super - [:@host]
      end
      joined("http://one.test", "/x").host.replace("poison.test")
      raise "reflection leaked mutable cache" unless joined("http://one.test", "/x").host == "one.test"
      URI::HTTP.send(:remove_method, :instance_variables)
      targeted_calls = 0
      targeted = TracePoint.new(:call) { targeted_calls += 1 }
      targeted.enable(target: URI.method(:join)) { 3.times { joined("http://one.test", "/x") } }
      raise "lost targeted trace events" unless targeted_calls == 3
      trace_calls = 0
      trace = TracePoint.new(:call) { |t| trace_calls += 1 if t.method_id == :join && t.defined_class == URI.singleton_class }
      trace.enable { 3.times { joined("http://one.test", "/x") } }
      raise "lost trace events" unless trace_calls == 3
      initial = URI.const_get(:INITIAL_SCHEMES)
      $defaults = 0
      table = Hash.new { $defaults += 1; nil }.freeze
      URI.send(:remove_const, :INITIAL_SCHEMES)
      URI.const_set(:INITIAL_SCHEMES, table)
      3.times { joined("http://one.test", "/x") }
      raise "lost hash default effects" unless $defaults == 6
      raise "certified effectful scheme table" unless Lowrail::MemoFacts.build["decline"] == "custom scheme table"
      URI.send(:remove_const, :INITIAL_SCHEMES)
      URI.const_set(:INITIAL_SCHEMES, initial)
      old = URI.const_get(:Schemes)
      replacement = Module.new
      replacement.const_set(:HTTP, URI::HTTP)
      replacement.const_set(:HTTPS, URI::HTTPS)
      %i[ReservedChars EscapedChars].each { |n| replacement.singleton_class.const_set(n, old.singleton_class.const_get(n)) }
      replacement.define_singleton_method(:escape) { |n| old.escape(n) }
      replacement.define_singleton_method(:find) { |n| $finds += 1; old.find(n) }
      2.times { joined("http://one.test", "/x") } # warm AFTER defining replacement methods
      $finds = 0
      URI.send(:remove_const, :Schemes)
      URI.const_set(:Schemes, replacement)
      3.times { joined("http://one.test", "/x") }
      raise "lost scheme module effects" unless $finds == 6
      puts JSON.generate({ injects: $injects, traces: trace_calls, defaults: $defaults, finds: $finds })
    RUBY
    assert_equal({ "injects" => 3, "traces" => 3, "defaults" => 6, "finds" => 6 }, out)
  end

  def test_passive_rspec_reporter_keeps_its_lifecycle_without_hiding_other_tracing
    skip "rspec not installed" if Gem::Specification.find_all_by_name("rspec-core").empty?
    prefix = "require 'lowrail/rspec'; Lowrail::RSpec.install('/unused-memo-report')\n"
    out = ruby_json(prefix + PRELUDE + <<~'RUBY')
      hook = Lowrail::RSpec.instance_variable_get(:@load_hook)
      2.times { joined("https://one.test", "/x") }
      raise "disabled reporter" unless hook.enabled?
      hits = Lowrail::Stats.unit_hits.fetch("0", 0)
      raise "reporter prevented memo" unless hits > 0
      2.times do |phase|
        calls = 0
        set_trace_func(proc { |event, _, _, id, _, owner| calls += 1 if event == "call" && id == :join && owner == URI })
        3.times { joined("https://one.test", "/x") }
        set_trace_func(nil)
        raise "lost legacy events in phase #{phase}: #{calls}" unless calls == 3
        2.times { joined("https://one.test", "/x") }
        require "rspec/core" if phase == 0
      end
      raise "reporter did not attach" if hook.enabled?
      raise "did not resume after attach" unless Lowrail::Stats.unit_hits.fetch("0") > hits
      # A stale passive-hook implementation invalidates the certificate too.
      cert.fetch("sources").find { |path,_| path.end_with?("/rspec.rb") }.last["sha256"] = "0" * 64
      Lowrail::Passes::Memo.install(manifest.units)
      before = Lowrail::Stats.unit_hits.fetch("0")
      2.times { joined("https://one.test", "/x") }
      raise "stale reporter certificate" unless before == Lowrail::Stats.unit_hits.fetch("0")
      puts JSON.generate({ hits: hits, reporter_disabled_after_attach: !hook.enabled? })
    RUBY
    assert_operator out.fetch("hits"), :>, 0
    assert_equal true, out.fetch("reporter_disabled_after_attach")
  end

  def test_timeouts_and_preexisting_or_later_tracing_decline_reuse
    out = ruby_json(PRELUDE + <<~'RUBY')
      calls = 0
      operation = -> { Lowrail::Memo.join(0, URI, "https://one.test", "/x") { |r,b,u| calls += 1; r.join(b,u) } }
      2.times { operation.call }
      raise "did not memoize" unless calls == 1
      Regexp.timeout = 0.1
      raise "certified timeouts" unless Lowrail::MemoFacts.build["decline"] == "regexp timeouts are observable runtime inputs"
      3.times { operation.call }
      raise "cached under timeout" unless calls == 4
      Regexp.timeout = nil
      operation.call
      raise "did not recover" unless calls == 4
      trace = TracePoint.trace(:call) {}
      trace.disable
      Lowrail::Passes::Memo.install(manifest.units)
      2.times { operation.call }
      raise "revived after tracing" unless calls == 6
      # Hooks installed in main must not raise in a foreign ractor.
      raise "foreign trace" unless Ractor.new { TracePoint.new(:call) {}.enabled? }.value == false
      puts JSON.generate({ calls: calls })
    RUBY
    assert_equal 6, out.fetch("calls")
    ["trace = TracePoint.new(:call) {}\n", "Ractor.new { 1 }.value\n"].each do |prefix|
      out = ruby_json(prefix + PRELUDE + <<~'RUBY')
        2.times { joined("https://one.test", "/x") }
        puts JSON.generate({ hits: Lowrail::Stats.unit_hits.fetch("0", 0), refusal: Lowrail::Memo.refusal_reason })
      RUBY
      assert_equal 0, out.fetch("hits")
      assert_match(/\Aractor_trace_visibility:/, out.fetch("refusal")) if prefix.start_with?("Ractor")
    end
  end

  def test_string_digest_keys_mutation_and_observable_dispatch
    prelude = PRELUDE.sub("MemoFacts.build", "MemoFacts.digest").sub('"memo/uri_join"', '"memo/sha256"')
    out = ruby_json(prelude + <<~'RUBY')
      def hashed(string)
        Lowrail::Memo.digest(0, Digest::SHA256, string) { |r,s| r.base64digest(s) }
      end
      Regexp.timeout = 1 # Rails' default must not disable a regex-free intrinsic.
      input = +"abc"
      expected = "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0="
      hashed(input).replace("poison")
      raise "shared return" unless hashed(input) == expected && !hashed(input).frozen?
      input.replace("different")
      raise "mutable key" unless hashed(input) == Digest::SHA256.base64digest(input)
      %i[before after].each do |turn|
        saved = "during-#{turn}"
        input = saved.dup
        other = "replacement-#{turn}"
        expected_digest = Digest::SHA256.base64digest(saved)
        ready, done = Queue.new, Queue.new
        worker = Thread.new { ready.pop; input.replace(other); done << true }
        actual = Lowrail::Memo.digest(0, Digest::SHA256, input) do |r,s|
          if turn == :before
            ready << true
            done.pop
          end
          value = r.base64digest(s)
          if turn == :after
            ready << true
            done.pop
          end
          value
        end
        worker.join
        raise "changed during digest computation: #{turn}" unless actual == expected_digest
        2.times do
          raise "old digest key poisoned" unless hashed(saved) == expected_digest
          raise "new digest key poisoned" unless hashed(other) == Digest::SHA256.base64digest(other)
        end
      end
      ["\xFF\0".b, "abc".b, "abc".encode("UTF-16LE"), ""].each do |s|
        2.times do
          actual = hashed(s)
          original = Digest::SHA256.base64digest(s)
          raise "bytes or encoding" unless actual == original && actual.encoding == original.encoding
        end
      end
      hits = Lowrail::Stats.unit_hits.fetch("0", 0)
      raise "vacuous memo test" unless hits > 0
      # These methods belong to the cache key, not the original digest closure.
      hash_method, eql_method = Array.instance_method(:hash), Array.instance_method(:eql?)
      Array.define_method(:hash) { 0 }
      Array.define_method(:eql?) { |_| true }
      ["left-key", "right-key"].each do |s|
        raise "key methods collapsed distinct strings" unless hashed(s) == Digest::SHA256.base64digest(s)
      end
      Array.define_method(:hash, hash_method)
      Array.define_method(:eql?, eql_method)
      wrapper = Module.new do
        def update(string)
          $updates += 1
          super
        end
      end
      $updates = 0
      Digest::Base.prepend(wrapper)
      3.times { hashed("abc") }
      raise "lost digest effects" unless $updates == 3
      raise "certified wrapper" unless Lowrail::MemoFacts.digest["decline"].include?("update")
      wrapper.send(:remove_method, :update)
      conversions = 0
      object = Object.new
      object.define_singleton_method(:to_str) { conversions += 1; "abc" }
      2.times { raise "conversion" unless hashed(object) == expected }
      raise "lost conversions" unless conversions == 2
      2.times do
        begin
          hashed(nil)
          raise "lost error"
        rescue TypeError
        end
      end
      targeted = 0
      trace = TracePoint.new(:call) { targeted += 1 }
      trace.enable(target: Digest::SHA256.method(:base64digest)) { 3.times { hashed("abc") } }
      raise "lost tracing" unless targeted == 3
      puts JSON.generate({ hits: hits, conversions: conversions, traces: targeted })
    RUBY
    assert_operator out.fetch("hits"), :>, 0
    assert_equal 2, out.fetch("conversions")
    assert_equal 3, out.fetch("traces")
  end

  def test_public_inertia_vite_version_keeps_its_own_file_and_time_semantics
    out = ruby_json("fixtures = #{File.expand_path('../../tests/fixtures/memo', __dir__).dump}\n" + <<~'RUBY')
      require "json"
      begin
        gem "vite_ruby", "3.11.1"
        gem "inertia_rails", "3.23.0"
      rescue Gem::LoadError
        puts JSON.generate({ available: false })
        exit
      end
      require "rails"
      require "active_support/all"
      require "action_controller"
      require "inertia_rails"
      require "vite_ruby"
      require "tmpdir"
      require "fileutils"
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p("#{dir}/config")
        FileUtils.mkdir_p("#{dir}/app/frontend")
        File.write("#{dir}/config/vite.json", JSON.generate({ all: { sourceCodeDir: "app/frontend" } }))
        file = "#{dir}/app/frontend/entry.js"
        File.write(file, "first")
        ViteRuby.reload_with(root: dir)
        load File.join(fixtures, "inertia_eager_version.rb")
        eager = InertiaRails.configuration.version.dup
        File.write(file, "other")
        sleep 1.1
        raise "eager version recomputed" unless InertiaRails.configuration.version == eager
        load File.join(fixtures, "inertia_version.rb")
        first = InertiaRails.configuration.version.dup
        raise "fixture missed changed file" if first == eager
        File.write(file, "third") # same size, different content
        sleep 1.1 # Vite's documented one-second memo must expire
        second = InertiaRails.configuration.version
        raise "stale file digest" if first == second
        puts JSON.generate({ available: true, changed: first != second, digest_size: second.size })
      end
    RUBY
    skip "install vite_ruby 3.11.1 and inertia_rails 3.23.0 for the public analogue" unless out.fetch("available")
    assert_equal true, out.fetch("changed")
    assert_equal 40, out.fetch("digest_size")
  end
end
