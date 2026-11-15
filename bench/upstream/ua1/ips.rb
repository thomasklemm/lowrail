# UA1 benchmark-ips: UserAgent.parse over the 21 UA1 user agents, allow_browser's check (BrowserBlocker#blocked?,
# versions: :modern) over the same 21, and one controller request with allow_browser :modern and Chrome 142.
# Run by p_map/ab1_review.sh (five interleaved rounds of base, candidate, base again; one pinned core):
#   ab1_review.sh RUBY_BIN GEMFILE_DIR_MAIN GEMFILE_DIR_FIX "--yjit" THIS
require "action_controller"
require "benchmark/ips"
require "useragent"
require_relative "uas"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

app = PagesController.action(:show)
chrome = UA1::UAS.fetch("Chrome macOS")
raise "blocked" unless app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => chrome)).first == 200

Request = Struct.new(:user_agent)
requests = UA1::UAS.values.map { |ua| Request.new(ua) }
user_agents = UA1::UAS.values

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)
  x.report("parse x21") { user_agents.each { |ua| UserAgent.parse(ua) } }
  x.report("check x21") { requests.each { |r| ActionController::AllowBrowser::BrowserBlocker.new(r, versions: :modern).blocked? } }
  x.report("request") { app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => chrome)) }
end
