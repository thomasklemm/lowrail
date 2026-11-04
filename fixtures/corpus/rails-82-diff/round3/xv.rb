# Cross-version harness, round 3. One process per tree writes data, the other tree reads it.
#   XV_TREE=81|main BUNDLE_GEMFILE=.../Gemfile bundle exec ruby xv.rb setup BASE
#   ... xv.rb write BASE            # writes BASE/blobs/<tree>[-<cfg>]/...
#   ... xv.rb read BASE SRC OUT     # reads blobs written by SRC, one "key<TAB>canonical value" line per case
# App configuration comes from XV_COOKIE_SER, XV_SESSION, XV_DEFAULTS, XV_SKB_MODE (old|new), XV_CBC.
# Values are generated from a fixed seed after Rails loads, with core Ruby calls only, so both trees build the
# same values in the same order.
MODE, BASE, *REST = ARGV
TREE = ENV.fetch("XV_TREE")
SEED = Integer(ENV.fetch("SEED", "20261104"))
N = Integer(ENV.fetch("N", "600"))
CFG = [ENV["XV_COOKIE_SER"] || "json", ENV["XV_SESSION"] || "cookie", ENV["XV_DEFAULTS"] || "8.1",
  ENV["XV_SKB_MODE"] || "same", ENV["XV_CBC"] ? "cbc" : "gcm"].join("-")
SKB_OLD = "o" * 128
SKB_NEW = "n" * 128
SKB = ENV["XV_SKB_MODE"] == "old" ? SKB_OLD : (ENV["XV_SKB_MODE"] == "new" ? SKB_NEW : "s" * 128)
ENV["SECRET_KEY_BASE"] = SKB
ENV["RAILS_ENV"] = "production"
ENV["DATABASE_URL"] = "sqlite3:#{BASE}/db.sqlite3"
require "fileutils"
FileUtils.mkdir_p("#{BASE}/root/config")

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_job/railtie"

class XvApp < Rails::Application
  config.root = "#{BASE}/root"
  config.load_defaults ENV.fetch("XV_DEFAULTS", "8.1")
  config.eager_load = false
  config.secret_key_base = SKB
  config.logger = Logger.new(nil)
  config.active_support.report_deprecations = false
  config.hosts.clear
  # Readers get their own copy of the session cache, because a read request consumes the flash and writes the
  # session back; sharing one store would let the first reader change what the second one sees.
  session_dir = MODE == "read" ? "#{BASE}/sessioncache-#{TREE}-from-#{REST[0]}" : "#{BASE}/sessioncache"
  if MODE == "read" && File.directory?("#{BASE}/sessioncache")
    FileUtils.rm_rf(session_dir)
    FileUtils.cp_r("#{BASE}/sessioncache", session_dir)
  end
  config.cache_store = :file_store, session_dir
  if ENV["XV_SESSION"] == "cache"
    config.session_store :cache_store, key: "_xv_session", expire_after: 1.year
  else
    config.session_store :cookie_store, key: "_xv_session"
  end
  config.action_dispatch.cookies_serializer = (ENV["XV_COOKIE_SER"] || "json").to_sym
  config.action_dispatch.use_authenticated_cookie_encryption = false if ENV["XV_CBC"]
  if ENV["XV_SKB_MODE"] == "new"
    config.action_dispatch.cookies_rotations.tap do |r|
      kg = ActiveSupport::KeyGenerator.new(SKB_OLD, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA256)
      r.rotate :encrypted, kg.generate_key("authenticated encrypted cookie", 32)
      r.rotate :signed, kg.generate_key("signed cookie")
    end
  end
  config.active_record.encryption.primary_key = "p" * 32
  config.active_record.encryption.deterministic_key = "d" * 32
  config.active_record.encryption.key_derivation_salt = "k" * 32
  config.active_job.queue_adapter = :test
  config.action_controller.allow_forgery_protection = true
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
end
Rails.application.initialize!
Rails.application.message_verifiers.rotate(secret_key_base: SKB_OLD) if ENV["XV_SKB_MODE"] == "new"
require "active_support/message_pack"
require "active_record/message_pack" rescue nil

