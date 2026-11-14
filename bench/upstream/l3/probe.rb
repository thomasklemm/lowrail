# frozen_string_literal: true

# L3 differential probe: what attributes_for_database, attributes_before_type_cast, Marshal and the MessagePack
# coder return, and what a record looks like after them, for one Rails tree. Diff the output of two trees.
#
#   RAILS=TREE BUNDLE_GEMFILE=... ruby probe.rb dump DIR          writes Marshal (and MessagePack) payloads to DIR
#   RAILS=TREE BUNDLE_GEMFILE=... ruby probe.rb probe [DIR...]    prints every case, then loads the payloads in DIRs
#
# ADAPTER=postgresql runs on database l3_probe instead of a fresh SQLite file. Non-deterministic ciphertext is shown
# decrypted, so output only differs when a value does.
require "bundler/setup"
require "active_record"
require "active_support/message_pack"
require "active_record/message_pack"
require "active_support/testing/time_helpers"
require "tmpdir"

rails = ENV.fetch("RAILS")
unless ActiveRecord::Base.method(:find).source_location.first.start_with?(File.expand_path(rails) + "/")
  abort "Active Record not loaded from #{rails}"
end

ADAPTER = ENV.fetch("ADAPTER", "sqlite3")
if ADAPTER == "sqlite3"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(Dir.mktmpdir, "probe.sqlite3"))
else
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "l3_probe")
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord.default_timezone = :utc
ActiveRecord::Encryption.configure(
  primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32
)
Time.zone = "UTC"
include ActiveSupport::Testing::TimeHelpers
travel_to Time.utc(2026, 6, 1, 9, 30, 15.25r)
DETERMINISTIC = ActiveRecord::Encryption::DeterministicKeyProvider.new(ActiveRecord::Encryption.config.deterministic_key)

ActiveRecord::Schema.define do
  create_table(:people, force: true) do |t|
    t.string :type
    t.string :name
    t.integer :age
    t.boolean :active
    t.datetime :born_at
    t.date :day
    t.decimal :balance, precision: 10, scale: 2
    t.float :ratio
    t.text :prefs
    t.text :tags
    t.json :meta
    t.string :secret
    t.string :det
    t.binary :blob
    t.integer :status
    t.timestamps
  end
  create_table(:notes, force: true) do |t|
    t.integer :person_id
    t.string :body
  end
end

class Note < ActiveRecord::Base
  belongs_to :person
end

class Person < ActiveRecord::Base
  serialize :prefs, coder: JSON
  serialize :tags, type: Array, coder: YAML
  encrypts :secret
  encrypts :det, deterministic: true
  alias_attribute :full_name, :name
  attribute :virtual, :string, default: "v"
  attribute :later, :datetime, default: -> { Time.utc(2020, 1, 2, 3, 4, 5) }
  enum :status, { draft: 0, live: 1 }
  has_many :notes
end

class Admin < Person
  attribute :level, :integer, default: 3
end

T0 = Time.utc(2026, 1, 1, 12, 0, 0)
ATTRS = {
  name: "Ann", age: 41, active: true, born_at: Time.utc(1985, 5, 6, 7, 8, 9.123456r), day: Date.new(2026, 2, 3),
  balance: BigDecimal("12.34"), ratio: 0.25, prefs: { "theme" => "dark", "n" => [1, 2] }, tags: %w[a b],
  meta: { "k" => "v", "list" => [1, { "x" => nil }] }, secret: "s3cret", det: "same", blob: "\x00\x01bin".b,
  status: :live, created_at: T0, updated_at: T0
}.freeze

def seed
  Note.delete_all
  Person.delete_all
  p1 = Person.create!(ATTRS)
  Admin.create!(ATTRS.merge(name: "Adm", level: 7))
  Person.create!(name: "Nil", created_at: T0, updated_at: T0)
  Note.create!(person: p1, body: "n1")
  Note.create!(person: p1, body: "n2")
  ids = Person.order(:id).pluck(:id)
  $ids = ids
end

def encrypted?(value)
  value.is_a?(String) && value.start_with?('{"p":')
end

