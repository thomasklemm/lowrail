# frozen_string_literal: true

# Vernier shares per default piece from harness.rb profile output:
#   ruby shares.rb PROFILE.json [PROFILE.json...]   (a second file is the A/A twin)
# Request time is the Puma worker's samples outside the keep-alive wait, plus
# GC.total_time. Every sample is charged to one piece, so the shares add up to 100.
require "json"

WAIT = /\A(IO#wait_readable|IO\.select|Kernel#sleep|Thread::ConditionVariable#wait|Thread::Mutex#sleep|IO#read_nonblock|Thread::Queue#pop)\z/
# Each sample goes to the innermost matching piece, root to leaf. A claiming
# piece keeps everything below it (helpers, allow_browser, logging, ...); a
# generic piece (a layer) only keeps what no inner piece claims.
WRAPPERS = %w[ActiveSupport::LoggerSilence#silence ActiveSupport::LoggerThreadSafeLevel#log_at
  ActiveSupport::TaggedLogging#tagged].freeze
CLAIMING = {
  "allow_browser" => /AllowBrowser|BrowserBlocker|\AUserAgent/,
  "csrf callbacks" => /#(verify_authenticity_token|verify_request_for_forgery_protection|verify_same_origin_request|append_sec_fetch_site_to_vary_header)\z/,
  "Turbo frame layout lambda and etag" => /Turbo::Frames::FrameRequest/,
  "csrf_meta_tags" => /#csrf_meta_tags\z/,
  "csp_meta_tag" => /#csp_meta_tag\z/,
  "javascript_importmap_tags" => /#javascript_importmap_tags\z/,
  "stylesheet_link_tag" => /#stylesheet_link_tag\z/,
  "logging (loggers, log subscribers, structured events)" => /LogSubscriber|ActiveSupport::Logger|\ALogger#|\ALogger::|TaggedLogging|BroadcastLogger|StructuredEventSubscriber|ActiveSupport::EventReporter|ParameterFilter/,
  "session and cookies" => /ActionDispatch::Session|ActionDispatch::Cookies|ActionDispatch::Request::Session|MessageEncryptor|MessageVerifier|Rack::Session/,
  "flash" => /ActionDispatch::Flash|#flash\z|#notice\z/
}.freeze
GENERIC = {
  "Puma (parse, write, keep-alive)" => /\APuma/,
  "Rack::BodyProxy#close (executor complete, logger finish)" => /Rack::BodyProxy#close/,
  "routing" => /ActionDispatch::Journey|ActionDispatch::Routing/,
  "controller (Metal, AbstractController)" => /\A(ActionController|AbstractController)::/,
  "callback chains" => /\AActiveSupport::Callbacks/,
  "notifications machinery" => /\AActiveSupport::Notifications/,
  "turbo_tracking_request_id (own)" => /Turbo::RequestIdTracking|\ATurbo\.with_request_id/,
  "Action Text renderer around_action (own)" => /ActionText::Content\.with_renderer|ActionText::Engine/,
  "params" => /ActionController::Parameters|ActionDispatch::Http::Parameters|ParamsWrapper|Rack::QueryParser|Rack::Multipart/,
  "Active Record" => /\AActiveRecord|\AArel|SQLite3/,
  "Action View" => /\AActionView/,
  "app templates" => /\A_app_views_/
}.freeze

MIDDLEWARE_LABEL = { "ActionDispatch::Routing::RouteSet#call" => "routing",
  "Rack::Session::Abstract::Persisted#call" => "mw ActionDispatch::Session::CookieStore",
  "Rack::Session::Abstract::Persisted#context" => "mw ActionDispatch::Session::CookieStore" }.freeze

profiles = ARGV.map { JSON.parse(File.read(_1)) }
report = profiles.map do |prof|
  stacks = prof["stacks"]
  chain = prof["middleware"].map { "#{_1}#call" } + ["ActionDispatch::Routing::RouteSet#call", "Rack::Session::Abstract::Persisted#call", "Rack::Session::Abstract::Persisted#context"]
  prof["windows"].each_with_index.to_h do |w, wi|
    counts = Hash.new(0)
    total = 0
    prof["samples"].each do |stack_idx, sw, weight|
      next unless sw == wi
      frames = stacks[stack_idx.to_s]
      next if WAIT.match?(frames.first.to_s)
      total += weight
      owner, claimed = "other", false
      frames.reverse_each do |label|
        if chain.include?(label)
          owner = MIDDLEWARE_LABEL.fetch(label) { "mw #{label.delete_suffix("#call")}" } unless claimed
        elsif WRAPPERS.include?(label)
          next
        elsif (piece = CLAIMING.find { _2.match?(label) }&.first)
          owner, claimed = piece, true
        elsif !claimed && (piece = GENERIC.find { _2.match?(label) }&.first)
          owner = piece
        end
      end
      counts[owner] += weight
    end
    gc = w["gc_ns"] / 1000.0 / prof["interval_us"]
    total += gc
    counts["GC"] = gc
    [w["name"], { total_ms: (total * prof["interval_us"] / 1000.0 / prof["requests"]).round(4),
      objects: w["objects"], shares: counts.transform_values { (100.0 * _1 / total).round(2) } }]
  end
end

names = report.first.keys
pieces = report.flat_map { |r| r.values.flat_map { _1[:shares].keys } }.uniq.sort
puts "| piece | #{names.join(" | ")} |"
puts "|---|#{"---:|" * names.size}"
puts "| ms per request | #{names.map { |n| report.map { _1[n][:total_ms] }.join(" / ") }.join(" | ")} |"
pieces.each do |piece|
  cells = names.map { |n| report.map { _1[n][:shares].fetch(piece, 0.0) }.join(" / ") }
  puts "| #{piece} | #{cells.join(" | ")} |"
end
