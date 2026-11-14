# frozen_string_literal: true

# AB1 review: Callgrind instructions per miss, uncached (main's code) against cached (the branch), GC off.
# The measured loop runs inside Array#cycle, which Callgrind's --toggle-collect=rb_ary_cycle collects.
#   BUNDLE_GEMFILE=<branch Gemfile> valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle \
#     ruby -rbundler/setup -I bench/upstream/p_map THIS uncached|cached N
require "action_controller"
require "useragent"
require "ab1_uas"

Blocker = ActionController::AllowBrowser::BrowserBlocker
mode, n = ARGV[0], Integer(ARGV[1] || 2_000)
warm = (0...3_000).map { |i| ActionDispatch::Request.new("HTTP_USER_AGENT" => AB1UAs.tail(50_000 + i)) }
measured = (0...n).map { |i| ActionDispatch::Request.new("HTTP_USER_AGENT" => AB1UAs.tail(90_000 + i)) }
check = { "uncached" => ->(r) { Blocker.new(r, versions: :modern).blocked? },
          "cached" => ->(r) { Blocker.blocked?(r, versions: :modern) } }.fetch(mode)
warm.each { |r| check.(r) }
GC.start
GC.disable
measured.cycle(1) { |r| check.(r) }
