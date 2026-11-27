# frozen_string_literal: true

# Who calls LazyIndexedAttributeSet#keys / #[] / row_keys during each case, with counts.
require_relative "setup_model"

cases = l6_cases
cases.each_value { |c| 5.times { c.call } }
targets = %i[keys [] row_keys to_hash index_for_name lookup attribute_at default_attribute]
cases.each do |name, call|
  counts = Hash.new(0)
  callers = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    next unless t.defined_class == ActiveModel::LazyIndexedAttributeSet || t.defined_class == ActiveModel::AttributeSet
    next unless targets.include?(t.method_id)
    counts[t.method_id] += 1
    if %i[keys [] to_hash].include?(t.method_id)
      loc = caller_locations(2, 6).map { |l| "#{l.path.sub(%r{.*/(active\w+)/lib/}, '\1/')}:#{l.lineno}:#{l.label}" }
      loc = loc.reject { |l| l.include?("attribute_set.rb") }.first(3)
      callers[[t.method_id, loc]] += 1
    end
  end
  tp.enable { call.call }
  puts "== #{name} (COLS=#{COLS}, #{RUBY_VERSION}, #{File.basename(Gem.loaded_specs['activemodel'].full_gem_path.sub('/activemodel', ''))})"
  counts.sort.each { |k, v| puts "  #{k}: #{v}" }
  callers.sort_by { |(m, _), v| [m.to_s, -v] }.each { |(m, loc), v| puts "  #{m} x#{v}  #{loc.join(' <- ')}" }
end