if MODE == "setup"
  c = ActiveRecord::Base.connection
  c.create_table(:posts, force: true) { |t| t.string :title; t.text :body; t.datetime :published_at; t.decimal :score, precision: 10, scale: 2; t.json :meta; t.integer :flags }
  c.create_table(:comments, force: true) { |t| t.integer :post_id; t.string :body }
  c.create_table(:secrets, force: true) { |t| t.string :src; t.integer :i; t.text :a; t.text :b; t.text :c; t.text :d; t.text :e; t.text :f; t.text :original_f; t.binary :g }
end

require "active_record/encryption/message_pack_message_serializer"
class Post < ActiveRecord::Base
  has_many :comments
end
class Comment < ActiveRecord::Base
  belongs_to :post
end
class Secret < ActiveRecord::Base
  encrypts :a
  encrypts :b, deterministic: true
  encrypts :c, deterministic: true, downcase: true
  encrypts :d, compress: false
  encrypts :f, deterministic: true, ignore_case: true
  encrypts :g, message_serializer: ActiveRecord::Encryption::MessagePackMessageSerializer.new
  serialize :e, coder: JSON
  encrypts :e
end
class XvJob < ActiveJob::Base
  def perform(*args, **kw) = nil
end

# ---- Canonical form -------------------------------------------------------------------------------------
def rep(v, d = 0)
  return "…" if d > 8
  s = case v
      when ActiveSupport::SafeBuffer then "SB(#{v.html_safe?})#{v.to_str.inspect}"
      when ActiveSupport::TimeWithZone then "TWZ #{v.utc.strftime("%F %T.%N")} [#{v.time_zone.name}] utc?#{v.utc?}"
      when DateTime then "DT #{v.strftime("%F %T.%N %:z")}"
      when Time then "T #{v.strftime("%F %T.%N %:z")} utc?#{v.utc?} zone=#{v.zone.inspect}"
      when Date then "Date #{v}"
      when ActiveSupport::Duration then "D #{v.value.inspect} #{v.parts.sort_by { |k, _| k.to_s }.inspect}"
      when BigDecimal then "BD #{v.to_s} prec=#{v.precision}"
      when Float then "F #{v.inspect}"
      when String then (v.encoding == Encoding::UTF_8 ? v.inspect : "#{v.encoding}:#{v.b.inspect}")
      when Array then "[" + v.map { rep(_1, d + 1) }.join(", ") + "]"
      when ActiveSupport::HashWithIndifferentAccess then "HWIA{" + v.map { |k, x| "#{rep(k, d + 1)}=>#{rep(x, d + 1)}" }.join(", ") + "}"
      when Hash then "{" + v.map { |k, x| "#{rep(k, d + 1)}=>#{rep(x, d + 1)}" }.join(", ") + "}"
      when Range then "R(#{rep(v.begin, d + 1)}#{v.exclude_end? ? "..." : ".."}#{rep(v.end, d + 1)})"
      when Set then "Set" + rep(v.to_a, d + 1)
      when ActiveRecord::Base
        "AR #{v.class.name} id=#{v.id.inspect} new=#{v.new_record?} destroyed=#{v.destroyed?} changed=#{v.changed.sort.inspect} " \
          "attrs=#{rep(v.attributes, d + 1)} assoc=#{v.class.reflect_on_all_associations.select { |a| v.association(a.name).loaded? }.map { |a| [a.name, rep(v.association(a.name).target, d + 1)] }.inspect}"
      when ActiveSupport::TimeZone then "Zone #{v.name}"
      when Exception then "Exc #{v.class}: #{v.message}"
      else "#{v.class}:#{v.inspect}"
      end
  s = s.gsub(/0x\h{6,}/, "0x")
  s.size > 4000 ? s[0, 4000] + "…" : s
end
def guard
  yield
rescue Exception => e
  raise if e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
  "!#{e.class}: #{e.message.to_s.gsub("\n", "\\n").gsub(/0x\h{6,}/, "0x")[0, 300]}"
end

# ---- Values ---------------------------------------------------------------------------------------------
R = Random.new(SEED)
def pick(a) = a[R.rand(a.size)]
ALPHA = (("a".."z").to_a + ("A".."Z").to_a + ["0", "9", " ", "_", "-", "/", ".", "'", "\"", "&", "<", ">", "%", "=", "é", "ß", "日", "😀", "\n", "\u2028"]).freeze
def rstr(max = 12) = Array.new(R.rand(max + 1)) { pick(ALPHA) }.join
ZONES = ["UTC", "Europe/Berlin", "America/New_York", "Asia/Kolkata", "Pacific/Chatham", "America/St_Johns", "Australia/Lord_Howe", "Etc/GMT+12"].freeze
def rtime
  sec = pick([0, 1, -1, 1_700_000_000, 2_147_483_648, 4_102_444_800, -2_208_988_800, R.rand(-3_000_000_000..4_000_000_000)])
  nsec = pick([0, 1, 999_999_999, 500_000_000, 123_456_789, R.rand(1_000_000_000)])
  Time.at(sec, nsec, :nsec)
