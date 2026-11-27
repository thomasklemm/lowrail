# frozen_string_literal: true

# Cost of finding a Mash method suffix, per call: ruby [--yjit|--zjit] suffix_micro.rb
ALLOWED_SUFFIXES = %w[? ! = _].freeze
SUFFIX = /[?!=_]\z/.freeze
names = %w[stargazers_count full_name private? description= html_url owner! id name].map(&:freeze).freeze

def t(label, names)
  best = Float::INFINITY
  12.times do
    GC.start
    s = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
    i = 0
    while i < 200_000
      names.each { |n| yield n }
      i += 1
    end
    e = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - s
    best = e if e < best
  end
  puts format('%-44s %6.1f ns', label, best * 1e9 / (200_000 * names.size))
end

puts RUBY_DESCRIPTION
t('empty block', names) { |n| n }
t('end_with?(*ALLOWED_SUFFIXES)', names) { |n| n.end_with?(*ALLOWED_SUFFIXES) }
t("end_with?('?', '!', '=', '_')", names) { |n| n.end_with?('?', '!', '=', '_') }
t('match?(/[?!=_]\z/)', names) { |n| n.match?(SUFFIX) }
t('getbyte(-1) case', names) { |n| b = n.getbyte(-1); b == 63 || b == 33 || b == 61 || b == 95 }
t('n[-1] if end_with?(*ALLOWED_SUFFIXES)', names) { |n| n[-1] if n.end_with?(*ALLOWED_SUFFIXES) }
