# frozen_string_literal: true

# ruby bench/ar_survey.rb .corpus/{real-blog,campfire,pingcrm,redprints-cfp,react-starter-kit}
require_relative "../gem/lib/lowrail"
require_relative "../gem/lib/lowrail/ar_plan_sites"

if $PROGRAM_NAME == __FILE__
  puts JSON.pretty_generate(ARGV.flat_map { Lowrail::ARPlanSites.inventory(_1) })
end