end
def rscalar
  case R.rand(26)
  when 0 then nil
  when 1 then pick([true, false])
  when 2 then pick([0, 1, -1, 2**31, 2**63, 2**64 + 1, -(2**70), R.rand(-10**6..10**6)])
  when 3 then pick([0.0, -0.0, 1.5, 1e-7, 1e300, Float::INFINITY, -Float::INFINITY, Float::NAN, R.rand])
  when 4 then BigDecimal(pick(["0", "1.10", "-0.0001", "1e40", "123456789012345678901234567890.123456789", "NaN", "Infinity", "-0", R.rand(-1000.0..1000.0).round(3).to_s]))
  when 5 then Rational(R.rand(-50..50), pick([1, 3, 7]))
  when 6, 7 then rstr
  when 8 then pick(["", " ", "\xff\xfe".b, "abc".encode("UTF-16LE"), "é".encode("ISO-8859-1"), "x" * 300, "plain".b])
  when 9 then pick([:a, :"with space", :"日本", :_aj_globalid, :Zz])
  when 10 then (s = rstr.html_safe; R.rand(2).zero? ? s : (b = "a<b".html_safe; b.gsub!("a", "x"); b))
  when 11 then rtime
  when 12 then rtime.getlocal(pick(["+05:30", "-08:00", "+00:00", "+14:00"]))
  when 13 then rtime.utc
  when 14, 15 then rtime.in_time_zone(pick(ZONES))
  when 16 then rtime.to_datetime
  when 17 then Date.jd(R.rand(1_000_000..3_000_000))
  when 18 then [1.second, 1.5.seconds, 2.minutes, 3.hours, 1.day, 2.weeks, 1.month, 1.year, (1.month + 2.5.seconds), ActiveSupport::Duration.build(R.rand(0..100_000_000)), -(3.days), 0.seconds, (1.year + 2.months + 3.days)].then { pick(_1) }
  when 19 then pick([1..5, 1...5, (1..), (..3), "a".."c", Date.new(2026, 1, 1)..Date.new(2026, 2, 1), rtime..rtime, 1.5..2.5])
  when 20 then ActiveSupport::TimeZone[pick(ZONES)]
  when 21 then pick([Set[1, "a"], IPAddr.new("10.0.0.0/8"), URI("https://x.org/a?b=c"), Pathname("/tmp/x"), /a+b/i, Complex(1, 2), Post, String])
  when 22, 23 then rrecord
  else rstr(4).to_sym
  end
end
def rrecord
  case R.rand(6)
  when 0 then Post.find(R.rand(1..20))
  when 1 then Post.includes(:comments).find(R.rand(1..20))
  when 2 then Post.new(title: rstr, score: BigDecimal("1.25"), published_at: rtime)
  when 3 then (p = Post.find(R.rand(1..20)); p.title = rstr; p)
  when 4 then Comment.find(R.rand(1..40))
  else Post.select(:id, :title).find(R.rand(1..20))
  end
end
def rvalue(depth = 0)
  case depth > 2 ? 0 : R.rand(6)
  when 0, 1, 2 then rscalar
  when 3 then Array.new(R.rand(4)) { rvalue(depth + 1) }
  when 4 then Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(3).to_sym, R.rand(10)]), rvalue(depth + 1)] }
  else ActiveSupport::HashWithIndifferentAccess.new(Array.new(R.rand(4)).to_h { [rstr(5), rvalue(depth + 1)] })
  end