def norm(value)
  case value
  when Hash then value.to_h { |k, v| [k, norm(v)] }
  when Array then value.map { |v| norm(v) }
  when String
    if encrypted?(value)
      plain = begin
        ActiveRecord::Encryption.encryptor.decrypt(value)
      rescue ActiveRecord::Encryption::Errors::Decryption
        ActiveRecord::Encryption.encryptor.decrypt(value, key_provider: DETERMINISTIC)
      end
      "ENC[#{plain}]"
    else
      "#{value.class.name}#{value.frozen? ? "(frozen)" : ""}:#{value.encoding}:#{value.inspect}"
    end
  when Time, ActiveSupport::TimeWithZone then "#{value.class.name}:#{value.iso8601(6)}:#{value.utc_offset}"
  when nil, true, false, Integer, Float, Symbol then value.inspect
  else "#{value.class.name}:#{value.inspect.gsub(/0x\h+/, "0x")}"
  end
end

def show(label)
  value = yield
  puts "  #{label}: #{norm(value).inspect}"
rescue => e
  puts "  #{label}: raised #{e.class}: #{e.message[0, 120]}"
end

MSGPACK = MessagePack::Factory.new.tap do |factory|
  ActiveRecord::MessagePack::Extensions.install(factory)
  ActiveSupport::MessagePack::Extensions.install(factory)
end

def state(rec, tag = "")
  show("#{tag}attributes") { rec.attributes }
  show("#{tag}changes") { rec.changes }
  show("#{tag}accessed_fields") { rec.accessed_fields.sort }
  show("#{tag}new_record?") { rec.new_record? }
  show("#{tag}frozen?") { rec.frozen? }
end

OPS = {
  for_database: ->(rec) { show("attributes_for_database") { rec.attributes_for_database } },
  for_database_stable: ->(rec) {
    show("attributes_for_database twice ==") { rec.attributes_for_database == rec.attributes_for_database }
  },
  before_type_cast: ->(rec) { show("attributes_before_type_cast") { rec.attributes_before_type_cast } },
  read: ->(rec) { show("read name/prefs/born_at") { [rec.name, rec.prefs, rec.born_at] } },
  read_all: ->(rec) { show("read all") { rec.attribute_names.map { |n| rec.public_send(n) rescue $!.class } } },
  write: ->(rec) { show("write") { rec.name = "W"; rec.tags = %w[w]; rec.meta = { "w" => 1 }; rec.secret = "new" } },
  mutate: ->(rec) { show("mutate in place") { rec.prefs["theme"] = "light"; rec.tags << "c"; rec.name << "!" } },
  for_db_name: ->(rec) { show("name_for_database") { [rec.name_for_database, rec.read_attribute_before_type_cast(:name)] } },
  state: ->(rec) { state(rec) },
  marshal: ->(rec) {
    show("Marshal stable") { Marshal.dump(rec) == Marshal.dump(rec) }
    copy = Marshal.load(Marshal.dump(rec))
    state(copy, "marshal copy ")
    show("marshal copy attributes_for_database") { copy.attributes_for_database }
    show("marshal copy notes") { copy.association(:notes).loaded? ? copy.notes.map(&:body) : :not_loaded }
  },
  msgpack: ->(rec) {
    copy = MSGPACK.load(MSGPACK.dump(rec))
    state(copy, "msgpack copy ")
    show("msgpack copy attributes_before_type_cast") { copy.attributes_before_type_cast }
  },
  save: ->(rec) {
    show("save") { rec.save }
    show("after save attributes_before_type_cast") { rec.attributes_before_type_cast }
    show("after save attributes_for_database") { rec.attributes_for_database }
    show("after save changed?/previous_changes") { [rec.changed?, rec.previous_changes.keys.sort] }
    show("after save reload") { rec.reload.attributes } if rec.persisted? && !rec.readonly?
  },
}.freeze

SEQUENCES = {
  "dump first" => %i[for_database for_database_stable before_type_cast state read state],
  "btc first" => %i[before_type_cast state for_database state],
  "read first" => %i[read for_database before_type_cast state],
  "read all first" => %i[read_all for_database before_type_cast state],
  "write then dump" => %i[write for_database before_type_cast for_db_name state],
  "mutate then dump" => %i[read mutate for_database for_database_stable before_type_cast state],
  "dump then mutate" => %i[read for_database mutate for_database before_type_cast state],
  "marshal" => %i[marshal for_database state],
  "msgpack" => %i[msgpack for_database state],
  "dump then save" => %i[for_database save],
  "btc then save" => %i[before_type_cast save],
  "write, dump, save" => %i[write for_database save marshal],
}.freeze

