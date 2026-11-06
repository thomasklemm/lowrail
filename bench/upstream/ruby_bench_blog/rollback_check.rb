# Preload (ruby -r) in place of the harness: runs ITRS iterations and checks that every
# iteration starts and ends with the same rows, max ids and sqlite_sequence in all
# databases, and records what the iteration had written just before its rollback.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
ITRS = Integer(ENV.fetch("ITRS", 30))

def __snapshot
  ActiveRecord::Base.connection_handler.connection_pool_list(:writing).to_h do |pool|
    pool.with_connection do |c|
      tables = c.tables - %w[ar_internal_metadata schema_migrations]
      [pool.db_config.name, {
        rows: tables.to_h { |t| [t, c.select_value("SELECT count(*) FROM #{t}")] },
        max_id: tables.to_h { |t| [t, c.select_value("SELECT max(id) FROM #{t}")] },
        seq: c.select_rows("SELECT name, seq FROM sqlite_sequence").to_h,
      }]
    end
  end
end

def __diff(a, b)
  a.flat_map do |db, kinds|
    kinds.flat_map do |kind, h|
      h.filter_map { |t, v| w = b.dig(db, kind, t); "#{db}.#{kind}.#{t} #{v}->#{w}" if v != w }
    end
  end
end

def run_benchmark(_n, **)
  mod = Module.new do
    def unpin_connection!
      $__inside ||= __snapshot
      super
    end
  end
  ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(mod)
  start = __snapshot
  puts "START #{start.transform_values { _1[:rows] }}"
  ok = true
  ITRS.times do |i|
    before = __snapshot
    $__inside = nil
    a0 = GC.stat(:total_allocated_objects)
    yield
    allocs = GC.stat(:total_allocated_objects) - a0
    after = __snapshot
    inside = __diff(before, $__inside)
    same = before == after && after == start
    ok &&= same
    puts "ITR #{i + 1} restored=#{same} allocs=#{allocs} written=#{inside.size} #{inside.first(12).join(' ')}"
  end
  puts "ALL_RESTORED=#{ok}"
end