end
# JSON-shaped values for cookies, sessions and JSON serializers (the real data in those places is JSON-safe).
def rjsonish(depth = 0)
  case depth > 2 ? R.rand(4) : R.rand(7)
  when 0 then pick([nil, true, false, 0, -1, 2**53 + 1, 1.5, "", rstr])
  when 1 then rstr
  when 2 then pick([rtime.in_time_zone(pick(ZONES)), Date.jd(R.rand(2_400_000..2_500_000)), BigDecimal("1.10"), :sym, 1.day])
  when 3 then rstr(3).to_sym
  when 4 then Array.new(R.rand(4)) { rjsonish(depth + 1) }
  when 5 then Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(3).to_sym]), rjsonish(depth + 1)] }
  else ActiveSupport::HashWithIndifferentAccess.new(Array.new(R.rand(3)).to_h { [rstr(5), rjsonish(depth + 1)] })
  end
end

def blobdir(src) = "#{BASE}/blobs/#{src}"
def blob_write(src, name, data)
  path = "#{blobdir(src)}/#{name}"
  FileUtils.mkdir_p(File.dirname(path))
  File.binwrite(path, Marshal.dump(data))
end
def blob_read(src, name) = Marshal.load(File.binread("#{blobdir(src)}/#{name}"))

# ---- Cases ----------------------------------------------------------------------------------------------
CACHE_CFGS = {
  "default" => {}, "m70" => { serializer: :marshal_7_0 }, "m71" => { serializer: :marshal_7_1 },
  "mp" => { serializer: :message_pack }, "m71z" => { serializer: :marshal_7_1, compress_threshold: 1 },
  "mpz" => { serializer: :message_pack, compress_threshold: 1 }, "nocomp" => { compress: false },
  "legacy70" => :legacy70, "marshal_coder" => { coder: Marshal },
}.freeze
MSG_SERS = %i[marshal json json_allow_marshal message_pack message_pack_allow_marshal].freeze
MSG_KINDS = %w[ver ver_url enc_gcm enc_cbc enc_url].freeze
def msg_obj(kind, ser, secret)
  key = ActiveSupport::KeyGenerator.new(secret, iterations: 1000).generate_key("salt", 32)
  case kind
  when "ver" then ActiveSupport::MessageVerifier.new(key, serializer: ser)
  when "ver_url" then ActiveSupport::MessageVerifier.new(key, serializer: ser, url_safe: true, digest: "SHA256")
  when "enc_gcm" then ActiveSupport::MessageEncryptor.new(key, serializer: ser)
  when "enc_cbc" then ActiveSupport::MessageEncryptor.new(key, key, cipher: "aes-256-cbc", serializer: ser)
  when "enc_url" then ActiveSupport::MessageEncryptor.new(key, serializer: ser, url_safe: true)
  end
end
def msg_opts(i) = [{}, { purpose: "p#{i % 3}" }, { expires_in: 1.year }, { expires_at: Time.utc(2100, 1, 1), purpose: :x }][i % 4]
def with_cache_store(cfg, src)
  dir = "#{BASE}/cache/#{src}/#{cfg}"
  if CACHE_CFGS[cfg] == :legacy70
    old = ActiveSupport::Cache.format_version
    ActiveSupport::Cache.format_version = 7.0
    begin
      yield ActiveSupport::Cache::FileStore.new(dir)
    ensure
      ActiveSupport::Cache.format_version = old
    end
  else
    yield ActiveSupport::Cache::FileStore.new(dir, **CACHE_CFGS[cfg])
  end
end
def secret_values = ["", "plain", "Mixed Case", "é日本😀", "\xff\x00".b, "x" * 500, ("ab" * 90), nil] + Array.new(N / 3) { rstr(R.rand(2) == 0 ? 30 : 400) }
# Values Active Job can serialize, so most cases get past the writer.
def rjob(depth = 0)
  case depth > 2 ? R.rand(3) : R.rand(6)
  when 0
    case R.rand(14)
    when 0 then pick([nil, true, false, 0, -1, 2**64, 1.5, -0.0, 1e-7])
    when 1 then BigDecimal(pick(["0", "1.10", "-0.0001", "1e40", "123456789012345678901234567890.123456789"]))
    when 2, 3 then rstr
    when 4 then pick([:a, :"with space", :Zz, :_aj_x])
    when 5 then rtime
    when 6 then rtime.getlocal(pick(["+05:30", "-08:00", "+00:00"]))
    when 7, 8 then rtime.in_time_zone(pick(ZONES))
    when 9 then rtime.to_datetime
    when 10 then Date.jd(R.rand(1_000_000..3_000_000))
    when 11 then pick([1.second, 1.5.seconds, 1.month, (1.month + 2.5.seconds), ActiveSupport::Duration.build(R.rand(0..100_000_000)), -(3.days), (1.year + 2.months + 3.days)])
    when 12 then pick([1..5, 1...5, (1..), (..3), "a".."c", Date.new(2026, 1, 1)..Date.new(2026, 2, 1), rtime.in_time_zone("Europe/Berlin")..rtime.utc, 1.5..2.5, Post, String, ActiveSupport::TimeZone["Europe/Berlin"]])
    else [Post, Comment][R.rand(2)].find(R.rand(1..20))
    end
  when 1 then rstr
  when 2 then Array.new(R.rand(4)) { rjob(depth + 1) }
  when 3 then Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(3).to_sym]), rjob(depth + 1)] }
  when 4 then ActiveSupport::HashWithIndifferentAccess.new(Array.new(R.rand(4)).to_h { [rstr(5), rjob(depth + 1)] })
  else rjob(depth + 1)
  end
