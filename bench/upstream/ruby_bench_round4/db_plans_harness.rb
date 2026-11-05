# Scratch harness for the database benchmarks of ruby-bench (round 4 of
# ruby-bench-improvements.md), extending round 2's plans_harness.rb:
#   ruby -r ./db_plans_harness.rb benchmarks/<name>/benchmark.rb   (from a ruby-bench tree)
# One warmup pass, then every SQL statement of one pass is recorded (Active
# Record notifications or a Sequel logger). For each distinct statement it
# prints EXPLAIN QUERY PLAN before and after ANALYZE on the same connection,
# times every SELECT with its recorded binds (median of 5 x PLANS_REPS) and
# checks that the rows are identical. With PLANS_ROUTES (railsbench) it also
# compares the response bodies of the given routes before and after ANALYZE.
require File.join(Dir.pwd, "lib/harness")

def run_benchmark(_hint, **, &block)
  require "json" # after Bundler.setup: the Gemfiles pin default gems
  require "digest"
  block.call
  sequel = defined?(Sequel::Model) && defined?(DB)
  ar = !sequel && defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?
  abort "no database connection: ActiveRecord #{defined?(ActiveRecord).inspect}, Sequel #{defined?(Sequel).inspect}" unless sequel || ar
  seen = {} # sql => [binds, count]
  record = ->(sql, binds) { (seen[sql] ||= [binds, 0])[1] += 1 }
  if ar
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"
      b = payload[:type_casted_binds]
      b = b.call if b.respond_to?(:call)
      record.(payload[:sql], Array(b).map { |x| x.is_a?(ActiveModel::Attribute) ? x.value_for_database : x })
    end
  else
    logger = Object.new
    logger.define_singleton_method(:info) { |m| record.(m.sub(/\A\([\d.]+s\) /, ""), []) }
    %i[debug warn error].each { |l| logger.define_singleton_method(l) { |_| } }
    DB.loggers << logger
  end
  block.call
  ar ? ActiveSupport::Notifications.unsubscribe(sub) : DB.loggers.delete(logger)

  raw = ar ? ActiveRecord::Base.connection.raw_connection : DB.synchronize { _1 }
  scalar = ->(sql) { r = raw.execute(sql).first; r.is_a?(Hash) ? r.values.first : r.first }
  stat1 = scalar.("SELECT count(*) FROM sqlite_master WHERE name = 'sqlite_stat1'")
  shape = ->(sql) { sql.gsub(/\b\d+\b/, "N") }
  shapes = seen.keys.group_by(&shape)
  plan = ->(sql, binds) { raw.execute("EXPLAIN QUERY PLAN #{sql}", binds).map { |r| r.is_a?(Hash) ? r["detail"] : r[3] }.join(" | ") }
  selects = seen.keys.select { _1 =~ /\A\s*SELECT/i }
  reps = Integer(ENV.fetch("PLANS_REPS", "200"))
  timeit = lambda do
    selects.to_h do |sql|
      stmt = raw.prepare(sql)
      b = seen[sql][0]
      rows = nil
      ts = 5.times.map do
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        reps.times { stmt.reset!; stmt.bind_params(*b); rows = stmt.to_a }
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / reps
      end
      stmt.close
      [sql, [ts.sort[2], Digest::SHA256.hexdigest(Marshal.dump(rows))]]
    end
  end
  routes = ENV["PLANS_ROUTES"]&.split(",")
  bodies = lambda do
    routes.to_h do |path|
      status, _, body = Rails.application.call(Rack::MockRequest.env_for("https://localhost#{path}"))
      s = +""; body.each { s << _1 }; body.close if body.respond_to?(:close)
      s.gsub!(/(name="csrf-token" content=|name="authenticity_token" value=)"[^"]*"/, '\\1""') # per request
      [path, [status, Digest::SHA256.hexdigest(s)]]
    end
  end
  bb = bodies.() if routes
  timeit.() # warms SQLite's page cache and the statement code paths
  tb = timeit.()
  before = seen.to_h { |sql, (binds, _)| [sql, plan.(sql, binds)] }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  raw.execute("ANALYZE")
  analyze_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000
  after = seen.to_h { |sql, (binds, _)| [sql, plan.(sql, binds)] }
  ta = timeit.()
  ba = bodies.() if routes
  changed = seen.keys.reject { before[_1] == after[_1] }
  tot = ->(h, keys) { keys.sum { |s| h[s][0] * seen[s][1] } * 1000 }
  puts "sqlite_stat1 before ANALYZE: #{stat1 == 1 ? "yes" : "no"}; after: #{scalar.("SELECT count(*) FROM sqlite_stat1")} rows, ANALYZE #{analyze_ms.round(2)} ms"
  puts "statements per pass: #{seen.size} distinct strings, #{shapes.size} distinct shapes (literals as N), #{seen.values.sum { _2 }} executions, #{selects.size} distinct SELECTs"
  shapes.each { |sh, sqls| puts format("  x%-6d %s", sqls.sum { seen[_1][1] }, sh[0, 160]) }
  puts "plans changed: #{changed.size} distinct, #{changed.sum { seen[_1][1] }} executions per pass"
  changed.each { |sql| puts "--- x#{seen[sql][1]} #{sql[0, 300]}", "  before: #{before[sql]}", "  after:  #{after[sql]}" }
  puts format("SQLite time per pass (median of 5 x %d reps, times executions): all SELECTs %.3f -> %.3f ms; changed %.3f -> %.3f ms",
              reps, tot.(tb, selects), tot.(ta, selects), tot.(tb, changed & selects), tot.(ta, changed & selects))
  diff_rows = selects.reject { tb[_1][1] == ta[_1][1] }
  puts "rows identical before/after ANALYZE: #{diff_rows.empty? ? "all #{selects.size}" : "DIFFER for #{diff_rows.size}"}"
  if routes
    diff = routes.reject { bb[_1] == ba[_1] }
    puts "responses identical before/after ANALYZE: #{diff.empty? ? "all #{routes.size} (statuses #{bb.values.map(&:first).tally})" : "DIFFER: #{diff.join(" ")}"}"
  end
  File.write(ENV["PLANS_OUT"], JSON.pretty_generate(seen.keys.map { |s| { sql: s, n: seen[s][1], before: before[s], after: after[s] } })) if ENV["PLANS_OUT"]
end
