require "bundler/setup"
require "active_record"
require "json"

def emit(label)
  value = yield
  puts JSON.generate([label, value]).gsub(/0x[0-9a-f]+/, "ADDRESS")
rescue => e
  puts JSON.generate([label, e.class.name, e.message.gsub(/0x[0-9a-f]+/, "ADDRESS")])
end

def build
  types = { "a" => ActiveModel::Type::Integer.new, "b" => ActiveModel::Type::String.new }
  defaults = ActiveModel::AttributeSet.new(ActiveModel::IndexedRow::Mutable[{}])
  ActiveModel::AttributeSet::Builder.new(types, defaults, types.keys).build_from_database({ "a" => "17", "b" => "hello" })
end

class ReviewSet < ActiveModel::LazyIndexedAttributeSet; end
names = ["a", "b", "missing", :a, nil, 0, false, Class.new(String).new("a")]
%w[fresh read written frozen dup clone marshal materialized subclass].each do |state|
  names.each_with_index do |name, i|
    set = build
    case state
    when 'read' then set.fetch_value('a')
    when 'written' then set.write_from_user('a', 29)
    when 'frozen' then set.freeze
    when 'dup' then set = set.dup
    when 'clone' then set = set.clone
    when 'marshal' then set = Marshal.load(Marshal.dump(set))
    when 'materialized' then set.to_hash; set.each_value.to_a
    when 'subclass'
      subclass = ReviewSet.allocate
      set.instance_variables.each { |var| subclass.instance_variable_set(var, set.instance_variable_get(var)) }
      set = subclass
    end
    emit([state, i]) do
      a = set[name]
      [a.class.name, a.name, a.initialized?, a.value, set.keys, set.to_hash]
    end
  end
end

class IndexHash < Hash
  attr_accessor :events, :callback
  def [](key)
    events << ['index', key]
    callback&.call
    super
  end
end
class AttributeArray < Array
  attr_accessor :events
  def [](key)
    events << ['attribute', key]
    super
  end
end

%w[plain mutate fiber thread].each do |mode|
  set = build
  events = []
  indexes = IndexHash.new
  set.indexes.each_key { |key| indexes[key] = set.indexes[key] }
  indexes.events = events
  attrs = AttributeArray.new([ActiveModel::Attribute.from_database('a', '41', ActiveModel::Type::Integer.new)])
  attrs.events = events
  set.instance_variable_set(:@indexes, indexes)
  set.instance_variable_set(:@attributes, attrs)
  action = -> { set.instance_variable_set(:@attributes, nil) }
  case mode
  when 'mutate' then indexes.callback = action
  when 'fiber' then indexes.callback = -> { Fiber.yield }
  when 'thread'
    ready, done = Queue.new, Queue.new
    indexes.callback = -> { ready << true; done.pop }
    writer = Thread.new { ready.pop; action.call; done << true }
  end
  emit(['callbacks', mode]) do
    result = if mode == 'fiber'
      fiber = Fiber.new { set['a'].value }
      fiber.resume
      action.call
      fiber.resume
    else
      set['a'].value
    end
    writer&.join
    [result, events]
  end
end

%i[indexes index_for_name lookup attribute_at].each do |method|
  set = build
  set.each_value.to_a
  mod = Module.new
  mod.define_method(method) { |*| raise "overridden #{method}" }
  set.extend(mod)
  emit(['excluded nodoc override', method]) { set['a'].value }
  emit(['excluded nodoc override keys', method]) { set.keys }
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:records) { |t| t.string :name; t.integer :count }
end
class ReviewRecord < ActiveRecord::Base
  self.table_name = 'records'
end
class ReviewOther < ActiveRecord::Base
  self.table_name = 'records'
  attribute :extra, :integer, default: 91
end
row = ReviewRecord.create!(name: 'left', count: 3)
row = ReviewRecord.find(row.id)
other = row.becomes(ReviewOther)
other.name = 'right'
emit('becomes') { [other.instance_variable_get(:@attributes).class.name, row.attributes, other.attributes, other.changed] }
emit('becomes marshal') { Marshal.load(Marshal.dump(other)).attributes }
emit('becomes freeze') { other.freeze.attributes }

%w[loaded new unchanged].each do |state|
  record = state == 'new' ? ReviewRecord.new(name: 'new') : ReviewRecord.find(row.id)
  calls = Hash.new(0)
  trace = TracePoint.new(:call) do |t|
    calls[t.method_id] += 1 if t.defined_class == ActiveModel::LazyIndexedAttributeSet && %i[keys []].include?(t.method_id)
  end
  trace.enable { record.update!(count: state == 'unchanged' ? 3 : 7) }
  emit(['save calls', state]) { calls }
end
