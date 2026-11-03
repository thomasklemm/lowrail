rails = ENV.fetch("RAILS")
%w[activesupport actionpack actionview].each { |f| $LOAD_PATH.unshift File.join(rails, f, "lib") }
require "useragent"; require "action_controller"; require "action_controller/metal/allow_browser"
BB = ActionController::AllowBrowser.const_get(:BrowserBlocker)
r = Struct.new(:user_agent).new("x")
def t(n = 500_000) = 5.times.map { GC.start; t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); n.times { yield }; (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / n * 1e9 }.min
GC.disable; a = GC.stat(:total_allocated_objects); BB.new(r, versions: :modern).send(:expanded_versions)["firefox"]; o = GC.stat(:total_allocated_objects) - a; GC.enable
base = t { BB.new(r, versions: :modern) }
full = t { BB.new(r, versions: :modern).send(:expanded_versions)["firefox"] }
puts format("%-28s %s expanded_versions[\"firefox\"]: %d objects (incl. blocker), %.0f ns over BrowserBlocker.new", File.basename(rails), defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "yjit  " : "interp", o, full - base)
p Ractor.shareable?(BB::EXPANDED_SETS) if BB.const_defined?(:EXPANDED_SETS)
