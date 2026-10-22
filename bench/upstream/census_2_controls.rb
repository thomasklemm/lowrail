# frozen_string_literal: true

# Run unbundled with one Rails checkout; compare stdout between base and draft.
require "json"
require "digest"
require "tmpdir"
root = File.expand_path(ARGV.fetch(0))
%w[activesupport activemodel activerecord actionview actionpack].each do |component|
  $LOAD_PATH.unshift "#{root}/#{component}/lib"
end
require "active_support"
require "active_support/cache"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/hash/keys"
require "active_record"

def snapshot(value)
  case value
  when String
    [value.class.name, value.encoding.name, value.unpack1("H*"), value.frozen?]
  when Array
    value.map { snapshot(_1) }
  when Hash
    value.map { |key, item| [snapshot(key), snapshot(item)] }
  else
    value
  end
end

rows = []
errors = []
ActiveSupport.error_reporter.subscribe(Object.new.tap do |subscriber|
  subscriber.define_singleton_method(:report) { |error, **| errors << error.class.name }
end)
coder = ActiveSupport::Cache::Coder.new(Marshal, Zlib)
values = [nil, false, 37, "", "héllo", "\xFF\x00".b, "ascii".encode("US-ASCII"),
  "é".encode("ISO-8859-1"), ["nested", { a: [17, false] }], "long" * 300]
versions = [nil, "", "v-17", "v-17".b, "é".encode("ISO-8859-1"), "\x04\x08prefix".b]
values.product(versions, [nil, 1.0, 4_000_000_000.0], [false, true]).each do |value, version, expiry, compressed|
  entry = ActiveSupport::Cache::Entry.new(value, version: version, expires_at: expiry)
  dumped = compressed ? coder.dump_compressed(entry, 1) : coder.dump(entry)
  original = dumped.dup
  loaded = coder.load(dumped)
  raise "round trip" unless loaded.value == value && loaded.version == version && loaded.expires_at == expiry
  raise "source mutation" unless dumped == original && dumped.frozen?
  rows << [snapshot(loaded.value), snapshot(loaded.version), loaded.expires_at,
    loaded.mismatched?("different"), snapshot(dumped)]
end

# Asymmetric byte lengths, every truncation, and signed negative/oversized
# lengths distinguish the exact byteslice boundary from character counts.
payload = coder.dump(ActiveSupport::Cache::Entry.new("héllö\x00世界", version: "ö-7"))
malformed = (0..payload.bytesize).map { payload.byteslice(0, _1) }
[-2_147_483_648, -37, -2, -1, 0, 1, 7, 2_147_483_647].each do |length|
  bytes = payload.dup
  bytes[11, 4] = [length].pack("l<")
  malformed << bytes
end
random = Random.new(41231)
250.times do
  bytes = payload.dup
  random.rand(1..4).times { bytes.setbyte(random.rand(bytes.bytesize), random.rand(256)) }
  malformed << bytes
end
malformed.each do |bytes|
  errors.clear
  result = begin
    loaded = coder.load(bytes)
    loaded && [snapshot(loaded.value), snapshot(loaded.version), loaded.expires_at]
  rescue => error
    ["exception", error.class.name]
  end
  rows << [result, errors.dup]
end

Dir.mktmpdir("census-2-cache") do |dir|
  stores = {
    memory: ActiveSupport::Cache::MemoryStore.new,
    file: ActiveSupport::Cache::FileStore.new(dir),
    redis: ActiveSupport::Cache::RedisCacheStore.new(url: "redis://127.0.0.1:6379/9", namespace: "u2-controls"),
    memcache: ActiveSupport::Cache::MemCacheStore.new("127.0.0.1:11211", namespace: "u2-controls", pool: false)
  }
  stores.each do |name, store|
    values.product(versions).each_with_index do |(value, version), index|
      key = "case-#{index}"
      raise "write" unless store.write(key, value, version: version)
      read = store.read(key, version: version)
      fetched = store.fetch(key, version: version) { raise "unexpected miss" }
      raise "public value" unless read == value && fetched == value
      rows << [name, snapshot(read), snapshot(fetched), snapshot(store.read(key, version: "mismatch"))]
      if read.is_a?(String)
        read << "changed"
        raise "alias" unless store.read(key, version: version) == value
      end
      store.delete(key)
    end
    store.write("expired", "gone", expires_at: Time.at(1))
    rows << [name, store.read("expired"), store.fetch("expired") { "generated" }, store.read("expired")]
    store.delete("expired")
  end
end

# Boundary witnesses for rejected lower-ranked sharing/prefix shortcuts.
require "action_view"
require "action_view/helpers"
require "action_view/structured_event_subscriber"
helper = Object.new.extend(ActionView::Helpers::AssetUrlHelper)
options = { type: :stylesheet, extname: ".css" }
rows << ["extname", helper.compute_asset_extname("x.css?query", options), helper.compute_asset_extname("x.css", options)]
source = { "name" => "first" }
keys = source.stringify_keys
keys["name"] = "other"
raise "hash alias" unless source["name"] == "first"
rows << ["stringify_keys", keys.equal?(source), source]
formatter = Object.new.extend(ActionView::StructuredEventSubscriber::Utils)
ActionView::StructuredEventSubscriber.rails_root = "/app/"
rows << ["root-not-prefix", formatter.send(:from_rails_root, "other/app/views/part.html.erb")]

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
pool = ActiveRecord::Base.connection_pool
events = []
subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  events << [event.payload[:sql], event.payload[:exception]&.first] unless event.payload[:name] == "SCHEMA"
end
10.times { pool.with_connection { |connection| raise "query" unless connection.select_value("SELECT 37") == 37 } }
10.times { pool.with_connection { } }
pool.with_connection do |connection|
  intent = ActiveRecord::ConnectionAdapters::QueryIntent.new(adapter: connection,
    raw_sql: "SELECT 19", name: "unfinished", materialize_transactions: false)
  connection.start_intent_log(intent)
end
rows << ["pool", events]
ActiveSupport::Notifications.unsubscribe(subscriber)
pool.disconnect!

puts JSON.generate(rows)
