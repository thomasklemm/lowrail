# frozen_string_literal: true

# Objects and time per I18n.t call with the Fallbacks backend (as in a Rails app
# with config.i18n.fallbacks), for docs/upstream/gem-census.md.
#   ruby [--yjit] i18n_micro.rb I18N_LIB_DIR
$LOAD_PATH.unshift(File.expand_path(ARGV.fetch(0)))
require "i18n"
require "i18n/backend/fallbacks"
I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
I18n.available_locales = %i[en de]
I18n.default_locale = :en
I18n.fallbacks = I18n::Locale::Fallbacks.new(de: :en)
I18n.backend.store_translations(:en, hello: "Hello", only_en: "Only en", greet: "Hi %{name}",
  activerecord: { attributes: { post: { title: "Title" } } }, attributes: { body: "Body" })
I18n.backend.store_translations(:de, hello: "Hallo")
MISSING = -(2**60) # ActiveModel::Translation::MISSING_TRANSLATION

CASES = {
  "t(:hello)" => -> { I18n.t(:hello) },
  "t(:greet, name:)" => -> { I18n.t(:greet, name: "Ann") },
  "t(:only_en, locale: :de) (falls back)" => -> { I18n.t(:only_en, locale: :de) },
  "human_attribute_name hit (Array default)" =>
    -> { I18n.t(:"activerecord.attributes.post.title", count: 1, raise: false, default: [:"attributes.title", MISSING]) },
  "human_attribute_name miss (Array default)" =>
    -> { I18n.t(:"activerecord.attributes.post.body", count: 1, raise: false, default: [:"attributes.body", MISSING]) },
  "String default, missing key" => -> { I18n.t(:missing, default: "Fallback") },
  "Symbol default, missing key" => -> { I18n.t(:missing, default: :hello) },
  "Hash default (number.format)" => -> { I18n.t(:"number.format", default: {}) },
}.freeze

N = 20_000
puts "#{RUBY_DESCRIPTION}"
CASES.each do |name, call|
  1000.times { call.() }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  N.times { call.() }
  objects = (GC.stat(:total_allocated_objects) - before).fdiv(N)
  GC.enable
  times = Array.new(5) do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    N.times { call.() }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / N * 1e9
  end
  printf("%-44s %6.2f objects/call %8.0f ns/call (median of 5)\n", name, objects, times.sort[2])
end
