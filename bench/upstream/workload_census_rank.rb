# frozen_string_literal: true

require "json"

output, *inputs = ARGV
abort "usage: workload_census_rank.rb NEW_JSON PROFILE..." unless output && !inputs.empty?
abort "fresh output required" if File.exist?(output)
profiles = inputs.map { JSON.parse(File.read(_1)) }
raise "do not mix boot and warm profiles" unless profiles.map { _1.key?("operations") }.uniq.size == 1
boot = !profiles.first.key?("operations")
ranked_profiles = profiles.map do |profile|
  next profile if profile.key?("operations")

  sites = profile.fetch("sites").map { _1.merge("objects_per_operation" => _1.fetch("objects_per_boot")) }
  profile.merge("operations" => [{ "operation" => "boot", "sites" => sites }])
end
ranked_profiles.group_by { _1.fetch("app") }.each do |app, pair|
  raise "#{app}: need exactly interpreter + YJIT" unless pair.map { _1.fetch("yjit") }.sort_by(&:to_s) == [false, true]
  %w[source lock_sha256 rails].each { |key| raise "#{app}: #{key} differs" unless pair.map { _1.fetch(key) }.uniq.one? }
  labels = pair.map { _1.fetch("operations").map { |operation| operation.fetch("operation") } }
  raise "#{app}: operations differ" unless labels.first == labels.last
end
rows = {}
ranked_profiles.each do |profile|
  operations = profile.fetch("operations")
  operations.each do |operation|
    operation.fetch("sites").each do |site|
      next unless %w[rails ruby gem].include?(site.fetch("owner"))
      next if !boot && site.fetch("file").match?(%r{/rack/mock_(?:request|response)\.rb\z})
      key = site.values_at("owner", "file", "line")
      row = rows[key] ||= { owner: key[0], file: key[1], line: key[2], per_app: Hash.new(0), exposures: {} }
      objects = site.fetch("objects_per_operation")
      row[:per_app][profile.fetch("app")] += objects.fdiv(2 * operations.size)
      exposure = [profile.fetch("app"), operation.fetch("operation"), profile.fetch("yjit") ? "yjit" : "interpreter"].join(":")
      row[:exposures][exposure] = row[:exposures].fetch(exposure, 0) + objects
    end
  end
end
ranking = rows.values.each { _1[:score] = _1[:per_app].values.sum }.sort_by { [-_1[:score], _1[:file], _1[:line].to_i] }
ranking.each_with_index { |row, i| row[:rank] = i + 1 }
File.write(output, JSON.pretty_generate(profiles: profiles, ranking: ranking) + "\n")
puts "rank\towner\tfile\tline\tscore\tper_app"
ranking.each { |row| puts [row[:rank], row[:owner], row[:file], row[:line], row[:score].round(4), JSON.generate(row[:per_app])].join("\t") }
