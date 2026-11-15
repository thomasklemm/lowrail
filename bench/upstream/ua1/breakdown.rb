# Per user agent: µs per call of UserAgent.parse, of version/browser/bot? on a parsed object, and of
# allow_browser's whole check (BrowserBlocker#blocked? with versions: :modern), plus objects per check.
#   ruby --yjit -rbundler/setup breakdown.rb [N]
require "action_controller"
require "useragent"
require_relative "uas"

N = Integer(ARGV[0] || 20_000)
Request = Struct.new(:user_agent)
Blocker = ActionController::AllowBrowser::BrowserBlocker

def us(n)
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { yield }
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e6 / n
end

def objs
  GC.disable
  a = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - a
ensure
  GC.enable
end

puts RUBY_DESCRIPTION
printf "%-22s %-16s %8s %8s %8s %8s %8s %8s %6s\n", "ua", "browser", "verdict", "parse", "version", "browser", "bot?", "check", "objs"
UA1::UAS.each do |name, ua|
  req = Request.new(ua)
  3.times { 2_000.times { Blocker.new(req, versions: :modern).blocked? } }
  parsed = UserAgent.parse(ua)
  row = [
    us(N) { UserAgent.parse(ua) },
    us(N) { parsed.version },
    us(N) { parsed.browser },
    us(N) { parsed.bot? },
    us(N) { Blocker.new(req, versions: :modern).blocked? },
  ]
  o = objs { Blocker.new(req, versions: :modern).blocked? }
  printf "%-22s %-16s %8s %8.2f %8.2f %8.2f %8.2f %8.2f %6d\n", name, parsed.browser, Blocker.new(req, versions: :modern).blocked?, *row, o
end
