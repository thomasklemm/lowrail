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
}.freeze

VISITS = {
  'initial' => {},
  'only_other' => { component: true, only: %w[other] },
  'only_all' => { component: true, only: %w[a o al d m s r1 r2 r3 page top] },
  'only_children' => { component: true, only: %w[o.u al.posts al.rows.0 d.u a.u page.panel] },
  'except_children' => { component: true, only: %w[o d al m], except: %w[o.n d.r al.e al.x] },
  'except_once' => { except_once: %w[o r2 rec] },
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