def scenarios
  id1, id2, id3 = $ids
  {
    "loaded" => -> { Person.find(id1) },
    "loaded nil columns" => -> { Person.find(id3) },
    "new full" => -> { Person.new(ATTRS) },
    "new empty" => -> { Person.new },
    "new by alias" => -> { Person.new(full_name: "Al") },
    "created" => -> { Person.create!(ATTRS.merge(name: "Cre")) },
    "partial select" => -> { Person.select(:id, :name, :prefs, :secret).find(id1) },
    "partial select with extras" => -> { Person.select("people.*, age + 1 AS age_plus, name AS nm").find(id1) },
    "partial select alias" => -> { Person.select(:id, :full_name).find(id1) },
    "sti subclass" => -> { Admin.find(id2) },
    "sti via parent" => -> { Person.find(id2) },
    "becomes" => -> { Person.find(id1).becomes(Admin) },
    "find_by_sql" => -> { Person.find_by_sql("SELECT id, name, prefs, 1 AS one FROM people ORDER BY id").first },
    "readonly" => -> { Person.readonly.find(id1) },
    "includes notes" => -> { Person.includes(:notes).find(id1) },
    "dup" => -> { Person.find(id1).dup },
    "frozen" => -> { Person.find(id1).freeze },
  }
end

def probe(dirs)
  scenarios.each_key do |scenario|
    SEQUENCES.each do |seq_name, ops|
      seed
      puts "#{scenario} / #{seq_name}"
      begin
        rec = scenarios.fetch(scenario).()
      rescue => e
        puts "  build raised #{e.class}: #{e.message[0, 120]}"
        next
      end
      ops.each { |op| OPS.fetch(op).(rec) }
    end
  end
  dirs.each do |dir|
    Dir[File.join(dir, "*.marshal")].sort.each do |path|
      SEQUENCES.each do |seq_name, ops|
        seed
        puts "payload #{File.basename(File.dirname(path))}/#{File.basename(path)} / #{seq_name}"
        rec = begin
          Marshal.load(File.binread(path))
        rescue => e
          puts "  load raised #{e.class}: #{e.message[0, 120]}"
          next
        end
        ops.each { |op| OPS.fetch(op).(rec) }
      end
    end
    Dir[File.join(dir, "*.msgpack")].sort.each do |path|
      seed
      puts "payload #{File.basename(File.dirname(path))}/#{File.basename(path)}"
      rec = MSGPACK.load(File.binread(path))
      SEQUENCES.fetch("dump first").each { |op| OPS.fetch(op).(rec) }
      OPS.fetch(:save).(rec)
    end
  end
end

def dump(dir)
  FileUtils.mkdir_p(dir)
  formats = ActiveRecord::Marshalling.respond_to?(:format_version=) ? [7.1] : []
  formats << 6.1 if ActiveRecord.version < Gem::Version.new("8.2.0.alpha")
  %w[loaded new\ full partial\ select sti\ subclass includes\ notes created].each do |scenario|
    seed
    formats.each do |format|
      ActiveRecord::Marshalling.format_version = format
      rec = scenarios.fetch(scenario).()
      rec.name if rec.has_attribute?(:name)
      File.binwrite(File.join(dir, "#{scenario.tr(" ", "_")}-#{format}.marshal"), Marshal.dump(rec))
      File.binwrite(File.join(dir, "#{scenario.tr(" ", "_")}.msgpack"), MSGPACK.dump(rec))
      rec = scenarios.fetch(scenario).()
      rec.name = "dirty" if rec.has_attribute?(:name)
      rec.prefs = { "dirty" => true } if rec.has_attribute?(:prefs)
      File.binwrite(File.join(dir, "#{scenario.tr(" ", "_")}-dirty-#{format}.marshal"), Marshal.dump(rec))
    end
  end
end

seed
case ARGV.shift
when "dump" then dump(ARGV.fetch(0))
when "probe" then probe(ARGV)
else abort "usage: probe.rb dump DIR | probe [DIR...]"
end
