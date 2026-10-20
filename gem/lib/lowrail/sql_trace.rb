# frozen_string_literal: true

module Lowrail
  # Per-test SQL traces for `lowrail verify` (on with LOWRAIL_OUTCOMES, off
  # with LOWRAIL_SQL_TRACE=0). Equal outcomes do not prove that a lowered
  # Active Record path issued the same queries; this compares, per test, the
  # sql.active_record events with Lowrail off and on.
  #
  # One line per event: name, SQL, bind signature (attribute name and class
  # of the value before type cast), cached flag and row count. Bind *values*
  # are left out on purpose: generated tokens and timestamps differ between
  # any two runs. Timestamp literals and numbers of six or more digits in the
  # SQL text are masked for the same reason. Events on the test's thread form an ordered sequence; events on
  # other threads (system-test servers, async queries) a sorted multiset.
  #
  # Excluded, because they depend on which test happens to run first in a
  # process, not on the code under test: SCHEMA queries, fixture loading
  # (FixtureSet.create_fixtures), connection setup (configure_connection,
  # e.g. SQLite PRAGMAs) and Rails' internal metadata tables. They are
  # counted, not compared.
  #
  # Output (in the outcome files): "sql" => {test => {"digest", "n", "skipped",
  # "other_digest"}}. "digest" covers the test's own thread and gates verify;
  # "other_digest" (present only when other threads queried) is advisory,
  # since thread interleaving can change it between two identical runs.
  # LOWRAIL_SQL_TRACE=full also stores the lines ("lines"), for diagnosis.
  module SqlTrace
    TIMESTAMP = /'\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d(?:\.\d+)?(?:[+-]\d\d:?\d\d|Z)?'/
    # Generated ids inlined into raw SQL (fixture ids are hashes, FTS rowids,
    # random tokens). Short literals such as LIMIT 20 stay significant.
    LONG_NUMBER = /(?<![\w.])\d{6,}(?![\w.])/
    INTERNAL_TABLES = /\b(?:ar_internal_metadata|schema_migrations)\b/

    class << self
      def enabled? = ENV["LOWRAIL_SQL_TRACE"] != "0"

      def tests = (@tests ||= {})

      def snapshot = tests.dup

      def hook_minitest
        return if @minitest_hooked || !enabled? || !defined?(::Minitest::Test)
        @minitest_hooked = true
        ::Minitest::Test.prepend(MinitestRun)
      end

      def start(key)
        return unless enabled? && subscribe
        hook_rails
        @mutex.synchronize do
          @key = key
          @thread = Thread.current
          @own = []
          @other = []
          @skipped = 0
        end
      end

      def finish
        key, own, other, skipped = @mutex&.synchronize do
          r = [@key, @own, @other, @skipped]
          @key = @thread = @own = @other = nil
          r
        end
        return unless key
        require "digest"
        lines = own + ["--- other threads"] + other.sort
        entry = { "digest" => Digest::SHA256.hexdigest(own.join("\n")), "n" => own.size + other.size, "skipped" => skipped }
        entry["other_digest"] = Digest::SHA256.hexdigest(other.sort.join("\n")) unless other.empty?
        entry["lines"] = lines if ENV["LOWRAIL_SQL_TRACE"] == "full"
        tests[key] = entry
      end

      def record(payload)
        return unless @key
        name = payload[:name].to_s
        sql = payload[:sql].to_s
        # SQLite accepts arbitrary bytes, including invalid UTF-8. Tracing
        # must not turn a successful query into an exception, nor conflate
        # distinct invalid byte sequences via replacement characters.
        sql = "<#{sql.encoding}:#{sql.b.unpack1('H*')}>" unless sql.valid_encoding?
        skip = Thread.current[:lowrail_sql_suspended] || name == "SCHEMA" || name.start_with?("Fixture") || sql.match?(INTERNAL_TABLES)
        line = skip ? nil : [name, sql.gsub(TIMESTAMP, "'<ts>'").gsub(LONG_NUMBER, "<n>"), binds(payload[:binds]), payload[:cached] ? "cached" : "", payload[:row_count]].join("\t")
        @mutex.synchronize do
          next unless @key
          if skip then @skipped += 1
          elsif Thread.current.equal?(@thread) then @own << line
          else @other << line
          end
        end
      end

      def suspended
        was = Thread.current[:lowrail_sql_suspended]
        Thread.current[:lowrail_sql_suspended] = true
        yield
      ensure
        Thread.current[:lowrail_sql_suspended] = was
      end

      private

      # Once the classes exist (they load lazily, so this is retried per test).
      def hook_rails
        if !@fixtures_hooked && defined?(::ActiveRecord::FixtureSet)
          @fixtures_hooked = true
          ::ActiveRecord::FixtureSet.singleton_class.prepend(SuspendFixtures)
        end
        if !@adapter_hooked && defined?(::ActiveRecord::ConnectionAdapters::AbstractAdapter) &&
           ::ActiveRecord::ConnectionAdapters::AbstractAdapter.private_method_defined?(:configure_connection)
          @adapter_hooked = true
          ::ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(SuspendConnect)
        end
      end

      def binds(list)
        return "" unless list
        list.map do |b|
          if b.respond_to?(:value_before_type_cast) && b.respond_to?(:name)
            "#{b.name}:#{b.value_before_type_cast.class}"
          else
            b.class.name
          end
        end.join(",")
      end

      # Subscribes once per process, as soon as Active Support is loaded.
      def subscribe
        return true if @subscribed
        return false unless defined?(::ActiveSupport::Notifications)
        @mutex = Mutex.new
        ::ActiveSupport::Notifications.subscribe("sql.active_record") { |*args| SqlTrace.record(args.last) }
        @subscribed = true
      end
    end

    module SuspendFixtures
      def create_fixtures(...) = SqlTrace.suspended { super }
    end

    # Prepended to AbstractAdapter: adapters that override configure_connection
    # call super, or run it from AbstractAdapter#connect!/reconnect!.
    module SuspendConnect
      private

      def configure_connection(...) = SqlTrace.suspended { super }
    end

    module MinitestRun
      def run
        SqlTrace.start("#{self.class.name}##{name}")
        super
      ensure
        SqlTrace.finish
      end
    end
  end
end
