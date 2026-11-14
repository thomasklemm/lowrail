# frozen_string_literal: true

# Lead 7 at realistic sizes: Ir and objects per call of loading ROWS records of a
# WIDTH-column table, for the Rails tree in BUNDLE_GEMFILE (or the checkout in RAILS,
# with its gems on GEM_PATH), on ADAPTER (sqlite3 or
# postgresql, database DB). IrCount under census 8's patched Callgrind,
# --instr-atstart=no. Prints "CASE ROWS WIDTH Ir/call obj/call jit-blocks".
#   inst      Item._load_from_sql on a cached result (no SQL; 8.1 reuses its memoized IndexedRows)
#   fresh     Item._load_from_sql on a new Result of the same rows (no SQL)
#   query     Item.limit(ROWS).to_a
#   read      query, then every generated reader of every record once
#   includes  Item.limit(ROWS).includes(:author).to_a
#   inc_read  includes, then every reader and item.author.name
if (rails = ENV["RAILS"])
  %w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
else
  require "bundler/setup"
end
require "active_record"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/l7/ext/ir_count.so"))

adapter = ENV.fetch("ADAPTER", "sqlite3")
if adapter == "sqlite3"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
else
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: ENV.fetch("DB", "l7"))
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
# As in production: Rails sets this from the log level; it defaults to true without Rails.
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)

width = Integer(ENV.fetch("WIDTH", "15"))
types = %i[string integer boolean datetime float text]
cols = (1..(width - 4)).map { |i| ["c#{i}", types[(i - 1) % types.size]] }
ActiveRecord::Schema.define do
  create_table(:authors, force: true) { |t| t.string :name; t.string :email; t.timestamps }
  create_table(:items, force: true) do |t|
    t.references :author, index: false
    cols.each { |c, type| t.column c, type }
    t.timestamps
  end
end
class Author < ActiveRecord::Base; has_many :items; end
class Item < ActiveRecord::Base; belongs_to :author; end

now = Time.utc(2026, 1, 1)
value = ->(type, i) do
  case type
  when :string then "value #{i}"
  when :text then "A longer text value for row #{i}, about as long as a short description."
  when :integer then i * 7
  when :boolean then i.odd?
  when :datetime then now + i * 3600
  when :float then i * 1.5
  end
end
Author.insert_all!(Array.new(20) { |i| { id: i + 1, name: "Author #{i}", email: "a#{i}@example.com", created_at: now, updated_at: now } })
Item.insert_all!(Array.new(Integer(ENV.fetch("ITEMS", "100"))) do |i|
  cols.to_h { |c, type| [c, value.(type, i)] }.merge(id: i + 1, author_id: i % 20 + 1, created_at: now, updated_at: now)
end)

readers = Item.column_names
read_all = eval("->(r) { #{readers.map { |n| "r.#{n}" }.join('; ')} }")

row_counts = ENV.fetch("ROWS", "1 10 50 100").split.map { Integer(_1) }
names = ENV.fetch("CASES", "inst fresh query read includes inc_read").split
cases = row_counts.flat_map do |n|
  result = Item.connection.select_all(Item.limit(n).arel)
  raise unless result.length == n
  args = [result.columns, result.rows, result.instance_variable_get(:@column_types)]
  {
    "inst" => -> { Item._load_from_sql(result) },
    "fresh" => -> { Item._load_from_sql(ActiveRecord::Result.new(*args)) },
    "query" => -> { Item.limit(n).to_a },
    "read" => -> { Item.limit(n).to_a.each(&read_all) },
    "includes" => -> { Item.limit(n).includes(:author).to_a },
    "inc_read" => -> { Item.limit(n).includes(:author).to_a.each { |r| read_all.(r); r.author.name } },
  }.slice(*names).map { |c, fn| [c, n, fn] }
end

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
reps = Integer(ENV.fetch("N", "100"))
IrCount.start if IrCount.running?
cases.each do |c, n, fn|
  (reps * 2).times { fn.() }
  if yjit
    flat = 0
    30.times { b = blocks.(); reps.times { fn.() }; flat = blocks.() == b ? flat + 1 : 0; break if flat == 3 }
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  reps.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  GC.enable
  puts format("%s %d %d %d %.2f %d", c, n, width, (i1 - i0) / reps, (o1 - o0).fdiv(reps), blocks.() - b0)
  $stdout.flush
end
