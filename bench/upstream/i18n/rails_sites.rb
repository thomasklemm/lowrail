# frozen_string_literal: true

# Objects, time and allocation sites of Rails' translation paths, for
# docs/upstream/i18n-performance.md: TranslationHelper#translate, human_attribute_name,
# Errors#add / #full_messages, model_name.human, l and number helpers.
#   cd RAILS_CHECKOUT && bundle exec ruby -I I18N_LIB_DIR rails_sites.rb [--sites] [--fallbacks=0] [--only=REGEX]
SITES = ARGV.include?("--sites")
FALLBACKS = ARGV.find { _1.start_with?("--fallbacks=") }&.split("=")&.last != "0"
ONLY = ARGV.find { _1.start_with?("--only=") }&.then { Regexp.new(_1.split("=", 2).last) }
require "objspace"
require "active_model"
require "action_view"
require "i18n/backend/fallbacks"
if FALLBACKS
  I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
  I18n.fallbacks = I18n::Locale::Fallbacks.new(de: :en)
end
I18n.available_locales = %i[en de]
I18n.enforce_available_locales = true
I18n.backend.store_translations(:en,
  activemodel: { models: { post: "Article" }, attributes: { post: { title: "Headline" } } },
  posts: { index: { title: "All posts", count: { one: "%{count} post", other: "%{count} posts" } } },
  helpers: { label: { post: { title: "Your headline" } } },
  date: { formats: { short: "%b %d" } })
I18n.backend.send(:init_translations)

class Post
  include ActiveModel::Model
  include ActiveModel::Validations
  attr_accessor :title, :body
  validates :title, :body, presence: true
end
POST = Post.new.tap(&:valid?)

class View
  include ActionView::Helpers::TranslationHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TagHelper
  def initialize = @virtual_path = "posts/index"
end
VIEW = View.new
DATE = Date.new(2026, 11, 3)

CASES = {
  "view t('.title')" => -> { VIEW.t(".title") },
  "view t('.count', count: 3)" => -> { VIEW.t(".count", count: 3) },
  "view t(:x, default: 'y') (miss)" => -> { VIEW.t(:missing_key, default: "Fallback") },
  "view l(date, format: :short)" => -> { VIEW.l(DATE, format: :short) },
  "number_to_currency(12.5)" => -> { VIEW.number_to_currency(12.5) },
  "human_attribute_name(:title) hit" => -> { Post.human_attribute_name(:title) },
  "human_attribute_name(:body) miss" => -> { Post.human_attribute_name(:body) },
  "model_name.human" => -> { Post.model_name.human },
  "errors.full_messages (2)" => -> { POST.errors.full_messages },
  "errors.add(:title, :blank)" => -> { ActiveModel::Errors.new(POST).add(:title, :blank).message },
}.select { |name, _| ONLY.nil? || ONLY.match?(name) }.freeze

def sites(call, n = 500)
  GC.start
  GC.disable
  ObjectSpace.trace_object_allocations_start
  n.times { call.() }
  ObjectSpace.trace_object_allocations_stop
  tally = Hash.new(0)
  ObjectSpace.each_object do |o|
    file = ObjectSpace.allocation_sourcefile(o) or next
    tally["#{file.sub(%r{.*/(lib|gems)/}, "")}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
  end
  ObjectSpace.trace_object_allocations_clear
  GC.enable
  tally.select { |_, c| c >= n / 2 }.sort_by { -_2 }.map { |k, c| [k, c.fdiv(n)] }
end

N = 10_000
puts "#{RUBY_DESCRIPTION} i18n=#{I18n::VERSION} (#{$LOADED_FEATURES.grep(%r{/i18n\.rb\z}).first}) rails=#{ActiveSupport.version} fallbacks=#{FALLBACKS}"
CASES.each do |name, call|
  500.times { call.() }
  if SITES
    puts "== #{name}"
    sites(call).each { |site, per| printf("  %5.2f  %s\n", per, site) }
    next
  end
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  N.times { call.() }
  objects = (GC.stat(:total_allocated_objects) - before).fdiv(N)
  GC.enable
  times = Array.new(7) do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    N.times { call.() }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / N * 1e9
  end
  printf("%-36s %6.2f objects/call %8.0f ns/call\n", name, objects, times.sort[3])
end
