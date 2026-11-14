# frozen_string_literal: false

# AB1 review: differential probe. Prints allow_browser's response for edge-case user agents and version sets,
# each requested twice (the branch's second request is a hit). Run on main and the branch and diff the output.
#   BUNDLE_GEMFILE=<main or branch Gemfile> ruby -rbundler/setup THIS
require "action_controller"

ua = ->(name) { "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) #{name} Safari/537.36" }
pad = ->(base, size) { base + " (" + "x" * (size - base.bytesize - 3) + ")" }
agents = {
  "nil" => nil, "empty" => "", "blank" => "   ", "garbage" => "%%%", "bare product" => "curl/8.5.0",
  "chrome 119" => ua.("Chrome/119.0.0.0"), "chrome 120" => ua.("Chrome/120.0.0.0"), "chrome no version" => ua.("Chrome"),
  "safari 17.1" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
  "ie 11" => "Mozilla/5.0 (Windows NT 10.0; Trident/7.0; rv:11.0) like Gecko",
  "googlebot old chrome" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html) Chrome/41.0.2272.96 Safari/537.36",
  "chrome 119, 512 bytes" => pad.(ua.("Chrome/119.0.0.0"), 512), "chrome 119, 513 bytes" => pad.(ua.("Chrome/119.0.0.0"), 513),
  "chrome 119, UTF-8" => ua.("Chrome/119.0.0.0 Ünïcødé"),
  "chrome 119, binary" => ua.("Chrome/119.0.0.0 \xFF\xFE").force_encoding(Encoding::BINARY),
  "chrome 119, invalid UTF-8" => ua.("Chrome/119.0.0.0 \xFF\xFE").force_encoding(Encoding::UTF_8),
}
sets = { modern: :modern, hash: { chrome: 120, safari: 17.2, ie: false }, string: "modern", unknown: :ancient }

events = 0
ActiveSupport::Notifications.subscribe("browser_block.action_controller") { events += 1 }

sets.each do |label, versions|
  controller = Class.new(ActionController::Base) do
    allow_browser versions: versions, block: -> { head :not_acceptable }
    def show = head(:ok)
    def self.name = "ProbeController"
  end
  app = controller.action(:show)
  agents.each do |name, agent|
    env = agent ? { "HTTP_USER_AGENT" => agent } : {}
    results = Array.new(2) do
      app.call(Rack::MockRequest.env_for("/", env)).first
    rescue => error
      "#{error.class}"
    end
    puts format("%-8s %-26s %s", label, name, results.join(" "))
  end
end
puts "browser_block events: #{events}"
