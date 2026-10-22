# frozen_string_literal: true

# Public SQLite3::Statement behavior and deterministic allocation companion.
# No CPU/JIT speed claim; the request counter is the performance gate.
require "json"
require "digest"
require_relative "../jit_stability"
library, output = ARGV
raise "new output required" if File.exist?(output)
$LOAD_PATH.unshift(File.expand_path(library))
require "sqlite3"
extension = $LOADED_FEATURES.find { _1.end_with?("sqlite3_native.so") }
raise "wrong native extension" unless File.realpath(extension).start_with?(File.realpath(library) + "/")
JitStability.assert_mode!

database = SQLite3::Database.new(":memory:")
database.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)")
database.execute("INSERT INTO items VALUES (31, 'héllo')")
snapshot = []
query = Class.new(String).new("SELECT id, name, 3.125, x'00FF', NULL FROM items")
statement = database.prepare(query.freeze)
row = statement.step
snapshot << [row.map { _1.is_a?(String) && _1.encoding == Encoding::BINARY ? _1.bytes : _1 },
  row.frozen?, row.map(&:frozen?), row[1].encoding.name, row[3].bytes]
snapshot << [statement.done?, statement.step, statement.done?, statement.step]
statement.reset!
another = statement.step
snapshot << [row == another, row.equal?(another), row[1].equal?(another[1]), row[3].equal?(another[3])]
begin
  row << "caller mutation"
rescue => error
  snapshot << error.class.name
end
statement.close
empty = database.prepare("SELECT name FROM items WHERE 0")
snapshot << [empty.step, empty.done?, empty.step]
empty.reset!
snapshot << [empty.done?, empty.step, empty.done?]
empty.close
begin
  database.execute("INSERT INTO items VALUES (31, 'duplicate')")
rescue => error
  snapshot << [error.class.name, error.message]
end
database.create_function("raising", 0) { raise "callback witness" }
begin
  database.execute("SELECT raising()")
rescue => error
  snapshot << [error.class.name, error.message]
end
GC.verify_compaction_references(double_heap: true, toward: :empty)
snapshot << database.get_first_row("SELECT id, name FROM items")

statements = {
  "empty_select" => database.prepare("SELECT name FROM items WHERE 0"),
  "one_row" => database.prepare("SELECT id, name FROM items"),
  "empty_update" => database.prepare("UPDATE items SET name = name WHERE 0")
}
operations = statements.transform_values do |stmt|
  -> { stmt.reset!; stmt.each { |_row| }; nil }
end
done_statement = database.prepare("SELECT 1 WHERE 0")
done_statement.step
operations["already_done_control"] = -> { done_statement.step }
allocations = operations.to_h do |name, operation|
  10_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  10_000.times { operation.call }
  [name, (GC.stat(:total_allocated_objects) - before).fdiv(10_000)]
end
File.write(output, JSON.pretty_generate(ruby: RUBY_DESCRIPTION, mode: JitStability.actual,
  sqlite: SQLite3::SQLITE_VERSION, gem: SQLite3::VERSION, snapshot: snapshot, allocations: allocations,
  extension_sha256: Digest::SHA256.file(extension).hexdigest, extension: extension) + "\n")
statements.each_value(&:close)
done_statement.close
database.close
