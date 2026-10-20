# frozen_string_literal: true

# Off-only interpreter worker. No app methods are replaced or specialized.
if ENV.fetch("HOTSPOT_TRACE", "0") != "1"
  load File.expand_path("../heap_requests.rb", __dir__)
  exit
end
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
require "digest"
require_relative "../heap_windows"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
require ENV.fetch("HOTSPOT_EXTENSION")

module HotspotGroups
  AXES = %w[subsystem component prefix].freeze

  def self.labels(path, app:, repo:)
    gem_match = path.match(%r{/gems/([^/]+-[^/]+)/(.+)})
    if path.start_with?(app + "/")
      relative = path.delete_prefix(app + "/")
      prefix = "APP/" + relative.split("/").take(2).join("/")
      component = "App"
    elsif gem_match
      name, relative = gem_match.captures
      prefix = "GEM/#{name}/" + relative.split("/").take(2).join("/")
      component = case relative
      when %r{(?:\A|/)(action_controller|abstract_controller)/} then "ActionController"
      when %r{(?:\A|/)action_dispatch/} then "ActionDispatch"
      when %r{(?:\A|/)action_view/} then "ActionView"
      when %r{(?:\A|/)(active_record|arel)/} then "ActiveRecord"
      when %r{(?:\A|/)active_model/} then "ActiveModel"
      when %r{(?:\A|/)active_support/} then "ActiveSupport"
      else name.sub(/-\d.*\z/, "")
      end
    elsif path.start_with?(repo + "/bench/")
      prefix = component = "Benchmark client/seam"
    else
      relative = path.sub(%r{.*?/lib/ruby/\d+\.\d+\.\d+/}, "")
      prefix = "RUBY/" + relative.split("/").take(2).join("/")
      component = "Ruby stdlib/internal"
    end
    subsystem = case path
    when %r{/bench/|/rack/mock_(request|response)} then "Benchmark client/seam"
    when %r{inline_script_hash|importmap|vite_|rails_vite} then "Assets/importmap/CSP"
    when %r{request_forgery_protection|inertia_csrf} then "CSRF"
    when %r{/app/views/} then "App templates"
    when %r{/app/helpers/} then "App helpers"
    when %r{/app/models/} then "App models"
    when %r{/app/controllers/} then "App controllers"
    when %r{inertia_rails} then "Inertia props/config/render"
    when %r{net/http|/net/protocol|/socket} then "SSR HTTP client"
    when %r{jbuilder|/alba[/-]|/json/|active_support/json} then "JSON/serialization"
    when %r{frozen_record} then "FrozenRecord"
    when %r{store_model} then "StoreModel"
    when %r{cancan} then "Authorization"
    when %r{middleware/(cookies|session)|/rack/session|message_(encryptor|verifier)|messages/|key_generator|/base64[./]|/openssl} then "Session/cookies/crypto"
    when %r{active_(record|model)/(attribute|type)|/active_model/lazy_attribute} then "AR attributes/casts"
    when %r{active_record/connection_adapters|/sqlite3/|/pg/} then "AR SQL/adapter"
    when %r{active_record/associations} then "AR associations/preload"
    when %r{active_record/(inheritance|core|model_schema|persistence)} then "AR instantiation/model"
    when %r{active_record/|/arel/} then "AR query/relation"
    when %r{active_support/(notifications|subscriber|event_reporter)|event_subscriber|log_subscriber|/logger[./]|/rack/logger} then "Events/logging"
    when %r{active_support/callbacks} then "Callback machinery"
    when %r{action_view/helpers/(tags/|form_|tag_helper)} then "View helpers/tags/forms"
    when %r{action_view/buffers|output_safety|core_ext/erb/util} then "Buffers/escaping"
    when %r{action_view/} then "Rendering/lookup/helpers"
    when %r{action_dispatch/(journey|routing)|action_controller/metal/url_for|/url_for\.rb} then "Routing/URL generation"
    when %r{action_controller/|abstract_controller/} then "Controller dispatch/response"
    when %r{action_dispatch/middleware/static} then "Static-file miss"
    when %r{action_dispatch/|/rack-|/rack/|rack-session} then "Rack/middleware/request"
    when %r{active_support/|/i18n[/-]|/tzinfo[/-]} then "AS utilities/I18n/time"
    else "Other gems/stdlib/app"
    end
    [subsystem, component, prefix]
  end
end

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil
raise "off/interpreter required" if defined?(Lowrail) || RubyVM::YJIT.enabled?
path = ARGV.fetch(0).delete_prefix("GET:")
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
client = Rack::MockRequest.new(Rails.application)
def requests(n, client, path, headers)
  n.times do
    response = client.get(path, headers)
    raise "request status #{response.status}" unless response.status == 200
  end
end
if ENV["HOTSPOT_SSR"] == "1"
  require "nokogiri"
  response = client.get(path, headers)
  raise "SSR unavailable" unless Nokogiri::HTML(response.body).at_css("#app")&.element_children&.any?
end
n = Integer(ENV.fetch("BENCH_REQUESTS", "50"))
requests(50, client, path, headers)
groups = []
ids = lambda do |labels|
  labels.each_with_index.map do |label, axis|
    key = [HotspotGroups::AXES.fetch(axis), label]
    groups.index(key) || groups.push(key).size - 1
  end
end
root = ids.call(Array.new(3, "Benchmark client/seam"))
gc = ids.call(Array.new(3, "GC"))
windows = HeapWindows.windows(n)
index = 0
seed = Integer(ENV.fetch("HOTSPOT_SEED", (41231 + Process.pid * 1_000_003).to_s))
anchors = HeapWindows.run(windows, settle: -> { requests(1, client, path, headers) }) do |count|
  HotspotProbe.measure(index, seed + index * 1_000_003) { requests(count, client, path, headers) }
  index += 1
end
raw = HotspotProbe.results
attribution = raw.fetch("windows").map { _1.merge("self" => Hash.new(0), "inclusive" => Hash.new(0)) }
raw.fetch("stacks").each do |paths, counts|
  labels = paths.map { HotspotGroups.labels(_1, app: Dir.pwd, repo: File.expand_path("../..", __dir__)) }
  stack = labels.map { ids.call(_1) }
  current = stack.first || root
  present = stack.flatten.uniq
  counts.each_with_index do |count, w|
    current.each { attribution[w]["self"][_1] += count }
    present.each { attribution[w]["inclusive"][_1] += count }
  end
end
attribution.each do |row|
  gc.each { |id| row["self"][id] += row.fetch("gc"); row["inclusive"][id] += row.fetch("gc") }
  %w[self inclusive].each { |kind| row[kind] = groups.each_index.map { row[kind][_1] } }
end
puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
  windows: windows, heap_anchors: anchors, ar_installed: 0, request_settle: true,
  sampling_seed: seed,
  groups: groups, attribution: attribution, rails: Rails.version,
  lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest,
  gems: Gem.loaded_specs.transform_values { _1.version.to_s }, trace: true)}"
