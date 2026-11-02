# frozen_string_literal: true

# Aggregate exactly one receipt/app/mode, equal weight per route and per app.
# ruby rails_main_rank.rb NEW_JSON PROFILE_JSON...
require "json"
output, *inputs = ARGV
raise "fresh output and receipts required" if !output || inputs.empty? || File.exist?(output)
profiles = inputs.map { JSON.parse(File.read(_1)) }
raise "duplicate app/mode" unless profiles.map { [_1.fetch("app"), _1.fetch("yjit")] }.uniq.size == profiles.size
raise "mixed Rails pins" unless profiles.map { _1.fetch("rails") }.uniq.one?
raise "incomplete app/mode" unless profiles.group_by { _1.fetch("app") }.values.all? { _1.map { |p| p.fetch("yjit") }.sort_by(&:to_s) == [false, true] }
sites = {}
profiles.each do |profile|
  routes = profile.fetch("routes")
  routes.each do |route|
    route.fetch("sites").each do |site|
      file = site.fetch("file").sub(%r{\AGEM/4\.0\.0/(?:bundler/)?gems/}, "GEM/")
      # Rails, Rack and the Ruby-shipped gems present in these receipts only.
      # Keep other application dependencies in the raw profiles, not the ranking.
      next unless file.start_with?("RAILS/", "RUBY/") || file.match?(%r{\AGEM/(?:rack(?:-session)?|uri|json|base64|openssl|securerandom)-})
      # Rack mock response/request creation is client overhead, not framework work.
      next if file.match?(%r{/rack/mock(?:_request|_response)?\.rb\z})
      key = [file, site.fetch("line")]
      sites[key] ||= Hash.new(0.0)
      sites[key][profile.fetch("app")] += site.fetch("objects_per_request") / (2 * routes.size)
    end
  end
end
ranking = sites.map do |(file, line), apps|
  frequency = apps.count { |_, n| n.positive? }
  { file: file, line: line, apps: frequency, objects_per_present_app_request: apps.values.sum / frequency,
    score: apps.values.sum, per_app: apps }
end.sort_by { [-_1.fetch(:score), _1.fetch(:file), _1.fetch(:line) || 0] }
File.write(output, JSON.pretty_generate(profiles: profiles, ranking: ranking) + "\n")
ranking.first(40).each { puts "#{_1[:apps]}\t#{format('%.2f', _1[:score])}\t#{_1[:file]}:#{_1[:line]}" }
