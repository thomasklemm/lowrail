# Scratch harness: one warmup pass, then capture every SQL statement of one
# pass with its binds, and print EXPLAIN QUERY PLAN for each distinct statement
# before and after ANALYZE on the same in-memory connection.
require File.join(Dir.pwd, "lib/harness")
require "json"

def run_benchmark(_hint, **, &block)
  block.call
  seen = {}
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    next if payload[:name] == "SCHEMA" || payload[:sql] !~ /\A\s*SELECT/i
    key = payload[:sql]
    seen[key] ||= [payload[:type_casted_binds].respond_to?(:call) ? payload[:type_casted_binds].call : payload[:type_casted_binds], 0]
    seen[key][1] += 1
  end
  block.call
  ActiveSupport::Notifications.unsubscribe(sub)
  raw = ActiveRecord::Base.connection.raw_connection
  plan = ->(sql, binds) { raw.execute("EXPLAIN QUERY PLAN #{sql}", Array(binds).map { |b| b.is_a?(ActiveModel::Attribute) ? b.value_for_database : b }).map { |r| r.is_a?(Hash) ? r["detail"] : r[3] }.join(" | ") }
  conv = ->(binds) { Array(binds).map { |b| b.is_a?(ActiveModel::Attribute) ? b.value_for_database : b } }
  reps = Integer(ENV.fetch("PLANS_REPS", "0"))
  timeit = lambda do
    seen.to_h do |sql, (binds, _)|
      stmt = raw.prepare(sql)
      b = conv.(binds)
      ts = 5.times.map do
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        reps.times { stmt.reset!; stmt.bind_params(*b); stmt.to_a }
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / reps
      end
      stmt.close
      [sql, ts.sort[2]]
    end
  end
  tb = timeit.() if reps > 0
  before = seen.to_h { |sql, (binds, _)| [sql, plan.(sql, binds)] }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  raw.execute("ANALYZE")
  analyze_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000
  after = seen.to_h { |sql, (binds, _)| [sql, plan.(sql, binds)] }
  changed = seen.keys.reject { |sql| before[sql] == after[sql] }
  if reps > 0
    ta = timeit.()
    tot = ->(h, keys) { keys.sum { |s| h[s] * seen[s][1] } * 1000 }
    puts format("SQLite execution per pass (median of 5 x %d reps per statement, times count): all %.3f -> %.3f ms; changed plans %.3f -> %.3f ms", reps, tot.(tb, seen.keys), tot.(ta, seen.keys), tot.(tb, changed), tot.(ta, changed))
    changed.each { |s| puts format("  x%-4d %.2f -> %.2f us  %s", seen[s][1], tb[s] * 1e6, ta[s] * 1e6, s[0, 90]) }
  end
  puts "distinct SELECTs #{seen.size}, executions #{seen.values.sum { _2 }}, ANALYZE #{analyze_ms.round(1)} ms, stat1 rows #{raw.execute("SELECT count(*) FROM sqlite_stat1").first.first}"
  puts "plans changed: #{changed.size} distinct, #{changed.sum { seen[_1][1] }} executions per pass"
  changed.each do |sql|
    puts "--- x#{seen[sql][1]} #{sql[0, 300]}", "  before: #{before[sql]}", "  after:  #{after[sql]}"
  end
  File.write(ENV["PLANS_OUT"], JSON.pretty_generate(seen.keys.map { |s| { sql: s, n: seen[s][1], before: before[s], after: after[s] } })) if ENV["PLANS_OUT"]
end
