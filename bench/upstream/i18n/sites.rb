# frozen_string_literal: true

# Objects, time and allocation sites per I18n call, for docs/upstream/i18n-performance.md.
# Covers I18n.t argument handling, key normalization, Simple#lookup, interpolation,
# pluralization, defaults, fallbacks and localize, with and without Backend::Fallbacks.
#   ruby [--yjit] sites.rb I18N_LIB_DIR [--sites|--cpu] [--fallbacks=0|1] [--only=REGEX]
# Without --sites it prints objects/call and the median ns/call of 7 batches.
# With --sites it prints the allocation sites (file:line, objects/call) per case;
# with --cpu the top stackprof frames (CPU mode, 20 µs) per case.
lib = File.expand_path(ARGV.fetch(0))
$LOAD_PATH.unshift(lib)
SITES = ARGV.include?("--sites")
CPU = ARGV.include?("--cpu") && require("stackprof")
FALLBACKS = ARGV.find { _1.start_with?("--fallbacks=") }&.split("=")&.last != "0"
ONLY = ARGV.find { _1.start_with?("--only=") }&.then { Regexp.new(_1.split("=", 2).last) }
require "i18n"
require "objspace"
require "date"
if FALLBACKS
  require "i18n/backend/fallbacks"
  I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
end
I18n.available_locales = %i[en de]
I18n.default_locale = :en
I18n.enforce_available_locales = true
I18n.fallbacks = I18n::Locale::Fallbacks.new(de: :en) if FALLBACKS
I18n.backend.store_translations(:en,
  hello: "Hello", only_en: "Only en", greet: "Hi %{name}", two: "%{a} and %{b}",
  pct: "100%% sure", link: :hello,
  inbox: { messages: { one: "%{count} message", other: "%{count} messages" } },
  dashboard: { cards: { title: "Net worth", subtitle: "As of %{date}" } },
  activerecord: { attributes: { post: { title: "Title" } } }, attributes: { body: "Body" },
  errors: { format: "%{attribute} %{message}", messages: { blank: "can't be blank" } },
  date: { formats: { default: "%Y-%m-%d", long: "%B %d, %Y" },
          month_names: [nil] + %w[January February March April May June July August September October November December],
          abbr_month_names: [nil] + %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec],
          day_names: %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday],
          abbr_day_names: %w[Sun Mon Tue Wed Thu Fri Sat] },
  time: { formats: { default: "%a, %d %b %Y %H:%M:%S %z", short: "%d %b %H:%M" }, am: "am", pm: "pm" },
  number: { format: { separator: ".", delimiter: ",", precision: 3 } })
I18n.backend.store_translations(:de, hello: "Hallo")
MISSING = -(2**60) # ActiveModel::Translation::MISSING_TRANSLATION
DATE = Date.new(2026, 11, 3)
TIME = Time.utc(2026, 11, 3, 12, 30)

CASES = {
  "t(:hello)" => -> { I18n.t(:hello) },
  "t('dashboard.cards.title')" => -> { I18n.t("dashboard.cards.title") },
  "t(:title, scope: [:dashboard, :cards])" => -> { I18n.t(:title, scope: [:dashboard, :cards]) },
  "t(:title, scope: 'dashboard.cards')" => -> { I18n.t(:title, scope: "dashboard.cards") },
  "t(:greet, name:)" => -> { I18n.t(:greet, name: "Ann") },
  "t(:two, a:, b:)" => -> { I18n.t(:two, a: "x", b: "y") },
  "t(:pct) (%% only)" => -> { I18n.t(:pct) },
  "t('inbox.messages', count: 3)" => -> { I18n.t("inbox.messages", count: 3) },
  "t(:link) (Symbol link)" => -> { I18n.t(:link) },
  "t(:only_en, locale: :de) (falls back)" => -> { I18n.t(:only_en, locale: :de) },
  "t(:hello, locale: :de)" => -> { I18n.t(:hello, locale: :de) },
  "String default, missing key" => -> { I18n.t(:missing, default: "Fallback") },
  "Symbol default, missing key" => -> { I18n.t(:missing, default: :hello) },
  "human_attribute_name hit" =>
    -> { I18n.t(:"activerecord.attributes.post.title", count: 1, raise: false, default: [:"attributes.title", MISSING]) },
  "human_attribute_name miss" =>
    -> { I18n.t(:"activerecord.attributes.post.body", count: 1, raise: false, default: [:"attributes.body", MISSING]) },
  "full_message format" =>
    -> { I18n.t(:"errors.format", default: "%{attribute} %{message}", attribute: "Title", message: "can't be blank") },
  "Hash default (number.format)" => -> { I18n.t(:"number.format", default: {}) },
  "exists?('dashboard.cards.title')" => -> { I18n.exists?("dashboard.cards.title") },
  "l(date, format: :long)" => -> { I18n.l(DATE, format: :long) },
  "l(time)" => -> { I18n.l(TIME) },
  "I18n.locale" => -> { I18n.locale },
  "with_locale(:de) { }" => -> { I18n.with_locale(:de) { } },
}.select { |name, _| ONLY.nil? || ONLY.match?(name) }.freeze

def sites(call, n = 1000)
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

N = 20_000
puts "#{RUBY_DESCRIPTION} i18n=#{I18n::VERSION} lib=#{lib} fallbacks=#{FALLBACKS}"
CALLS = ARGV.find { _1.start_with?("--calls=") }&.split("=")&.last&.to_i
CASES.each do |name, call|
  1000.times { call.() }
  if CALLS # for callgrind: Ir per call = (Ir(--calls=N) - Ir(--calls=0)) / N
    CALLS.times { call.() }
    next
  end
  if SITES
    puts "== #{name}"
    sites(call).each { |site, per| printf("  %5.2f  %s\n", per, site) }
    next
  end
  if CPU
    profile = StackProf.run(mode: :cpu, interval: 20, raw: false) { 200_000.times { call.() } }
    total = profile[:samples].to_f
    puts "== #{name} (#{profile[:samples]} samples)"
    profile[:frames].values.sort_by { -_1[:samples] }.first(12).each do |f|
      printf("  %5.1f%% self %5.1f%% total  %s %s:%s\n", 100 * f[:samples] / total, 100 * f[:total_samples] / total,
        f[:name], f[:file].to_s.sub(%r{.*/(lib|gems)/}, ""), f[:line])
    end
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
  printf("%-42s %6.2f objects/call %8.0f ns/call\n", name, objects, times.sort[3])
end
