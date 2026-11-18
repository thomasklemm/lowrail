# frozen_string_literal: true

# Differential probe for INR436: resolves the same props through PropsResolver of one inertia-rails tree
# and prints one JSON line per case and visit, with and without a DevTools recorder. Run through run.sh.
tree = File.expand_path(ARGV.fetch(0))
$LOAD_PATH.unshift(File.join(tree, 'lib'))
require 'rails'
require 'action_controller/railtie'
require 'inertia_rails'
resolver_file = $LOADED_FEATURES.grep(%r{inertia_rails/props_resolver\.rb}).first
abort "loaded #{resolver_file}, not from #{tree}" unless resolver_file.start_with?(tree)

class Ser
  def initialize(name, extra = nil)
    @name = name
    @password_digest = 'secret'
    @extra = extra
  end

  def to_inertia = @extra ? { name: @name, extra: @extra } : { name: @name }
end

class SubSer < Ser; end

class DuckSer
  def to_inertia = 'duck'
end

class Raising
  def to_inertia = raise('boom')
end

class LateFailure
  def as_json(*) = raise('late query failed')
end

Projection = Struct.new(:value) do
  def to_inertia = value
end

Rec = Struct.new(:id, :deferred, :once, :rescue) do
  def deferred? = deferred
  def once? = once
  def rescue? = self.rescue
end

class Recorder
  attr_reader :log

  def initialize = @log = []
  def prop_resolved(path, _prop, reset: false) = @log << [:prop, path, reset]
  def serializer_found(serializer, path) = @log << [:ser, serializer.class.name, path]
end

def dump(value)
  case value
  when Hash then value.to_h { |k, v| [k.to_s, dump(v)] }
  when Array then value.map { |v| dump(v) }
  when String, Integer, Float, true, false, nil then value
  when Symbol then ":#{value}"
  else "#<#{value.class.name || 'anon'} #{value.as_json.inspect}>"
  end
end

