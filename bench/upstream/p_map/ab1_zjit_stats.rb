# frozen_string_literal: true

# AB1 review: ZJIT stats for a fixed number of allow_browser requests (the PR body's controller and user agent).
#   BUNDLE_GEMFILE=<main or branch Gemfile> ruby --zjit --zjit-stats-quiet -rbundler/setup THIS [N]
require "action_controller"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

app = PagesController.action(:show)
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
Integer(ARGV[0] || 20_000).times { app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent)) }

stats = RubyVM::ZJIT.stats
puts RUBY_DESCRIPTION
%i[compiled_iseq_count failed_iseq_count side_exit_count compiled_side_exit_count zjit_alloc_bytes
   compile_error_out_of_memory].each { |key| puts format("%-28s %d", key, stats[key] || 0) }
stats.select { |key, value| key.start_with?("exit_") && value.positive? }.sort_by { -_2 }.first(8)
     .each { |key, value| puts format("  %-26s %d", key, value) }
