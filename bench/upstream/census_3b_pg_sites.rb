# frozen_string_literal: true

# Census-3b: Rails and pg-gem sites in the CodeTriage receipts, both modes averaged.
# ruby census_3b_pg_sites.rb [LIMIT]  (run from the census-3 receipt directory)
require "json"
agg = Hash.new(0.0)
%w[interpreter yjit].each do |m|
  p = JSON.parse(File.read("codetriage-#{m}.json"))
  p["routes"].each { |r| r["sites"].each { |s| agg[[s["file"].sub(%r{GEM/4\.0\.0/(bundler/)?gems/}, "GEM/"), s["line"], s["class"]]] += s["objects_per_request"] / 6.0 } }
end
rails = "/tmp/w/rails-bundled-orig"
agg.sort_by { -_2 }.select { |(f, *), _| f.start_with?("RAILS/") || f =~ %r{GEM/pg-} }.first(Integer(ARGV[0] || 60)).each do |(f, l, c), v|
  path = File.join(rails, f.sub("RAILS/", ""))
  src = File.exist?(path) ? File.readlines(path)[l - 1].to_s.strip[0, 90] : ""
  printf "%7.1f  %-12s %s:%s  %s\n", v, c[0, 12], f.sub("RAILS/", ""), l, src
end