end
def job_args = Array.new(N) { [Array.new(R.rand(4)) { rjob }, Array.new(R.rand(3)).to_h { [rstr(4).to_sym, rjob] }] }

# Every case draws from R in the same order on both sides, so all values are generated first.
VALUES = Array.new(N) { rvalue } if MODE != "setup"
JVALUES = Array.new(N) { rjsonish } if MODE != "setup"
SECRETS = secret_values if MODE != "setup"
JOBS = job_args if MODE != "setup"
COOKIES = Array.new(N / 3) { Array.new(1 + R.rand(4)) { |k| [pick(%w[plain signed encrypted permanent_signed permanent_encrypted]), "c#{k}", rjsonish, pick([nil, 1.hour, 1.year])] } } if MODE != "setup"
SESSIONS = Array.new(N / 3) { [Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(3).to_sym]), rjsonish] }, pick([nil, rstr, ["a", "b"]])] } if MODE != "setup"

class XvController < ActionController::Base
  protect_from_forgery with: :exception
  def write
    i = params[:i].to_i
    COOKIES[i].each do |jar, name, value, exp|
      v = exp ? { value: value, expires: exp } : { value: value }
      case jar
      when "plain" then cookies[name] = value.to_s
      when "signed" then cookies.signed[name] = v
      when "encrypted" then cookies.encrypted[name] = v
      when "permanent_signed" then cookies.permanent.signed[name] = { value: value }
      when "permanent_encrypted" then cookies.permanent.encrypted[name] = { value: value }
      end
    end
    h, flash_v = SESSIONS[i]
    h.each { |k, v| session[k] = v }
    flash[:notice] = flash_v if flash_v
    render plain: form_authenticity_token
  end
  def read
    i = params[:i].to_i
    got = COOKIES[i].map do |jar, name, _value, _exp|
      [name, guard { rep(case jar
        when "plain" then cookies[name]
        when "signed", "permanent_signed" then cookies.signed[name]
        else cookies.encrypted[name]
        end) }]
    end
    sess = session.to_hash.except("session_id", "_csrf_token")
    csrf = guard { valid_authenticity_token?(session, request.headers["X-Xv-Token"]) }
    render plain: [rep(got), rep(sess.sort_by { |k, _| k.to_s }.to_h), rep(flash.to_hash), "csrf=#{csrf}"].join(" | ")
  end
end
Rails.application.routes.draw do
  get "/xv/write/:i" => "xv#write"
  get "/xv/read/:i" => "xv#read"
end

def app_call(path, cookie = nil, token = nil)
  env = Rack::MockRequest.env_for("https://example.org#{path}", "HTTP_COOKIE" => cookie.to_s, "HTTP_X_XV_TOKEN" => token.to_s)
  status, headers, body = Rails.application.call(env)
  text = +""
  body.each { text << _1 }
  body.close if body.respond_to?(:close)
  set = Array(headers["set-cookie"] || headers["Set-Cookie"]).flat_map { _1.split("\n") }
  [status, set, text]
end
def cookie_header(set) = set.map { _1.split(";").first }.join("; ")

case MODE
when "setup"
  1.upto(20) { |i| Post.create!(id: i, title: "t#{i} <é>", body: "b" * i, published_at: Time.utc(2026, 1, i, 1, 2, 3, 456_789), score: BigDecimal("#{i}.25"), meta: { "k" => i, "a" => [1, nil] }, flags: i * 3) }
  1.upto(40) { |i| Comment.create!(id: i, post_id: (i % 20) + 1, body: "c#{i}") }
