# frozen_string_literal: true

# Untimed exactness worker. Correctness uses the existing pinned companions;
# native measurements use bet A's shared script/native-bench unchanged.
require "json"
require "digest"
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require_relative "../../fixtures/corpus/blog_production"
require_relative "fused_views"

raise "native YJIT required" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" && RubyVM::YJIT.enabled?
arm, route = ARGV
raise "unknown arm" unless %w[off_a off_b fused sealed stacked].include?(arm)
raise "retained blog required" unless BlogProduction::Entropy.source_pin(Dir.pwd) ==
  "86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf"
session = Rack::MockRequest.new(Rails.application)
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "fused-views-exploration"}
request = -> do
  response = session.get(route, headers)
  raise "#{route}: #{response.status}" unless response.status == 200
  response
end
# Natural stock witnesses first. The stacked arm does not fake the moved form
# block's source location to evade FormScaffold's real admission certificate.
2.times do
  %w[/articles/1 /articles].each do |path|
    response = session.get(path, headers)
    raise "witness #{path}: #{response.status}" unless response.status == 200
  end
end
if %w[fused stacked].include?(arm)
  FusedViews.observe
  FusedViews.install(ArticlesController, "show", partials: ["comments/comment"])
  FusedViews.install(ArticlesController, "index", partials: ["articles/article"])
  raise "compilation refused: #{FusedViews::LEDGER}" unless FusedViews::PLANS.size == 2
  FusedViews.enabled = true
end
Integer(ENV.fetch("FUSED_WARMUP", "2")).times { request.call }
reply = ->(data) { puts "FUSED #{JSON.generate(data)}"; $stdout.flush }
stats = -> do
  {fusion: FusedViews::COUNTS.dup,
    hits: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {},
    fallbacks: defined?(Lowrail::Stats) ? Lowrail::Stats.unit_fallbacks : {},
    form: defined?(Lowrail::FormScaffold) ? {admission: Lowrail::FormScaffold.admission,
      refusal: Lowrail::FormScaffold.refusal, input_refusal: Lowrail::FormScaffold.input_refusal} : nil}
end
reply.call(ready: true, arm: arm, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  ledger: FusedViews::LEDGER, coverage: stats.call)
STDIN.each_line do |line|
  command = JSON.parse(line)
  case command.fetch("op")
  when "gate"
    if defined?(Lowrail)
      require "lowrail/stats"
      Lowrail::Stats.enable!
      Lowrail::Stats.reset_counts!
    end
    validation = BlogProduction::Entropy.validate(Dir.pwd)
    raise "entropy policy refused: #{validation}" unless validation.fetch("active")
    BlogProduction::Entropy.install(validation.fetch("policy"))
    events = BlogProduction::AppEvents.new
    sql = []
    sql_subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      sql << {sql: payload[:sql], binds: BlogProduction.value(payload[:type_casted_binds]), cached: !!payload[:cached]}
    end
    subscription = ActiveSupport::Notifications.subscribe(/\.(?:action_view|action_controller)\z/, events)
    before = BlogProduction.effects
    responses = [0, 1].flat_map do |seed|
      %w[/articles/1 /articles].map do |path|
        events.events.clear
        sql.clear
        events.thread = Thread.current
        response, entropy = BlogProduction::Entropy.with(seed, "fused/#{path}") do
          session.get(path, headers)
        end
        raise "entropy failure: #{entropy}" unless entropy.fetch("errors").empty?
        {seed: seed, path: path, status: response.status, headers: response.headers.to_h,
          body_sha256: Digest::SHA256.hexdigest(response.body.b), bytes: response.body.bytesize,
          events: Marshal.load(Marshal.dump(events.events)), sql: Marshal.load(Marshal.dump(sql))}
      end
    end
    events.thread = nil
    ActiveSupport::Notifications.unsubscribe(subscription)
    ActiveSupport::Notifications.unsubscribe(sql_subscription)
    after = BlogProduction.effects
    reply.call(responses: responses, db_unchanged: before == after, db: after, coverage: stats.call)
  when "coverage"
    reply.call(stats.call)
  else
    raise "unknown operation"
  end
end
