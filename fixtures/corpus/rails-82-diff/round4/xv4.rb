# Cross-version harness, round 4: Redis/Memcache/Solid Cache stores, Active Storage, Action Cable and Turbo
# stream names, Active Record encryption with previous schemes. Same shape as xv.rb:
#   XV_TREE=81|main BUNDLE_GEMFILE=.../Gemfile bundle exec ruby xv4.rb setup BASE
#   ... xv4.rb write BASE                 # data under the writer's name; stores namespaced by it
#   ... xv4.rb read BASE SRC OUT          # each reader works on its own copy of the database and storage
# XV_ENC picks the encryption configuration (see ENC_CONFIGS) separately for writer and reader.
MODE, BASE, *REST = ARGV
TREE = ENV.fetch("XV_TREE")
SEED = Integer(ENV.fetch("SEED", "20261104"))
N = Integer(ENV.fetch("N", "600"))
ENC = ENV.fetch("XV_ENC", "base")
CFG = "enc_#{ENC}"
require "fileutils"
SRC = %w[read debug].include?(MODE) ? REST[0] : "#{TREE}-#{CFG}"
WORK = %w[read debug].include?(MODE) ? "#{BASE}/readers/#{TREE}-from-#{SRC}" : BASE
if %w[read debug].include?(MODE)
  FileUtils.rm_rf(WORK)
  FileUtils.mkdir_p(WORK)
  FileUtils.cp("#{BASE}/db.sqlite3", "#{WORK}/db.sqlite3")
  FileUtils.cp_r("#{BASE}/storage", "#{WORK}/storage") if File.directory?("#{BASE}/storage")
end
ENV["SECRET_KEY_BASE"] = "s" * 128
ENV["RAILS_ENV"] = "production"
ENV["DATABASE_URL"] = "sqlite3:#{WORK}/db.sqlite3"
FileUtils.mkdir_p("#{BASE}/root/config")
File.write("#{BASE}/root/config/storage.yml", "local:\n  service: Disk\n  root: <%= ENV.fetch('XV_STORAGE') %>\n")
ENV["XV_STORAGE"] = "#{WORK}/storage"
File.write("#{BASE}/root/config/cache.yml", "production:\n  store_options:\n    max_age: 31536000\n")

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_job/railtie"
require "active_storage/engine"
require "action_cable/engine"
require "turbo-rails"
require "solid_cache"

OLD_KEYS = { primary_key: "o" * 32, deterministic_key: "q" * 32, key_derivation_salt: "k" * 32 }.freeze
NEW_KEYS = { primary_key: "p" * 32, deterministic_key: "d" * 32, key_derivation_salt: "k" * 32 }.freeze
# Global keys and per-attribute declarations for each configuration. "old" writers use OLD_KEYS; readers of the
# rotation configurations know the old keys or scheme only through `previous`.
ENC_CONFIGS = {
  "base" => { keys: NEW_KEYS },
  "old" => { keys: OLD_KEYS },
  # Key rotation as the guides describe it: a list of primary keys (the last one encrypts), and the old
  # deterministic key through a previous scheme.
  "rotated" => { keys: NEW_KEYS.merge(primary_key: [OLD_KEYS[:primary_key], NEW_KEYS[:primary_key]]), previous_det: OLD_KEYS[:deterministic_key] },
  "plain" => { keys: NEW_KEYS, plain: true },
  "unencrypted_ok" => { keys: NEW_KEYS, support_unencrypted_data: true },
  "nondet" => { keys: NEW_KEYS, nondet: true },
  "det_prev_nondet" => { keys: NEW_KEYS, det_prev_nondet: true },
  "attr_prev_key" => { keys: NEW_KEYS, attr_prev_key: true },
}.freeze
EC = ENC_CONFIGS.fetch(ENC)