when "write"
  src = "#{TREE}-#{CFG}"
  if CFG.end_with?("json-cookie-8.1-same-gcm") || CFG.end_with?("json-cookie-8.2-same-gcm")
    # Cache stores
    CACHE_CFGS.each_key do |cfg|
      with_cache_store(cfg, src) do |store|
        results = VALUES.each_with_index.map do |v, i|
          guard { store.write("k#{i}", v, **[{}, { expires_in: 1.year }, { version: "v#{i % 3}" }][i % 3]) }
        end
        blob_write(src, "cache-#{cfg}-writes", results)
      end
    end
    # Messages
    MSG_KINDS.product(MSG_SERS).each do |kind, ser|
      %w[cur old].each do |which|
        o = msg_obj(kind, ser, which == "cur" ? "cur" : "old")
        msgs = VALUES.each_with_index.map do |v, i|
          guard { kind.start_with?("ver") ? o.generate(v, **msg_opts(i)) : o.encrypt_and_sign(v, **msg_opts(i)) }
        end
        blob_write(src, "msg-#{kind}-#{ser}-#{which}", msgs)
      end
    end
    blob_write(src, "msg-app", JVALUES.each_with_index.map { |v, i| guard { Rails.application.message_verifier("xv").generate(v, **msg_opts(i)) } })
    blob_write(src, "msg-apps", JVALUES.each_with_index.map { |v, i| guard { Rails.application.message_verifiers["xv2"].generate(v, **msg_opts(i)) } })
    blob_write(src, "signed_id", Array.new(60) { |i| guard { Post.find(i % 20 + 1).signed_id(**[{}, { purpose: :login }, { expires_in: 1.year }][i % 3]) } })
    blob_write(src, "sgid", Array.new(60) { |i| guard { Post.find(i % 20 + 1).to_sgid(**[{}, { for: "x" }, { expires_in: 1.year }][i % 3]).to_s } })
    blob_write(src, "gid", Array.new(60) { |i| guard { [Post, Comment][i % 2].find(i % 20 + 1).to_gid.to_s } })
    # Active Job
    blob_write(src, "jobs", JOBS.map { |args, kw| guard { h = XvJob.new(*args, **kw).serialize; JSON.dump(h) } })
    blob_write(src, "jobs-at", JOBS.first(50).map { |args, kw| guard { j = XvJob.new(*args); j.scheduled_at = Time.utc(2100, 1, 1, 0, 0, 0, 123_456); j.priority = 3; j.queue_name = "q"; JSON.dump(j.serialize) } })
    # Active Record encryption
    Secret.where(src: src).delete_all
    SECRETS.each_with_index do |s, i|
      r = guard { Secret.create!(src: src, i: i, a: s, b: s, c: s, d: s, e: (s.nil? ? nil : { "s" => s.to_s.scrub, "i" => i }), f: s, g: s) }
      warn "secret #{i}: #{r}" if r.is_a?(String)
    end
    blob_write(src, "aenc", SECRETS.map { |s| guard { ActiveRecord::Encryption.encryptor.encrypt(s) } })
    blob_write(src, "secret_values", SECRETS)
  end
  # Cookies and session, through the app
  out = COOKIES.each_index.map do |i|
    guard { app_call("/xv/write/#{i}") }
  end
  blob_write(src, "cookies-#{CFG}", out)