I = InertiaRails
CASES = {
  'plain' => ->(c) { { a: 1, b: { c: [1, 2] }, d: [] , e: {} } },
  'closure_hash_ser' => ->(c) { { a: -> { c << :a; { u: Ser.new('A') } } } },
  'optional_hash_ser' => ->(c) { { o: I.optional { c << :o; { u: Ser.new('A'), n: 1 } } } },
  'optional_array_ser' => ->(c) { { o: I.optional { c << :o; [Ser.new('A'), 1, { u: Ser.new('B') }] } } },
  'always_hash_ser' => lambda { |c|
    { other: 1, al: I.always { c << :al; { u: Ser.new('A'), x: I.optional { c << :x; 2 }, l: -> { c << :l; 3 }, e: {} } } }
  },
  'always_array_ser' => lambda { |c|
    { other: 1, al: I.always { c << :al; [Ser.new('A'), I.optional { c << :x; 2 }, -> { c << :l; 3 }, I.always { Ser.new('B') }] } }
  },
  'always_only_exec' => ->(c) { { other: 1, al: I.always { { x: I.optional { c << :x; 2 } } } } },
  'always_plain_hash' => ->(c) { { other: 1, al: I.always { c << :al; { a: 1, b: { c: 2 } } } } },
  'always_ser_direct' => ->(c) { { other: 1, al: I.always { Ser.new('A', -> { c << :cnt; 2 }) } } },
  'defer_hash_ser' => ->(c) { { d: I.defer { c << :d; { u: Ser.new('A'), r: Raising.new } } } },
  'defer_rescue' => ->(c) { { d: I.defer(rescue: true) { { u: Raising.new } } } },
  'once_array_ser' => ->(c) { { o: I.once { c << :o; [{ u: Ser.new('A') }] } } },
  'merge_array_ser' => ->(c) { { m: I.merge { c << :m; [{ u: Ser.new('A') }] } } },
  'merge_nested_in_always' => lambda { |c|
    { al: I.always { { u: Ser.new('A'), posts: I.merge { c << :posts; [Ser.new('B')] }, rows: [I.optional { c << :row; Ser.new('C') }, I.defer { c << :dr; 1 }] } } }
  },
  'subclass_and_duck' => ->(c) { { o: I.optional { { s: SubSer.new('S'), d: DuckSer.new, h: ActiveSupport::HashWithIndifferentAccess.new(u: Ser.new('H')) } } } },
  'ordered_options' => ->(c) { oo = ActiveSupport::OrderedOptions.new; oo.k = 1; { o: I.optional { { oo: oo, u: Ser.new('A') } }, top: oo } },
  'records_with_predicates' => lambda { |c|
    { r1: Rec.new(1, true, false, false), r2: Rec.new(2, false, true, false), r3: Rec.new(3, false, false, true),
      o: I.optional { { rec: Rec.new(4, true, true, false), u: Ser.new('A') } } }
  },
  'records_in_closure' => ->(c) { { a: -> { { rec: Rec.new(5, true, false, false), u: Ser.new('A') } } } },
  'proc_returning_prop' => ->(c) { { a: -> { I.optional { c << :inner; { u: Ser.new('A') } } } } },
  'nested_prop_in_closure' => lambda { |c|
    { page: -> { { panel: I.always { { u: Ser.new('A'), x: I.optional { c << :x; 2 } } } } } }
  },
  'big_plain_array' => ->(c) { { a: Array.new(50) { |i| { id: i, tags: %w[x y] } } } },
  'scroll_ser' => ->(c) { { s: I.scroll { c << :s; [Ser.new('A')] } } },
  'always_deep_exec' => lambda { |c|
    { other: 1, al: I.always { { rows: [[Ser.new('A'), -> { c << :closure; 7 }],
                                     { x: I.optional { c << :optional; 8 }, u: Ser.new('B') }] } } }
  },
  'always_serializer_with_exec' => lambda { |c|
    { other: 1, al: I.always { { u: Projection.new({ name: 'A', x: -> { c << :x; 7 },
                                                   later: I.defer { c << :later; 8 } }) } } }
  },
  'optional_array_positions' => lambda { |c|
    { o: I.optional { [11, { u: Ser.new('A'), r: Raising.new },
                       [Ser.new('B'), I.optional { c << :inner; 8 }], [], {}] } }
  },
  'optional_serializer_returns_array' => lambda { |c|
    { o: I.optional { { u: Projection.new([Ser.new('A'), -> { c << :x; 7 }]) } } }
  },
  'always_empty_serializer' => ->(c) { { other: 1, al: I.always { { u: Projection.new({}) } } } },
  'always_null_serializer' => ->(c) { { other: 1, al: I.always { { u: Projection.new(nil) } } } },
  'always_string_serializer' => ->(c) { { other: 1, al: I.always { { u: DuckSer.new } } } },
  'defer_late_hash' => ->(c) { { d: I.defer(rescue: true) { { u: Ser.new('A'), lazy: LateFailure.new } } } },
  'defer_late_array' => ->(c) { { d: I.defer(rescue: true) { [Ser.new('A'), LateFailure.new] } } },
  'defer_late_plain_control' => ->(c) { { d: I.defer(rescue: true) { { u: 'A', lazy: LateFailure.new } } } },
  'defer_direct_late_serializer_control' => lambda { |c|
    { d: I.defer(rescue: true) { Projection.new({ u: 'A', lazy: LateFailure.new }) } }
  },
  'mixed_predicates_in_always' => lambda { |c|
    { al: I.always { { u: Ser.new('A'), rec: Rec.new(9, true, true, true) } } }
  },
  'optional_empty_containers' => ->(c) { { o: I.optional { { u: Ser.new('A'), h: {}, a: [], n: nil } } } },
  'always_partial_plain_array' => ->(c) { { al: I.always { { u: Ser.new('A'), rows: [11, 22, 33] } } } },
  'optional_hash_subclass' => lambda { |c|
    { o: I.optional { ActiveSupport::HashWithIndifferentAccess.new(u: Ser.new('A'), rows: [1, Ser.new('B')]) } }
  },
  'serializer_in_array_with_props' => lambda { |c|
    { al: I.always { [Projection.new({ u: Ser.new('A'), x: I.optional { c << :x; 7 } }), 11] } }
  },
}.freeze

VISITS = {
  'initial' => {},
  'only_other' => { component: true, only: %w[other] },
  'only_all' => { component: true, only: %w[a o al d m s r1 r2 r3 page top] },
  'only_children' => { component: true, only: %w[o.u al.posts al.rows.0 d.u a.u page.panel] },
  'except_children' => { component: true, only: %w[o d al m], except: %w[o.n d.r al.e al.x] },
  'except_once' => { except_once: %w[o r2 rec] },
  'only_array_positions' => { component: true, only: %w[o.1.u o.2.1 al.rows.1 al.0.u] },
  'except_parent' => { component: true, except: %w[al o d] },
  'except_exec_children' => { component: true, except: %w[al.u.x al.rows.0.1 o.1.r] },
  'reset_and_scroll' => { component: true, only: %w[al m s], reset: %w[m al.posts], scroll_intent: 'prepend' },
}.freeze

evaluator = InertiaRails::PropEvaluator.new(Object.new)
CASES.each do |name, build|
  VISITS.each do |visit_name, visit|
    [false, true].each do |devtools|
      calls = []
      recorder = devtools ? Recorder.new : nil
      line = { case: name, visit: visit_name, devtools: devtools }
      begin
        props, meta = InertiaRails::PropsResolver.new(build.call(calls), evaluator: evaluator, visit: visit,
                                                                         recorder: recorder).resolve
        line.merge!(props: dump(props), json: props.to_json, meta: dump(meta), calls: calls.map(&:to_s),
                    recorder: recorder&.log&.map { |e| e.map(&:to_s) })
      rescue StandardError => e
        line.merge!(error: "#{e.class}: #{e.message}", calls: calls.map(&:to_s))
      end
      puts JSON.generate(line)
    end
  end
end