class XvApp < Rails::Application
  config.root = "#{BASE}/root"
  config.load_defaults "8.1"
  config.eager_load = false
  config.secret_key_base = "s" * 128
  config.logger = Logger.new(nil)
  config.active_support.report_deprecations = false
  config.hosts.clear
  config.active_storage.service = :local
  config.active_storage.variant_processor = :vips
  config.active_storage.resolve_model_to_route = :rails_storage_redirect
  config.action_cable.mount_path = nil
  config.active_job.queue_adapter = :inline
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.active_record.encryption.primary_key = EC[:keys][:primary_key]
  config.active_record.encryption.deterministic_key = EC[:keys][:deterministic_key]
  config.active_record.encryption.key_derivation_salt = EC[:keys][:key_derivation_salt]
  config.active_record.encryption.support_unencrypted_data = true if EC[:support_unencrypted_data]
  config.active_record.encryption.extend_queries = true if EC[:support_unencrypted_data]
end
Rails.application.initialize!
# Built after boot: a key provider reads the encryption config, which must not load before initialization.
ActiveRecord::Encryption.config.previous = [{ key_provider: ActiveRecord::Encryption::DeterministicKeyProvider.new(EC[:previous_det]), deterministic: true }] if EC[:previous_det]
ActionCable.server.config.cable = { adapter: "redis", url: "redis://localhost:6390/0", channel_prefix: "xv" }
ActionCable.server.config.logger = Logger.new(nil)
require "active_support/message_pack"
require "action_cable/channel/test_case"

if MODE == "setup"
  c = ActiveRecord::Base.connection
  c.create_table(:posts, force: true) { |t| t.string :title; t.text :body; t.datetime :published_at; t.decimal :score, precision: 10, scale: 2; t.json :meta; t.integer :flags }
  c.create_table(:comments, force: true) { |t| t.integer :post_id; t.string :body }
  c.create_table(:vault, force: true) { |t| t.string :src; t.integer :i; t.text :a; t.text :b; t.text :c; t.text :d }
  load Dir["#{Gem.loaded_specs["activestorage"].full_gem_path}/db/migrate/*create_active_storage_tables.rb"].first
  CreateActiveStorageTables.migrate(:up)
  load "#{Gem.loaded_specs["solid_cache"].full_gem_path}/lib/generators/solid_cache/install/templates/db/cache_schema.rb"
end

class ApplicationController < ActionController::Base; end
class Post < ActiveRecord::Base
  has_many :comments
  has_one_attached :cover
  has_many_attached :files
end
class Comment < ActiveRecord::Base
  belongs_to :post
end
class Vault < ActiveRecord::Base
  self.table_name = "vault"
  if EC[:plain]
    # Writer without encryption: the columns hold plain text.
  elsif EC[:nondet]
    encrypts :a; encrypts :b; encrypts :c; encrypts :d
  elsif EC[:det_prev_nondet]
    encrypts :a, deterministic: true, previous: { deterministic: false }
    encrypts :b, deterministic: true, previous: { deterministic: false }
    encrypts :c, deterministic: true, downcase: true, previous: { deterministic: false }
    encrypts :d, previous: { deterministic: false }
  elsif EC[:attr_prev_key]
    encrypts :a, previous: { key: "o" * 32 }
    encrypts :b, deterministic: true, previous: { key: "o" * 32, deterministic: true }
    encrypts :c, deterministic: true, downcase: true
    encrypts :d
  else
    encrypts :a
    encrypts :b, deterministic: true
    encrypts :c, deterministic: true, downcase: true
    encrypts :d, compress: false
  end
end
module ApplicationCable
  class Channel < ActionCable::Channel::Base; end
end
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room]}"
    stream_for Post.find(params[:post_id]) if params[:post_id]
  end
end

# Canonical form and generators shared with round 3.
src3 = File.read(File.join(__dir__, "xv.rb"))
eval(src3[src3.index("# ---- Canonical form")...src3.index("def blobdir")], binding, "xv.rb")
# Tempfile names in error messages differ per process; drop them.
def guard
  yield
