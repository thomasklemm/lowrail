# frozen_string_literal: true

# steps.rb: Ir per call of each step that _load_from_sql runs per row, for the tree in
# BUNDLE_GEMFILE or RAILS (SQLite, WIDTH columns, interpreter), minus an empty lambda.
# Under census 8's patched Callgrind, --instr-atstart=no. Prints "step Ir objects".
ENV["CASES"] = "inst"
ENV["ROWS"] = "1"
ENV["N"] = "0"
micro = File.join(__dir__, "load_micro.rb")
eval(File.read(micro).sub(/^yjit = .*\z/m, ""), TOPLEVEL_BINDING, micro)

result = Item.connection.select_all(Item.limit(1).arel)
Item._load_from_sql(result)
rec = Item.first
main = ActiveRecord::Result.method_defined?(:map_rows)
b = Item.attributes_builder
if main
  layout = ActiveRecord::Result::RowLayout.new(result.columns, b.indexes, result.instance_variable_get(:@column_types))
  row = result.rows.first
  idx = layout.indexes
  build = -> { b.build_from_row(row, idx) }
  inst = -> { Item.send(:instantiate_instance_of, Item, row, idx) }
  each_row = -> { layout.build(row) }
else
  irow = result.indexed_rows.first
  ci = result.column_indexes
  r0 = result.rows.first
  build = -> { b.build_from_database(irow, {}) }
  inst = -> { Item.send(:instantiate_instance_of, Item, irow, {}) }
  row_class = defined?(ActiveRecord::Result::IndexedRow) ? ActiveRecord::Result::IndexedRow : ActiveModel::IndexedRow
  each_row = -> { row_class.new(ci, r0) }
end
attrs = build.()
steps = {
  "empty" => -> {},
  "row (8.1 IndexedRow.new, main RowLayout#build)" => each_row,
  "attributes_builder" => -> { Item.attributes_builder },
  "build attributes (8.1 build_from_database, main build_from_row)" => build,
  "allocate" => -> { Item.allocate },
  "primary_key" => -> { Item.primary_key },
  "strict_loading_by_default" => -> { Item.strict_loading_by_default },
  "strict_loading_mode" => -> { Item.strict_loading_mode },
  "define_attribute_methods" => -> { Item.define_attribute_methods },
  "init_internals" => -> { rec.send(:init_internals) },
  "_run_find_callbacks" => -> { rec._run_find_callbacks },
  "_run_initialize_callbacks" => -> { rec._run_initialize_callbacks },
  "init_with_attributes" => -> { Item.allocate.init_with_attributes(attrs) },
  "instantiate_instance_of" => inst,
}
n = 2000
IrCount.start if IrCount.running?
base = nil
steps.each do |name, fn|
  n.times { fn.() }
  GC.start
  GC.disable
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  n.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  GC.enable
  ir = (i1 - i0).fdiv(n)
  base ||= ir
  puts format("%-62s %8.1f %5.2f", name, name == "empty" ? ir : ir - base, (o1 - o0).fdiv(n))
end
