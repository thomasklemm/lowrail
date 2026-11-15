# Callgrind body for UA1: allow_browser's check (versions: :modern), or UserAgent.parse alone, over the UA1
# user agents, inside Array#cycle so --toggle-collect=rb_ary_cycle collects only that. GC is off in the window.
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle ruby [--yjit] -rbundler/setup \
#     ir.rb check|parse ROUNDS
require "action_controller"
require "useragent"
require_relative "uas"

what, rounds = ARGV[0], Integer(ARGV[1])
Request = Struct.new(:user_agent)
Blocker = ActionController::AllowBrowser::BrowserBlocker
work = { "check" => UA1::UAS.values.map { |ua| r = Request.new(ua); -> { Blocker.new(r, versions: :modern).blocked? } },
         "parse" => UA1::UAS.values.map { |ua| -> { UserAgent.parse(ua) } } }.fetch(what)
300.times { work.each(&:call) }
GC.start
GC.disable
blocks = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? -> { RubyVM::YJIT.runtime_stats[:compiled_block_count] } : -> { 0 }
b0, o0 = blocks.call, GC.stat(:total_allocated_objects)
work.cycle(rounds, &:call)
puts "UA1 compiled_blocks=#{blocks.call - b0} objects=#{GC.stat(:total_allocated_objects) - o0}"
