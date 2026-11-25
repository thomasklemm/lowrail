# Merge ecosystem-1, ecosystem-2 and round-59141 suites into census 11's manifest (later rounds win).
require "yaml"
dir = "bench/upstream/readiness"
suites = {}
%w[round-ecosystem-1 round-ecosystem-2 round-59141].each do |m|
  y = YAML.load_file("#{dir}/#{m}.yml", aliases: true)
  y.fetch("suites").each { |name, s| suites[name] = s.merge("x-from" => m) }
end
suites.delete_if { |name, _| name.start_with?("x-") }
puts YAML.dump("suites" => suites).sub(/\A---\n/, "")
