# Differential harness for C4 (number_to_currency i18n defaults): run in main and candidate, diff.
require "active_support"
require "bigdecimal"
require "active_support/number_helper"
require "active_support/core_ext/hash/indifferent_access"
I18n.enforce_available_locales = false
b = I18n.backend
b.store_translations :full, number: { format: { separator: ",", delimiter: "." }, currency: { format: { unit: "€", format: "%n %u", negative_format: "(%n %u)" } } }
b.store_translations :fmt_only, number: { currency: { format: { format: "%u%n!" } } }
b.store_translations :nil_neg, number: { currency: { format: { format: "%n%u", negative_format: nil } } }
b.store_translations :base_only, number: { format: { precision: 1, separator: "_" } }
b.store_translations :str_fmt, number: { format: "oops" }
LOG = []
class Mutating < I18n::Backend::Simple
  def translate(locale, key, options = {})
    r = super
    LOG << "#{key} default=#{options[:default].inspect} frozen=#{options[:default].frozen?}" if key.to_s.include?("format")
    r
  end
end
nums = [10, -10, 1234.5678, "12x", nil, BigDecimal("-0.001"), -0.004, Float::INFINITY]
optsets = [{}, { locale: :full }, { locale: :fmt_only }, { locale: :nil_neg }, { locale: :base_only }, { locale: :str_fmt },
  { locale: :full, format: "%u %n" }, { locale: :none, precision: 0 }, { negative_format: "neg %n" }]
fb = Class.new(I18n::Backend::Simple) { include I18n::Backend::Fallbacks }.new
[I18n.backend, Mutating.new, fb].each_with_index do |backend, i|
  I18n.backend = backend
  b.instance_variable_get(:@translations)&.each { |l, t| backend.store_translations(l, t) } if i > 0
  I18n.fallbacks = [:full] if i == 2
  nums.product(optsets).each do |n, o|
    LOG.clear
    r = begin
      ActiveSupport::NumberHelper.number_to_currency(n, o).inspect
    rescue => e
      "#{e.class}: #{e.message}"
    end
    puts "#{i} #{n.inspect} #{o.inspect} => #{r}"
  end
end
