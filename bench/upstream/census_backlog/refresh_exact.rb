# frozen_string_literal: true

load File.join(__dir__, "refresh_cases.rb")
require "json"

def outcome
  ["return", yield]
rescue => error
  [error.class.name, error.message.lines.first.strip.gsub(/0x[0-9a-f]+/, "0xADDRESS")]
end

if ARGV.first == "nil"
  calls = []
  opaque = Object.new
  def opaque.respond_to_missing?(*) = raise("unexpected respond_to_missing?")
  def opaque.method_missing(*) = raise("unexpected method_missing")
  array = Class.new(Array) { def each(*) = raise("unexpected each") }.new([opaque]).freeze
  hash = Class.new(Hash) { def to_hash = raise("unexpected to_hash") }.new.freeze
  string = Class.new(String) { def to_s = raise("unexpected to_s") }.new("upload").freeze
  [[], [:upload], [string], [opaque, array, hash], [nil, false, "mutable"]].each_with_index do |args, i|
    %i[try try!].each do |name|
      [nil, -> { raise "block must not run" }, ->(_one, _two) { raise "block must not run" }].each_with_index do |block, b|
        [{}, { mutable: array }, { frozen: opaque }.freeze].each_with_index do |kwargs, k|
          original = kwargs.dup
          result = nil.public_send(name, *args, **kwargs, &block)
          raise "not nil" unless result.nil?
          raise "mutated keywords" unless kwargs == original
          calls << [i, name, b, k, result]
        end
      end
    end
  end
  converter = Object.new
  converter.define_singleton_method(:to_proc) { calls << "to_proc"; -> { raise "called" } }
  calls << outcome { nil.try(:x, &converter) }
  calls << outcome { nil.try!(:x, &converter) }
  calls << outcome { nil.try(&Object.new) }

  [:valid, :raises, :invalid, :missing].each do |kind|
    %i[try try!].each do |name|
      log = []
      keywords = Object.new
      unless kind == :missing
        keywords.define_singleton_method(:to_hash) do
          log << :to_hash
          raise "keyword conversion" if kind == :raises
          kind == :valid ? { upload: "example" } : nil
        end
      end
      result = outcome do
        name == :try ? nil.try(:upload, **keywords) : nil.try!(:upload, **keywords)
      end
      calls << ["direct_keywords", kind, name, result, log]
    end
  end
  require "action_controller"
  params = ActionController::Parameters.new(upload: "example")
  calls << ["unpermitted", outcome { nil.try(:upload, **params) }]
  calls << ["unpermitted_bang", outcome { nil.try!(:upload, **params) }]
  puts JSON.generate(calls)
else
  results = []
  [:symbol, :block, :object, :plain].each do |kind|
    object = RefreshCallbacks.new
    results << [kind, outcome { object.run(kind) }, object.count]
    results << [kind, "frozen", outcome { object.freeze.run(kind) }]
  end

  [false, true].each do |skip|
    [false, true].each do |halt|
      [:symbol, :object, :proc2, :proc1, :proc0, :missing].each do |kind|
        log = []
        klass = Class.new do
          include ActiveSupport::Callbacks
          define_callbacks :work
          attr_accessor :log
          def wrap
            log << :enter
            yield
          ensure
            log << :leave
          end
          private :wrap
          def method_missing(name, *)
            return super unless name == :missing
            log << :missing
            yield
          end
          def respond_to_missing?(name, *) = name == :missing || super
        end
        handler = Object.new
        handler.define_singleton_method(:around) { |r, &inner| r.log << :object; inner.call; r.log << :after_object }
        filter = {
          symbol: :wrap,
          missing: :missing,
          object: handler,
          proc2: ->(r, inner) { r.log << :proc2; inner.call; r.log << :after_proc2 },
          proc1: ->(r) { r.log << :proc1 },
          proc0: -> { log << :proc0 },
        }.fetch(kind)
        klass.set_callback(:work, :before) { throw :abort if halt }
        klass.set_callback :work, :around, filter, unless: -> { skip }
        klass.set_callback(:work, :after) { log << :after }
        object = klass.new
        object.log = log
        results << [kind, skip, halt, outcome { object.run_callbacks(:work) { log << :body; :value } }, log.dup]
        log.clear
        results << [kind, skip, halt, "raises", outcome { object.run_callbacks(:work) { raise "from body" } }, log.dup]
        log.clear
        fiber = Fiber.new { object.run_callbacks(:work) { Fiber.yield(:suspended); :value } }
        first = outcome { fiber.resume }
        second = fiber.alive? ? outcome { fiber.resume } : nil
        results << [kind, skip, halt, "fiber", first, second, log.dup]
      end
    end
  end

  subclass = Class.new(RefreshCallbacks) do
    attr_accessor :log
    def send(name, *args, &block)
      log << ["send", name, args.length]
      super
    end
    def instance_exec(*args, &block)
      log << ["instance_exec", args.length, args.first.equal?(self)]
      super
    end
    def to_ary = raise("callback receiver must not be converted")
  end
  [:symbol, :block, :object].each do |kind|
    object = subclass.new
    object.log = []
    results << ["subclass", kind, object.run(kind), object.log]
  end
  puts JSON.generate(results)
end
