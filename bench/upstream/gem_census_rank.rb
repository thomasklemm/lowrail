# frozen_string_literal: true

# Equal weight for apps, routes and modes. Versions stay distinct.
require "json"
output, *inputs = ARGV
raise "new output and receipts required" unless output && !inputs.empty? && !File.exist?(output)
profiles = inputs.map { JSON.parse(File.read(_1)) }
raise "duplicate app/mode" unless profiles.map { [_1.fetch("app"), _1.fetch("yjit")] }.uniq.size == profiles.size
raise "incomplete mode pairs" unless profiles.group_by { _1.fetch("app") }.values.all? { _1.map { |p| p.fetch("yjit") }.sort_by(&:to_s) == [false, true] }
rails_gems = %w[rails railties actionpack actionview actioncable actionmailer actionmailbox actiontext activejob activemodel activerecord activestorage activesupport]
sites = {}
profiles.each do |profile|
  routes = profile.fetch("routes")
  routes.each do |route|
    route.fetch("sites").each do |site|
      file = site.fetch("file")
      next unless file.start_with?("GEM/")
      gem = file.split("/", 3).fetch(1)
      next if rails_gems.any? { gem.start_with?(_1 + "-") }
      next if file.match?(%r{/rack/mock(?:_request|_response)?\.rb\z})
      key = [file, site.fetch("line")]
      sites[key] ||= Hash.new(0.0)
      sites[key][profile.fetch("app")] += site.fetch("objects_per_request") / (2 * routes.size)
    end
  end
end
ranking = sites.map do |(file, line), apps|
  {file: file, line: line, apps: apps.size, objects_per_present_app_request: apps.values.sum / apps.size,
    score: apps.values.sum, per_app: apps}
end.sort_by { [-_1.fetch(:score), _1.fetch(:file), _1.fetch(:line) || 0] }
File.write(output, JSON.pretty_generate(profiles: profiles, ranking: ranking) + "\n")
ranking.first(50).each { puts "#{format('%.2f', _1[:score])}\t#{_1[:file]}:#{_1[:line]}\t#{_1[:per_app]}" }