rescue Exception => e
  raise if e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
  "!#{e.class}: #{e.message.to_s.gsub("\n", "\\n").gsub(/0x\h{6,}/, "0x").gsub(%r{/tmp/[^"\s]+}, "/tmp/T")[0, 300]}"
end
def blobdir(src) = "#{BASE}/blobs/#{src}"
def blob_write(src, name, data)
  FileUtils.mkdir_p(blobdir(src))
  File.binwrite("#{blobdir(src)}/#{name}", Marshal.dump(data))
end
def blob_read(src, name) = Marshal.load(File.binread("#{blobdir(src)}/#{name}"))

if MODE != "setup"
VALUES = Array.new(N) { rvalue }
JVALUES = Array.new(N) { rjsonish }
SECRETS = ["", "plain", "Mixed Case", "é日本😀", "x" * 500, nil] + Array.new(N / 3) { rstr(R.rand(2) == 0 ? 30 : 400) }
FILES = Array.new(N / 6) { |i| [pick(%w[png jpg txt bin pdf svg html]), R.rand(1..5000), rstr(10), pick(["", "a b.png", "ü日本.txt", "x\"y.bin", "..%2f.png", "a/b.jpg"])] }
VARIATIONS = Array.new(N / 6) { pick([{ resize_to_limit: [10, 10] }, { resize_to_fill: [7, 9] }, { resize_to_limit: [20, 20], format: :webp }, { rotate: 90 }, { resize_to_limit: [5, 5], saver: { quality: 50 } }, { crop: [0, 0, 4, 4] }, { resize_and_pad: [12, 12, { background: [255, 0, 0] }] }]) }
end

CACHE_KINDS = {
  "redis" => ->(ns, o) { ActiveSupport::Cache::RedisCacheStore.new(url: "redis://localhost:6390/1", namespace: ns, **o) },
  "mem" => ->(ns, o) { ActiveSupport::Cache::MemCacheStore.new("localhost:11290", namespace: ns, **o) },
  "solid" => ->(ns, o) { SolidCache::Store.new(namespace: ns, **o) },
}.freeze
CACHE_OPTS = { "default" => {}, "m71" => { serializer: :marshal_7_1 }, "mp" => { serializer: :message_pack }, "z" => { compress_threshold: 1 }, "mpz" => { serializer: :message_pack, compress_threshold: 1 } }.freeze
def cache_store(kind, opts, src) = CACHE_KINDS.fetch(kind).("xv4-#{src}-#{opts}", CACHE_OPTS.fetch(opts))
def kopts(i) = [{}, { expires_in: 1.year }, { version: "v#{i % 3}" }][i % 3]

def png(seed, w, h)
  require "vips"
  Vips::Image.black(w, h, bands: 3).add([seed % 255, (seed * 7) % 255, (seed * 13) % 255]).cast(:uchar).write_to_buffer(".png")
end
def file_body(ext, size, i) = %w[png jpg].include?(ext) ? png(i, 3 + size % 40, 3 + (size / 7) % 40) : (Random.new(i).bytes(size))

$t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
def phase(name) = (warn format("PHASE %-28s %.2fs", name, Process.clock_gettime(Process::CLOCK_MONOTONIC) - $t0) if ENV["XV_TIME"])
CHAT_TEST = Class.new(ActionCable::Channel::TestCase) { tests ChatChannel; def name = "xv" } if defined?(ActionCable::Channel::TestCase)
def app_get(path)
  env = Rack::MockRequest.env_for("https://example.org#{path}")
  st, h, b = Rails.application.call(env)
  body = +"".b; b.each { body << _1 }; b.close if b.respond_to?(:close)
  [st, h, body]
