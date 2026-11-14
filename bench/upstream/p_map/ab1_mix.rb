# frozen_string_literal: true

# AB1 review: allow_browser :modern's check per request under several user agent mixes, on main or the branch
# (whichever actionpack the bundle loads). Prints hit rates (branch only), then benchmark-ips per mix.
#   [MIXES=one,unique] BUNDLE_GEMFILE=.../Gemfile taskset -c 1 ruby [--yjit|--zjit] -I bench/upstream/p_map THIS [seconds|rates]
require "action_controller"
require "benchmark/ips"
require "ab1_uas"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

Blocker = ActionController::AllowBrowser::BrowserBlocker
cached = Blocker.respond_to?(:blocked?)
check = cached ? ->(request) { Blocker.blocked?(request, versions: :modern) } : ->(request) { Blocker.new(request, versions: :modern).blocked? }
seconds = Float(ARGV[0] == "rates" ? 0 : ARGV[0] || 3)

mixes = AB1UAs.mixes.slice(*ENV.fetch("MIXES", AB1UAs.mixes(1).keys.join(",")).split(",")).transform_values { |uas| uas.map { |ua| ActionDispatch::Request.new("HTTP_USER_AGENT" => ua) } }

if ARGV[0] == "rates"
  # Same verdicts as an uncached check, and the share of checks that parse.
  parses = 0
  Blocker.prepend(Module.new { define_method(:blocked?) { parses += 1; super() } })
  mixes.each do |name, requests|
    requests.each { |r| check.(r) }
    parses = 0
    misses = requests.count { |r| check.(r) }.then { parses }
    wrong = requests.count { |r| check.(r) != Blocker.new(r, versions: :modern).blocked? }
    raise "#{name}: #{wrong} verdicts differ" unless wrong.zero?
    blocked = requests.count { |r| Blocker.new(r, versions: :modern).blocked? }
    lengths = requests.map { |r| r.user_agent.bytesize }
    puts format("%-16s requests %d  distinct %5d  blocked %5.1f%%  mean UA %3d bytes  hit rate %5.1f%%", name, requests.size,
                requests.map(&:user_agent).uniq.size, 100.0 * blocked / requests.size, lengths.sum / lengths.size,
                100.0 * (requests.size - misses) / requests.size)
  end
  exit
end
puts RUBY_DESCRIPTION

Benchmark.ips do |x|
  x.config(time: seconds, warmup: 1)
  mixes.each do |name, requests|
    i = 0
    n = requests.size
    x.report(name) { check.(requests[i]); i += 1; i = 0 if i == n }
  end
end
