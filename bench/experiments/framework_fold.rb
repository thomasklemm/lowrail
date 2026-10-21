# frozen_string_literal: true

# Bet G's first screen is exactness, not timing. These deliberately optimistic
# specimens test the proposed request-entry-only certificate. They are NEVER
# installed into an application or shipped by Lowrail.
require "json"
require "digest"

module FrameworkFold
  module_function

  def notifications
    notifications = ActiveSupport::Notifications
    original = notifications.notifier
    name = "framework_fold.absent"
    result = %w[off_a off_b on].to_h do |arm|
      notifier = ActiveSupport::Notifications::Fanout.new
      notifications.notifier = notifier
      events = []
      # Reflection and the request-entry check both see zero listeners.
      plan = notifier.all_listeners_for(name).dup.freeze
      entry_matches = notifier.all_listeners_for(name) == plan
      body_evaluations = 0
      body = ->(_payload) { body_evaluations += 1; :body_result }
      payload = {value: 37}
      notifications.subscribed(->(event) { events << event.payload.fetch(:value) }, name) do
        if arm == "on" && entry_matches && plan.empty?
          value = body.call(payload) # compiled direct yield
        else
          value = notifications.instrument(name, payload, &body)
        end
        raise "body result changed" unless value == :body_result
      end
      raise "body evaluation count changed" unless body_evaluations == 1
      [arm, {entry_matches: entry_matches, observed_events: events,
        body_evaluations: body_evaluations, listeners_after_request: notifier.all_listeners_for(name).size}]
    end
    {arms: result, off_control_equal: result["off_a"] == result["off_b"],
      exact: result["off_a"] == result["on"], verdict: "kill_request_entry_absence_fold"}
  ensure
    notifications.notifier = original if original
  end

  def policy_middleware
    middleware = ActionDispatch::ContentSecurityPolicy::Middleware
    policy_key = "action_dispatch.content_security_policy"
    header = ActionDispatch::Constants::CONTENT_SECURITY_POLICY
    # A controller may install a per-request policy even with no boot policy.
    inner = ->(env) do
      ActionDispatch::Request.new(env).content_security_policy =
        ActionDispatch::ContentSecurityPolicy.new { |p| p.default_src :none }
      [200, {}, ["same body"]]
    end
    stock = middleware.new(inner)
    facts = [stock.method(:call), stock.instance_variable_get(:@app)]
    result = %w[off_a off_b on].to_h do |arm|
      env = {}
      entry_matches = facts == [stock.method(:call), stock.instance_variable_get(:@app)] && !env[policy_key]
      status, headers, body = (arm == "on" && entry_matches ? inner : stock).call(env)
      [arm, {entry_matches: entry_matches, status: status, body: body.join,
        policy_header: headers[header], middleware_facts_still_match: facts ==
          [stock.method(:call), stock.instance_variable_get(:@app)]}]
    end
    raise "stock policy witness failed" unless result["off_a"][:policy_header] == "default-src 'none'"
    {arms: result, off_control_equal: result["off_a"] == result["off_b"],
      exact: result["off_a"] == result["on"], verdict: "kill_boot_nil_policy_elision"}
  end

  def run
    {scope: "exactness-first negative screen, not an app-route performance result",
      ruby: RUBY_DESCRIPTION, rails: Rails.version, rack: Rack.release,
      environment: Rails.respond_to?(:env) ? Rails.env.to_s : nil, yjit: RubyVM::YJIT.enabled?,
      probe_sha256: Digest::SHA256.file(__FILE__).hexdigest,
      notifications: notifications, policy_middleware: policy_middleware}
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "--framework-only"
    require "rails"
    require "action_dispatch"
  else
    require File.expand_path("config/environment", Dir.pwd)
  end
  report = FrameworkFold.run
  raise "A/A control failed" unless %i[notifications policy_middleware].all? { report.fetch(_1).fetch(:off_control_equal) }
  raise "negative witness unexpectedly passed" if %i[notifications policy_middleware].any? { report.fetch(_1).fetch(:exact) }
  if ARGV[1]
    File.write(ARGV[1], JSON.pretty_generate(report))
  else
    puts JSON.pretty_generate(report)
  end
end
