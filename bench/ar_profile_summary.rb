# frozen_string_literal: true

# ruby bench/ar_profile_summary.rb STACKPROF.json
# Inclusive boundaries overlap; deepest-boundary attribution is disjoint.
# This is a planning-budget diagnostic, not a claim that boundary time is removable.
require "json"

module ARProfileSummary
  module_function

  def category(frame)
    name = frame.fetch("name", "")
    file = frame.fetch("file", "")
    return "execution" if name.match?(/ActiveRecord::ConnectionAdapters::.*#(?:raw_execute|perform_query|execute_batch_statements)\z/)
    return "types_instantiation" if name.match?(/\AActiveModel::(?:Attribute|LazyAttribute|Type::)/) ||
      name.match?(/\AActiveRecord::(?:Type::|AttributeMethods|AttributeSet|TypeCaster)/) ||
      name.match?(/ActiveRecord::.*[#.](?:instantiate\w*|_instantiate\w*|_load_from_sql|attributes_builder)\z/)
    return "sql_building_arel" if name.start_with?("Arel::") ||
      name.match?(/\AActiveRecord::(?:PredicateBuilder|TableMetadata|Relation::WhereClause)/) ||
      name.match?(/ActiveRecord::QueryMethods#(?:build_\w+|arel|where!?|order!?|select!?|limit!?)\z/)
    return "association_loading" if file.include?("/active_record/associations/")
  end

  def summarize(profile)
    frames = profile.fetch("frames")
    inclusive = Hash.new(0)
    exclusive = Hash.new(0)
    boundaries = Hash.new(0)
    total = 0
    raw = profile.fetch("raw")
    i = 0
    while i < raw.size
      length = raw.fetch(i)
      stack = raw.slice(i + 1, length).map { frames.fetch(_1.to_s) }
      count = raw.fetch(i + length + 1)
      categories = stack.filter_map { category(_1) }
      categories.uniq.each { inclusive[_1] += count }
      names = stack.map { _1.fetch("name") }
      boundaries["build_arel_and_visitors"] += count if names.any? { _1.match?(/ActiveRecord::QueryMethods#build_arel\z|\AArel::Visitors::/) }
      boundaries["preloader"] += count if names.any? { _1.start_with?("ActiveRecord::Associations::Preloader") }
      boundaries["association_scope"] += count if names.any? { _1.start_with?("ActiveRecord::Associations::AssociationScope") }
      leaf = categories.last || (stack.any? { _1["name"].start_with?("ActiveRecord::", "ActiveModel::") } ? "other_ar_am" : "outside_ar_am")
      exclusive[leaf] += count
      total += count
      i += length + 2
    end
    { samples: total, reported_samples: profile["samples"], missed_samples: profile["missed_samples"],
      boundaries: boundaries.transform_values { { samples: _1, pct: (100.0 * _1 / total).round(3) } },
      categories: (inclusive.keys | exclusive.keys).sort.to_h { |key|
        [key, { inclusive_samples: inclusive[key], deepest_samples: exclusive[key],
          inclusive_pct: (100.0 * inclusive[key] / total).round(3), deepest_pct: (100.0 * exclusive[key] / total).round(3) }]
      } }
  end
end

puts JSON.pretty_generate(ARProfileSummary.summarize(JSON.parse(File.read(ARGV.fetch(0))))) if $PROGRAM_NAME == __FILE__
