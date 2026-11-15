# ZJIT stats for a fixed number of allow_browser checks (versions: :modern) over the 21 UA1 user agents.
#   BUNDLE_GEMFILE=<main or branch Gemfile> ruby --zjit --zjit-stats-quiet -rbundler/setup THIS [ROUNDS]
require "action_controller"
require "useragent"
require_relative "uas"

Request = Struct.new(:user_agent)
requests = UA1::UAS.values.map { |ua| Request.new(ua) }
Integer(ARGV[0] || 1_000).times { requests.each { |r| ActionController::AllowBrowser::BrowserBlocker.new(r, versions: :modern).blocked? } }

stats = RubyVM::ZJIT.stats
puts RUBY_DESCRIPTION
%i[compiled_iseq_count failed_iseq_count side_exit_count compiled_side_exit_count zjit_alloc_bytes
   compile_error_out_of_memory].each { |key| puts format("%-28s %d", key, stats[key] || 0) }
stats.select { |key, value| key.to_s.start_with?("exit_") && value.positive? }.sort_by { -_2 }.first(10)
     .each { |key, value| puts format("  %-26s %d", key, value) }