when "read"
  srcname, outfile = REST
  out = File.open(outfile, "w")
  emit = ->(k, v) { out.puts "#{k}\t#{v.to_s.gsub("\n", "\\n").gsub("\t", "\\t")}" }
  writer_cfg = srcname.split("-", 2).last
  if File.exist?("#{blobdir(srcname)}/jobs")
    CACHE_CFGS.each_key do |cfg|
      emit.("cache/#{cfg}/writes", rep(blob_read(srcname, "cache-#{cfg}-writes").uniq))
      with_cache_store(cfg, srcname) do |store|
        VALUES.each_index do |i|
          emit.("cache/#{cfg}/#{i}", guard { rep(store.read("k#{i}", **[{}, {}, { version: "v#{i % 3}" }][i % 3])) })
        end
        emit.("cache/#{cfg}/multi", guard { rep(store.read_multi(*Array.new(20) { "k#{_1 * 3}" })) })
      end
    end
    MSG_KINDS.product(MSG_SERS).each do |kind, ser|
      cur = msg_obj(kind, ser, "cur")
      rot = msg_obj(kind, ser, "new")
      key = ActiveSupport::KeyGenerator.new("old", iterations: 1000).generate_key("salt", 32)
      kind.start_with?("enc_cbc") ? rot.rotate(key, key, cipher: "aes-256-cbc") : rot.rotate(key)
      other = MSG_SERS.reject { _1 == ser }
      %w[cur old].each do |which|
        msgs = blob_read(srcname, "msg-#{kind}-#{ser}-#{which}")
        o = which == "cur" ? cur : rot
        msgs.each_with_index do |m, i|
          r = guard do
            v = kind.start_with?("ver") ? o.verified(m, **msg_opts(i).slice(:purpose)) : o.decrypt_and_verify(m, **msg_opts(i).slice(:purpose))
            rep(v)
          end
          r2 = which == "cur" && i % 4 == 1 ? guard { rep(kind.start_with?("ver") ? cur.verified(m) : cur.decrypt_and_verify(m)) } : ""
          emit.("msg/#{kind}/#{ser}/#{which}/#{i}", "#{r} #{r2}")
        end
      end
    end
    blob_read(srcname, "msg-app").each_with_index { |m, i| emit.("msg/app/#{i}", guard { rep(Rails.application.message_verifier("xv").verified(m, **msg_opts(i).slice(:purpose))) }) }
    blob_read(srcname, "msg-apps").each_with_index { |m, i| emit.("msg/apps/#{i}", guard { rep(Rails.application.message_verifiers["xv2"].verified(m, **msg_opts(i).slice(:purpose))) }) }
    blob_read(srcname, "signed_id").each_with_index { |m, i| emit.("signed_id/#{i}", guard { rep(Post.find_signed(m, **[{}, { purpose: :login }, {}][i % 3])) }) }
    blob_read(srcname, "sgid").each_with_index { |m, i| emit.("sgid/#{i}", guard { rep(GlobalID::Locator.locate_signed(m, **[{}, { for: "x" }, {}][i % 3])) }) }
    blob_read(srcname, "gid").each_with_index { |m, i| emit.("gid/#{i}", guard { rep(GlobalID::Locator.locate(m)) }) }
    %w[jobs jobs-at].each do |name|
      blob_read(srcname, name).each_with_index do |s, i|
        emit.("#{name}/#{i}", guard do
          j = ActiveJob::Base.deserialize(JSON.parse(s))
          j.send(:deserialize_arguments_if_needed)
          rep([j.class.name, j.arguments, j.queue_name, j.priority, j.executions, j.locale, j.timezone, j.scheduled_at, j.exception_executions])
        end)
        emit.("#{name}-wire/#{i}", guard { s.is_a?(String) && s.start_with?("{") ? JSON.parse(s).except("job_id", "enqueued_at", "provider_job_id").to_json : s })
      end
    end
    vals = blob_read(srcname, "secret_values")
    Secret.where(src: srcname).order(:i).each do |s|
      emit.("aenc/row/#{s.i}", guard { rep(%w[a b c d e f g].map { |c| s.public_send(c) }) })
      emit.("aenc/lookup/#{s.i}", guard { v = vals[s.i]; rep([Secret.where(src: srcname, b: v).pluck(:i).include?(s.i), Secret.where(src: srcname, c: v).pluck(:i).include?(s.i), Secret.where(src: srcname, f: v).pluck(:i).include?(s.i)]) })
    end
    blob_read(srcname, "aenc").each_with_index { |m, i| emit.("aenc/raw/#{i}", guard { rep(ActiveRecord::Encryption.encryptor.decrypt(m)) }) }
  end
  cfile = Dir["#{blobdir(srcname)}/cookies-*"].first
  blob_read(srcname, File.basename(cfile)).each_with_index do |w, i|
    next emit.("cookie/#{i}", "W#{w}") if w.is_a?(String)
    st, set, token = w
    emit.("cookie/#{i}", guard do
      rst, rset, text = app_call("/xv/read/#{i}", cookie_header(set), token)
      "#{st}/#{rst} rewrites=#{rset.map { _1.split("=").first }.sort.inspect} #{text}"
    end)
  end
  out.close
end
