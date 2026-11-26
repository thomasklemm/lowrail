# HM1 differential: run once per hashie checkout (ruby -I CHECKOUT/lib hm1_diff.rb > out) and diff the outputs.
# Every observable result of respond_to?, respond_to_missing?, writes (including the built-in-method warning) and
# dynamic method calls, for Mash and its Mash extensions, over keys of every shape. Expected difference:
# respond_to_missing? called directly with one argument or three, which Ruby never does (it passes two).
require "hashie"
require "logger"
require "stringio"

LIB = File.dirname($LOADED_FEATURES.grep(%r{/hashie\.rb\z}).first)

log = StringIO.new
Hashie.logger = Logger.new(log)
Hashie.logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }

bases = %w[a abc zip count class key keys merge to_s hash name values method_missing respond_to? frozen object_id
           initialize __send__ dup _ __ ? ! = é ünïcödé ﬆ 名前 a-b a.b 1 9x].flat_map do |b|
  [b, "#{b}?", "#{b}!", "#{b}=", "#{b}_", "#{b}??", "#{b}=?"]
end
keys = bases.flat_map { |b| [b, b.to_sym] } + [:"", "", 1, 1.5, nil, true, Object, [1], :a.to_proc]

classes = {
  "Mash" => Hashie::Mash,
  "StrictKeyAccess" => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::StrictKeyAccess },
  "PermissiveRespondTo" => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::PermissiveRespondTo },
  "KeepOriginalKeys" => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::KeepOriginalKeys },
  "SymbolizeKeys" => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::SymbolizeKeys },
  "DefineAccessors" => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::DefineAccessors },
  "super *args" => Class.new(Hashie::Mash) { def respond_to_missing?(name, *args) = super },
  "super(name, priv)" => Class.new(Hashie::Mash) { def respond_to_missing?(name, priv = false) = super(name, priv) },
  "quiet" => Class.new(Hashie::Mash) { disable_warnings },
  "quiet zip" => Class.new(Hashie::Mash) { disable_warnings :zip, :count },
}

def outcome
  value = yield
  value = value.to_hash if value.is_a?(Hashie::Mash)
  [:ok, value.inspect]
rescue Exception => e # rubocop:disable Lint/RescueException
  [:raise, e.class.name, e.message.sub(/ for #<.*\z/m, "").sub(/0x\h+/, "0x")]
end

classes.each do |label, klass|
  [{}, { "abc" => 1, "zip" => 2, "count?" => 3, "a=" => 4, "é" => 5 }].each do |seed|
    keys.each do |key|
      mash = outcome { klass.new(seed) }.first == :ok ? klass.new(seed) : next
      log.truncate(0)
      log.rewind
      rows = [
        ["respond_to?", outcome { mash.respond_to?(key) }],
        ["respond_to? private", outcome { mash.respond_to?(key, true) }],
        ["respond_to_missing? 1", outcome { mash.send(:respond_to_missing?, key) }],
        ["respond_to_missing? 2", outcome { mash.send(:respond_to_missing?, key, false) }],
        ["respond_to_missing? 3", outcome { mash.send(:respond_to_missing?, key, true, 1) }],
        ["method", outcome { mash.method(key).arity }],
        ["write", outcome { mash[key] = :v }],
        ["after write", outcome { [mash.to_hash, mash.respond_to?(key)] }],
        ["write again", outcome { mash[key] = :w }],
        ["call", (key.is_a?(String) || key.is_a?(Symbol)) && !key.to_s.empty? ? outcome { mash.public_send(key, *(key.to_s.end_with?("=") ? [:x] : [])) } : nil],
        ["after call", outcome { mash.to_hash }],
        ["new", outcome { klass.new(key => 1).to_hash }],
        ["log", log.string],
      ]
      # Object addresses and hash values differ between any two processes.
      puts [label, seed.size, key.inspect, rows].inspect.gsub(LIB, "LIB").gsub(/0x\h+/, "0x").gsub(/\["call", \[:ok, "-?\d{6,}"\]\]/, '["call", :number]')
    end
  end
end