end
def follow(path, hops = 3)
  trail = []
  st = h = body = nil
  hops.times do
    st, h, body = app_get(path)
    trail << [st, h["content-type"], h["content-disposition"]&.sub(/filename\*=.*/, "")]
    break unless (300..399).cover?(st)
    path = URI(h["location"]).request_uri
  end
  st, h, body = app_get(path) if trail.size == hops
  "#{trail.inspect} sha=#{Digest::SHA256.hexdigest(body)[0, 16]} bytes=#{body.bytesize}"
end
def capture_cable
  sub = RedisClient.new(url: "redis://localhost:6390/0").pubsub
  sub.call("PSUBSCRIBE", "xv*")
  sub.next_event(1)
  got = []
  yield
  idle = 0
  while idle < 3
    ev = sub.next_event(0.2)
    if ev && ev[0] == "pmessage" then got << [ev[2], ev[3]]; idle = 0 else idle += 1 end
  end
  sub.close
  got
end

case MODE
when "setup"
  1.upto(20) { |i| Post.create!(id: i, title: "t#{i} <é>", body: "b" * i, published_at: Time.utc(2026, 1, i, 1, 2, 3, 456_789), score: BigDecimal("#{i}.25"), meta: { "k" => i }, flags: i * 3) }
  1.upto(40) { |i| Comment.create!(id: i, post_id: (i % 20) + 1, body: "c#{i}") }
when "write"
  if ENC == "base"
    CACHE_KINDS.each_key do |kind|
      CACHE_OPTS.each_key do |o|
        phase("cache #{kind} #{o}")
        # No clear: MemCacheStore#clear flushes the whole server and SolidCache's deletes every entry, which would
        # wipe the other tree's data. Namespaces are per writer, and all4.sh flushes the servers once.
        store = cache_store(kind, o, SRC)
        blob_write(SRC, "cache-#{kind}-#{o}", VALUES.each_with_index.map { |v, i| guard { store.write("k#{i}", v, **kopts(i)) } })
        guard { store.write_multi(Array.new(20) { ["m#{_1}", VALUES[_1]] }.to_h, expires_in: 1.year) }
        Array.new(30) { |i| guard { store.increment("c#{i}", i - 10, expires_in: 1.year) } }
      end
    end
    phase("storage")
    blobs = FILES.each_with_index.map do |(ext, size, name, fname), i|
      guard do
        b = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(file_body(ext, size, i)), filename: (fname.empty? ? "#{name}.#{ext}" : fname), metadata: { "custom" => { "i" => i } })
        Post.find(i % 20 + 1).files.attach(b)
        b.analyze if i % 3 == 0
        b
      end
    end
    out = blobs.each_with_index.map do |b, i|
      next b if b.is_a?(String)
      helpers = Rails.application.routes.url_helpers
      v = VARIATIONS[i % VARIATIONS.size]
      {
        id: b.id, key: b.key, checksum: b.checksum, signed_id: b.signed_id, signed_purpose: b.signed_id(purpose: :x), signed_exp: b.signed_id(expires_in: 1.year),
        variation_key: ActiveStorage::Variation.wrap(v).key, variable: b.variable?,
        paths: guard { [helpers.rails_blob_path(b, only_path: true), helpers.rails_blob_path(b, disposition: :attachment, only_path: true), helpers.rails_storage_proxy_path(b, only_path: true),
          (b.variable? ? [helpers.rails_representation_path(b.variant(v), only_path: true), helpers.rails_storage_proxy_path(b.variant(v), only_path: true), helpers.rails_blob_representation_path(b.signed_id, ActiveStorage::Variation.wrap(v).key, b.filename, only_path: true)] : [])].flatten },
        attachment_sgid: Post.find(i % 20 + 1).files.attachments.first.to_signed_global_id.to_s,
        direct_upload_token: guard { ActiveStorage::DirectUploadToken.generate_direct_upload_token("local", "local", nil) rescue "n/a" },
      }
    end
    blob_write(SRC, "storage", out)
    phase("vault")
    # Active Record encryption is written by every configuration below.
  end
  if ENC == "base" || %w[old plain nondet].include?(ENC)
    Vault.where(src: SRC).delete_all
    SECRETS.each_with_index { |s, i| r = guard { Vault.create!(src: SRC, i: i, a: s, b: s, c: s, d: s) }; warn "vault #{i}: #{r}" if r.is_a?(String) && i < 3 }
    blob_write(SRC, "vault_values", SECRETS)
  end
  if ENC == "base"
    phase("cable")
    wire = capture_cable do
      JVALUES.first(N / 2).each_with_index do |v, i|
        guard { ActionCable.server.broadcast("chat_#{i % 7}", v.is_a?(Hash) ? v : { "m" => v }) }
        guard { ChatChannel.broadcast_to(Post.find(i % 20 + 1), { "i" => i, "v" => v }) } if i % 3 == 0
      end
      Array.new(40) do |i|
        p = Post.find(i % 20 + 1)
        guard { Turbo::StreamsChannel.broadcast_replace_to(p, target: "t#{i}", html: "<p>#{rstr}</p>") }
        guard { Turbo::StreamsChannel.broadcast_append_to([p, :comments], target: "c", html: "<b>#{i}</b> & ü") }
        guard { Turbo::StreamsChannel.broadcast_action_to("room_#{i}", action: :update, target: "x", attributes: { "data-a" => rstr }, html: "x") }
      end
    end
    blob_write(SRC, "cable-wire", wire)
    phase("cable done")
    blob_write(SRC, "turbo-signed", Array.new(60) { |i| guard { Turbo::StreamsChannel.signed_stream_name([[Post.find(i % 20 + 1)], [Post.find(i % 20 + 1), :comments], "room_#{i}", [Comment.find(i % 40 + 1), "x", :y]][i % 4]) } })
    blob_write(SRC, "cable-ids", Array.new(60) { |i| { "channel" => "ChatChannel", "room" => [i, "r#{i}", nil, "é"][i % 4], "post_id" => (i % 2 == 0 ? (i % 20 + 1) : nil) }.compact.to_json })
    blob_write(SRC, "cable-broadcastings", Array.new(60) { |i| guard { [ChatChannel.broadcasting_for(Post.find(i % 20 + 1)), ChatChannel.broadcasting_for([Post.find(i % 20 + 1), :x]), Turbo::StreamsChannel.broadcasting_for([Post.find(i % 20 + 1), :comments])] } })
  end
