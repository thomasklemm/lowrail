# Profiles allow_browser's check (BrowserBlocker#blocked?, versions: :modern) over the UA1 user agents.
#   ruby [--yjit] -rbundler/setup profile.rb stackprof|vernier OUT [ROUNDS]
require "action_controller"
require "useragent"
require_relative "uas"

tool, out, rounds = ARGV[0], ARGV[1], Integer(ARGV[2] || 3_000)
Request = Struct.new(:user_agent)
Blocker = ActionController::AllowBrowser::BrowserBlocker
requests = UA1::UAS.values.map { |ua| Request.new(ua) }
run = -> { rounds.times { requests.each { |r| Blocker.new(r, versions: :modern).blocked? } } }
run.call

case tool
when "stackprof"
  require "stackprof"
  StackProf.run(mode: :cpu, interval: 50, raw: true, out: out, &run)
when "vernier"
  require "vernier"
  Vernier.profile(out: out, &run)
end
