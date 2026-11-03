# usage: RAILS=path ruby [--yjit] p1.rb
rails = ENV.fetch("RAILS")
%w[activesupport actionpack actionview].each { |f| $LOAD_PATH.unshift File.join(rails, f, "lib") }
require "useragent"
require "action_controller"
require "action_controller/metal/allow_browser"
def t(n = 200_000)
  best = Float::INFINITY
  3.times { GC.start; t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); n.times { yield }; best = [best, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / n * 1e9].min }
  best
end
def objs; GC.disable; a = GC.stat(:total_allocated_objects); yield; GC.stat(:total_allocated_objects) - a - 1; ensure GC.enable; end
class C < ActionController::Base
  protect_from_forgery with: :exception
end
req = ActionDispatch::TestRequest.create
ctrl = -> { c = C.new; c.set_request!(req); c }
check = ->(c) { c.send(:protect_against_forgery?) }
cs = Array.new(200_000) { ctrl.() }; i = -1
base = Array.new(200_000) { ctrl.() }; j = -1
t1 = t { check.(cs[i += 1] || (i = 0; cs[0])); }
t0 = t { base[j += 1] || (j = 0; base[0]) }
c = ctrl.(); o = objs { check.(c) }; o2 = objs { check.(c) }
puts format("protect_against_forgery? first call on a fresh controller: %d objects, %.0f ns; again: %d objects", o, t1 - t0, o2)
Req = Struct.new(:user_agent)
BB = ActionController::AllowBrowser.const_get(:BrowserBlocker)
r = Req.new("Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0")
t(20_000) { BB.new(r, versions: :modern).blocked? }
puts format("BrowserBlocker#blocked? :modern Firefox 140: %d objects, %.0f ns", objs { BB.new(r, versions: :modern).blocked? }, t(50_000) { BB.new(r, versions: :modern).blocked? })
h = { chrome: 120 }
puts format("BrowserBlocker#blocked? custom Hash (control): %d objects, %.0f ns", objs { BB.new(r, versions: h).blocked? }, t(50_000) { BB.new(r, versions: h).blocked? })
puts "yjit=#{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?} #{rails}"
