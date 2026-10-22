# frozen_string_literal: true

# Cheap rejection witnesses for proposed shortcuts, not accepted patches.
require "json"
require "tmpdir"
require "pathname"
require "rack"
require "active_support/all"
require "action_dispatch"
require "rails"
require "user_agent"
load File.join(Gem::Specification.find_by_name("rack-mini-profiler").full_gem_path, "lib/mini_profiler_rails/railtie.rb")
module Propshaft
  module Resolver; end
end
load File.join(ARGV.fetch(0), "lib/propshaft/manifest.rb")
load File.join(ARGV.fetch(0), "lib/propshaft/resolver/static.rb")

class RetainedScan < String
  attr_reader :parts

  def scan(...)
    @parts = super
  end
end
input = RetainedScan.new("140.2.31")
version = UserAgent::Version.new(input)
before = version.to_a
input.parts.clear
raise "baseline Version aliases scan" unless version.to_a == before
results = {useragent: {input: "String subclass retaining scan result", before: before,
  after_clearing_scan: version.to_a, map_bang_would_alias: true,
  unicode: {product: "ß", lookup: "SS", downcase_equal: "ß".downcase == "SS".downcase,
    casecmp_equal: "ß".casecmp?("SS")}}}

class RetainedSplit < String
  attr_reader :parts

  def split(...)
    @parts = super
  end
end
input = RetainedSplit.new("/app/views/articles/_card.html.erb")
first = Rack::MiniProfilerRails.shorten_identifier(input)
retained = input.parts.dup
first.clear
second = Rack::MiniProfilerRails.shorten_identifier(input)
raise "baseline shortened result aliases input" unless second == "articles/_card.html.erb"
parts = input.split("/")
parts.shift while parts.size > 2
reused = parts.join("/")
results[:mini_profiler] = {before: second, frozen_input: Rack::MiniProfilerRails.shorten_identifier(String.new(input).freeze),
  reused_value: reused, retained_split_before: retained, retained_split_after_reuse: parts,
  equivalent_retained_state: retained == parts}

Dir.mktmpdir("propshaft-ownership-") do |dir|
  manifest = Pathname.new(File.join(dir, "manifest.json"))
  manifest.write(JSON.generate("app.js" => "app-digest.js"))
  prefix = +"/assets"
  resolver = Propshaft::Resolver::Static.new(manifest_path: manifest, prefix: prefix)
  first = resolver.resolve("app.js")
  first.clear
  second = resolver.resolve("app.js".freeze)
  raise "baseline resolver aliases previous result" unless second == "/assets/app-digest.js"
  prefix.replace("/changed")
  third = resolver.resolve("app.js")
  raise "baseline resolver caches prefix" unless third == "/changed/app-digest.js"
  results[:propshaft] = {second_after_clearing_first: second, after_mutating_retained_prefix: third,
    frozen_prefix: Propshaft::Resolver::Static.new(manifest_path: manifest, prefix: "/frozen".freeze).resolve("app.js"),
    join_slashes: File.join("/assets/", "/app.js"), interpolated_slashes: "#{'/assets/'}/#{'/app.js'}"}
end
File.write(ARGV.fetch(1), JSON.pretty_generate(results) + "\n")