when "debug"
  eval(File.read(ENV.fetch("XV_DEBUG")), binding)
when "read"
  outfile = REST[1]
  out = File.open(outfile, "w")
  emit = ->(k, v) { out.puts "#{k}\t#{v.to_s.gsub("\n", "\\n").gsub("\t", "\\t")}" }
  if File.exist?("#{blobdir(SRC)}/storage")
    CACHE_KINDS.each_key do |kind|
      CACHE_OPTS.each_key do |o|
        emit.("cache/#{kind}/#{o}/writes", rep(blob_read(SRC, "cache-#{kind}-#{o}").uniq))
        store = cache_store(kind, o, SRC)
        VALUES.each_index { |i| emit.("cache/#{kind}/#{o}/#{i}", guard { rep(store.read("k#{i}", **kopts(i).slice(:version))) }) }
        emit.("cache/#{kind}/#{o}/multi", guard { rep(store.read_multi(*Array.new(20) { "m#{_1}" })) })
        emit.("cache/#{kind}/#{o}/fetch_multi", guard { rep(store.fetch_multi(*Array.new(5) { "m#{_1}" }) { "miss" }) })
        emit.("cache/#{kind}/#{o}/exist", guard { rep(Array.new(20) { store.exist?("k#{_1}", **kopts(_1).slice(:version)) }) })
        # Counters are read without changing them, so the next reader sees the same store.
        emit.("cache/#{kind}/#{o}/counters", guard { rep(Array.new(30) { |i| store.read("c#{i}", raw: true) }) })
      end
    end
    blob_read(SRC, "storage").each_with_index do |w, i|
      next emit.("as/#{i}", "W#{w}") if w.is_a?(String)
      emit.("as/find/#{i}", guard { b = ActiveStorage::Blob.find_signed(w[:signed_id]); rep([b&.id == w[:id], ActiveStorage::Blob.find_signed(w[:signed_purpose], purpose: :x)&.id == w[:id], ActiveStorage::Blob.find_signed(w[:signed_exp])&.id == w[:id], ActiveStorage::Blob.find_signed(w[:signed_purpose])&.id]) })
      emit.("as/variation/#{i}", guard { rep(ActiveStorage::Variation.decode(w[:variation_key]).transformations) })
      emit.("as/meta/#{i}", guard { b = ActiveStorage::Blob.find(w[:id]); rep([b.filename.to_s, b.content_type, b.byte_size, b.metadata.except("analyzed", "identified"), b.checksum == w[:checksum], b.service.exist?(b.key), b.variable?, b.image?]) })
      emit.("as/attachment/#{i}", guard { a = GlobalID::Locator.locate_signed(w[:attachment_sgid]); rep([a.class.name, a&.record_type, a&.name]) })
      Array(w[:paths]).each_with_index { |p, j| emit.("as/serve/#{i}/#{j}", guard { follow(p) }) }
    end
    blob_read(SRC, "cable-wire").each_with_index do |(chan, payload), i|
      emit.("cable/wire/#{i}", guard { rep([chan, ActiveSupport::JSON.decode(payload)]) })
    end
    emit.("cable/wire-count", blob_read(SRC, "cable-wire").size)
    blob_read(SRC, "turbo-signed").each_with_index { |s, i| emit.("turbo/verify/#{i}", guard { rep(Turbo::StreamsChannel.verified_stream_name(s)) }) }
    blob_read(SRC, "cable-broadcastings").each_with_index do |names, i|
      emit.("cable/broadcasting/#{i}", guard { mine = [ChatChannel.broadcasting_for(Post.find(i % 20 + 1)), ChatChannel.broadcasting_for([Post.find(i % 20 + 1), :x]), Turbo::StreamsChannel.broadcasting_for([Post.find(i % 20 + 1), :comments])]; rep([mine == names, names]) })
    end
    blob_read(SRC, "cable-ids").each_with_index do |ident, i|
      emit.("cable/subscribe/#{i}", guard do
        # Through the public test API, which both versions share: decode the identifier as the server does and
        # subscribe with its params.
        tc = CHAT_TEST.new("xv")
        tc.before_setup
        tc.stub_connection
        params = ActiveSupport::JSON.decode(ident).except("channel")
        sub = tc.subscribe(params)
        streams = sub.respond_to?(:stream_names) ? sub.stream_names : sub.streams
        r = rep([streams.sort, sub.params.to_h.sort.to_h, sub.confirmed?, sub.rejected?, tc.transmissions.map { _1.except("identifier") }])
        tc.after_teardown rescue nil
        r
      end)
    end
  end
  if File.exist?("#{blobdir(SRC)}/vault_values")
    vals = blob_read(SRC, "vault_values")
    Vault.where(src: SRC).order(:i).each do |s|
      emit.("vault/#{ENC}/row/#{s.i}", guard { rep(%w[a b c d].map { |c| guard { s.public_send(c) } }) })
      emit.("vault/#{ENC}/lookup/#{s.i}", guard { v = vals[s.i]; rep(%w[b c].map { |c| guard { Vault.where(src: SRC, c => v).pluck(:i).include?(s.i) } }) })
      emit.("vault/#{ENC}/rewrite/#{s.i}", guard { s.a = "#{s.a}!" rescue nil; s.save!; s.reload; rep([s.a, Vault.where(src: SRC, b: vals[s.i]).exists?(s.id)]) })
    end
    emit.("vault/#{ENC}/count", Vault.where(src: SRC).count)
  end
  out.close
end
