require_relative "../lib/harness"

# Redefines SQLite3 perform_query (and PostgreSQL prepare_statement) in every variant, from the
# installed gem's own source, so main and candidate both run a redefined method.
#   LR_VARIANT: main | tm (type map once) | st (statement once) | ab (both)
def lowrail_patch(variant)
  path = ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements.instance_method(:perform_query).source_location[0]
  src = File.read(path)
  body = src[/^          def perform_query\(.*?\n          end\n/m] or raise "perform_query not found"
  if %w[st ab].include?(variant)
    old = "                @statements[sql] ||= raw_connection.prepare(sql)\n                @statements[sql].reset!\n"
    body.sub!(old, "                (@statements[sql] ||= raw_connection.prepare(sql)).reset!\n") or raise "st"
  end
  if %w[tm ab].include?(variant)
    old = "                  ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { |t| type_map.lookup(t) }, affected_rows: affected_rows)\n"
    body.sub!(old, "                  type_map = type_map()\n" + old) or raise "tm"
  end
  ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements.module_eval(body, path, 1)
end

def run_benchmark(_n, **, &block)
  lowrail_patch(ENV.fetch("LR_VARIANT"))
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, variant=#{ENV["LR_VARIANT"]}"
end
