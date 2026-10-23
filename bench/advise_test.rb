# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "advise"
require_relative "experiments/advise_patch_study"

class AdviseTest < Minitest::Test
  def test_evidence_distinguishes_repeated_values_changes_and_exception_unwinds
    Dir.mktmpdir do |root|
      path = File.join(root, "candidate.rb")
      File.write(path, <<~'RUBY')
        class AdviceEvidenceFixture
          def stable(key) = "sensitive-value-#{key}"
          def changing(key)
            @counter = (@counter || 0) + 1
          end
          def failing
            raise "fixture failure"
          end
          def work
            10.times do
              stable(19)
              changing(19)
              begin
                failing
              rescue RuntimeError
                nil
              end
            end
            100.times { String.new("allocate") }
            nil
          end
        end
      RUBY
      load path
      object = AdviceEvidenceFixture.new
      report = Advise.capture(-> { object.work }, root: root, warmup: 1, requests: 100, census: 7)
      finding = report.fetch(:findings).find { _1[:file] == "candidate.rb" }
      methods = finding.fetch(:methods).to_h { [_1[:method], _1] }
      stable = methods.fetch("AdviceEvidenceFixture#stable")
      assert_equal 70, stable[:calls]
      assert_equal 10, stable[:calls_per_operation]
      assert_equal 32, stable[:comparable]
      assert_equal 31, stable[:repeated]
      changing = methods.fetch("AdviceEvidenceFixture#changing")
      assert_equal 0, changing[:repeated]
      assert_equal 31, changing[:changed]
      failing = methods.fetch("AdviceEvidenceFixture#failing")
      assert_equal 0, failing[:comparable]
      assert_equal 70, failing[:tainted]
      assert_operator finding[:allocations_per_operation], :>=, 100
      assert_equal finding[:self_samples], finding[:cpu_frames].sum { _1[:self_samples] }
      assert finding[:cpu_frames].all? { _1[:inclusive_samples] <= finding[:inclusive_samples] }
      assert_equal "discovery_only", report[:kind]
      refute_includes JSON.generate(report), "sensitive-value-19"
      assert_includes finding[:explanation], "Do not globally memoize"
    ensure
      Object.send(:remove_const, :AdviceEvidenceFixture) if defined?(AdviceEvidenceFixture)
    end
  end

  def test_failed_workload_does_not_leave_allocation_tracing_or_gc_disabled
    assert_raises(RuntimeError) { AllocationCensus.capture(1) { raise "failed job" } }
    refute GC.disable
  ensure
    GC.enable
  end

  def test_sql_ranks_real_duplicate_round_trips_not_query_cache_hits
    require "active_record"
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    connection = ActiveRecord::Base.connection
    connection.execute("CREATE TABLE advice_rows (id integer)")
    cached = "SELECT 11 AS cached_read"
    uncached = "SELECT 29 AS uncached_read"
    report = Advise.sql(2, root: __dir__ + "/") do
      connection.cache { 3.times { connection.select_all(cached) } }
      connection.uncached { 2.times { connection.select_all(uncached) } }
      connection.execute("INSERT INTO advice_rows VALUES (1)")
      connection.select_all(uncached)
    end
    rows = report.fetch(:events).to_h { [_1[:statement], _1] }
    assert_equal 2, rows.fetch(uncached)[:duplicate_round_trips]
    assert_equal 6, rows.fetch(uncached)[:round_trips]
    assert_equal 0, rows.fetch(cached)[:duplicate_round_trips]
    assert_equal 4, rows.fetch(cached)[:duplicate_cached_hits]
    assert_equal uncached, report[:events].first[:statement]
  ensure
    ActiveRecord::Base.connection_handler.clear_all_connections! if defined?(ActiveRecord::Base)
  end

  def test_sql_gate_only_drops_certified_duplicate_reads_on_the_same_connection_without_barriers
    read = ['SELECT "id" FROM "items" WHERE "owner_id" = ?', [["owner_id", 19]], false, 1]
    cached = read.dup.tap { _1[2] = true }
    other = ['SELECT "name" FROM "items"', [], false, 1]
    allowed = [read.first(2)]
    compare = ->(a, b) { AdvisePatchStudy.sql_comparison(a, b, permitted_reads: allowed) }
    result = compare.call([read, other, cached], [read, other])
    assert result[:pass]
    assert_equal [{ position: 3, earlier_position: 1, statement: read[0], binds: read[1], cached: true, connection: 1 }], result[:dropped]
    assert compare.call([read, read], [read])[:pass] # A real duplicate read may drop too.
    refute AdvisePatchStudy.sql_comparison([read, read], [read])[:pass] # Explicit certification required.
    refute compare.call([read], [])[:pass]
    refute compare.call([read, other], [read])[:pass]
    refute compare.call([read], [read, other])[:pass]
    refute compare.call([read, other], [other, read])[:pass]
    changed_bind = read.dup.tap { _1[1] = [["owner_id", 23]] }
    refute compare.call([read, changed_bind], [read])[:pass]
    other_connection = read.dup.tap { _1[3] = 2 }
    refute compare.call([read, other_connection], [read])[:pass]
    ["UPDATE items SET owner_id = 1", "BEGIN", "COMMIT", "SELECT id FROM items FOR UPDATE"].each do |sql|
      barrier = [sql, [], false, 1]
      refute compare.call([read, barrier, read], [read, barrier])[:pass]
      refute compare.call([read, barrier, read], [read, read])[:pass]
    end
    baseline = { "exact" => [{ "status" => 200, "controlled_body_sha256" => "body",
      "controlled_headers_sha256" => "headers", "sql" => [read, other, cached] }], "lock_sha256" => "lock" }
    patched = Marshal.load(Marshal.dump(baseline))
    patched["exact"].first["sql"].pop
    workers = { "off_a" => baseline, "on" => patched, "off_b" => baseline }
    screen = -> { AdvisePatchStudy.exact_comparison(workers, permitted_reads: allowed) }
    assert screen.call.values_at(:sql_pass, :responses_equal, :same_dependencies).all?
    workers["off_b"] = patched
    refute screen.call[:sql_pass] # Allowed B-only drops must not mask A/A drift.
    workers["off_b"] = baseline
    patched["lock_sha256"] = "changed"
    refute screen.call[:same_dependencies]
    patched["exact"].first["controlled_body_sha256"] = "changed"
    refute screen.call[:responses_equal]
  end

  def test_uncertainty_is_over_four_blocks_not_individual_requests
    result = AdvisePatchStudy.t95([-10, 0, -20, -30])
    assert_equal(-15, result[:mean])
    assert_in_delta(-35.543, result[:t95].first, 0.001)
    assert_in_delta(5.543, result[:t95].last, 0.001) # A negative mean alone is not a resolved gain.
    assert_raises(RuntimeError) { AdvisePatchStudy.t95(Array.new(4000, -15)) }
  end

  def test_response_comparison_exempts_only_declared_counted_entropy
    response = Struct.new(:status, :body, :headers)
    policy = { "body" => [{ "name" => "CSRF", "pattern" => '(csrf-token" content=")[a-z]+(")',
      "replacement" => '\1<csrf>\2', "count" => 1 }],
      "headers" => { "x-request-id" => { "name" => "request ID", "pattern" => '\A[a-z]+\z',
        "replacement" => "<id>", "count" => 1 } } }
    a = response.new(200, '<meta name="csrf-token" content="alpha"><p>paid</p>', { "x-request-id" => "first" })
    b = response.new(200, '<meta name="csrf-token" content="beta"><p>paid</p>', { "x-request-id" => "second" })
    left = AdvisePatchStudy.response_fingerprint(a, policy)
    right = AdvisePatchStudy.response_fingerprint(b, policy)
    refute_equal left[:body_sha256], right[:body_sha256]
    assert_equal left[:controlled_body_sha256], right[:controlled_body_sha256]
    assert_equal left[:controlled_headers_sha256], right[:controlled_headers_sha256]
    b.body = b.body.sub("paid", "free")
    refute_equal left[:controlled_body_sha256], AdvisePatchStudy.response_fingerprint(b, policy)[:controlled_body_sha256]
    b.headers["cache-control"] = "public"
    refute_equal left[:controlled_headers_sha256], AdvisePatchStudy.response_fingerprint(b, policy)[:controlled_headers_sha256]
    b.body += '<meta name="csrf-token" content="extra">'
    assert_raises(RuntimeError) { AdvisePatchStudy.response_fingerprint(b, policy) }
  end

  def test_cookie_rules_count_across_header_values_without_ignoring_other_cookies
    response = Struct.new(:status, :body, :headers)
    policy = { "headers" => { "set-cookie" => [{ "name" => "one session value",
      "pattern" => '(\Asession=)[a-z]+', "replacement" => '\1<session>', "count" => 1 }] } }
    a = response.new(200, "same", { "set-cookie" => ["other=fixed; secure", "session=alpha; secure"] })
    b = response.new(200, "same", { "set-cookie" => ["other=fixed; secure", "session=beta; secure"] })
    fingerprint = ->(r) { AdvisePatchStudy.response_fingerprint(r, policy)[:controlled_headers_sha256] }
    assert_equal fingerprint.call(a), fingerprint.call(b)
    b.headers["set-cookie"][0] = "other=changed; secure"
    refute_equal fingerprint.call(a), fingerprint.call(b)
    b.headers["set-cookie"] << "session=extra; secure"
    assert_raises(RuntimeError) { fingerprint.call(b) }
  end
end
