# frozen_string_literal: true
# Allocations per call, by allocation site, for form helpers on a Rails checkout (ARGV[0]).
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_model"
require "action_view"
require "objspace"

if ENV["AM"]
  class Post
    include ActiveModel::Model
    include ActiveModel::Attributes
    attribute :title, :string
    attribute :published, :boolean
    attribute :category, :string
  end
else
  gem "sqlite3", "2.10.2"
  require "active_record"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.boolean :published; t.string :category } }
  class Post < ActiveRecord::Base; end
end

V = ActionView::Base.empty
POST = ENV["AM"] ? Post.new(title: "Hello", published: true, category: "news") : Post.create!(title: "Hello", published: true, category: "news")
F = ActionView::Helpers::FormBuilder.new(:post, POST, V, {})

SCENARIOS = {
  "text_field_tag" => -> { V.text_field_tag("q", "x") },
  "hidden_field_tag" => -> { V.hidden_field_tag("post[tag_ids][]", "1") },
  "email_field_tag w/ class" => -> { V.email_field_tag("email", "a@b.c", class: "input") },
  "label_tag" => -> { V.label_tag("q", "Query") },
  "check_box_tag" => -> { V.check_box_tag("accept", "1", true) },
  "f.text_field" => -> { F.text_field(:title) },
  "f.text_field w/ class" => -> { F.text_field(:title, class: "input") },
  "f.hidden_field" => -> { F.hidden_field(:title) },
  "f.label" => -> { F.label(:title) },
  "f.check_box" => -> { F.check_box(:published) },
  "f.select" => -> { F.select(:category, %w[news blog]) },
  "f.submit" => -> { F.submit },
}

require_relative "form_stack_patches"
only = ARGV[1]
if ENV["IPS"]
  require "benchmark/ips"
  Benchmark.ips(quiet: true) do |x|
    x.config(warmup: 1, time: 3)
    SCENARIOS.each { |l, fn| next if only && !l.match?(only); x.report(l, &fn) }
    x.json!("/tmp/k6s/ips_#{ENV["PATCH"]}_#{ENV["ROUND"]}.json")
  end
  exit
end
if ENV["OUT"]
  SCENARIOS.each { |l, fn| puts "#{l}\t#{fn.call}" }
  exit
end
SCENARIOS.each do |label, fn|
  next if only && !label.include?(only)
  3.times { fn.call }
  GC.start
  GC.disable
  ObjectSpace.trace_object_allocations_start
  g = GC.count
  fn.call
  ObjectSpace.trace_object_allocations_stop
  sites = ObjectSpace.each_object(BasicObject).select { |o| (ObjectSpace.allocation_generation(o) == g rescue false) }
    .map { |o| "#{o.class} #{ObjectSpace.allocation_sourcefile(o).to_s.sub(%r{.*/lib/}, '')}:#{ObjectSpace.allocation_sourceline(o)}" }
  ObjectSpace.trace_object_allocations_clear
  GC.enable
  puts "== #{label}: #{sites.size} objects"
  sites.tally.sort_by { |k, v| [-v, k] }.each { |k, v| puts "  #{v} #{k}" } if ENV["SITES"]
end
