# frozen_string_literal: true

# QB1: inclusive share of server time of query-building mechanisms (a sample
# counts when any frame on its stack matches), from p_map/profile.rb receipts:
#   ruby mechanisms.rb RECEIPT.json...
require_relative "stages"

module QBMechanisms
  ROWS = [
    ["Association reader: scope built before the statement cache (#59212's lever)", ->(f) { QBStages.assoc_scope_before_cache?(f) }],
    ["Association#scope (any caller)", /\AActiveRecord::Associations::(?:Collection)?Association#scope\z/],
    ["AssociationScope.scope (per owner record)", /\AActiveRecord::Associations::AssociationScope#scope\z/],
    ["CollectionProxy#scope (has_many chains, count, exists?)", /\AActiveRecord::Associations::CollectionProxy#scope\z/],
    ["Preloader scope building (LoaderQuery, reflection_scope)", /Preloader::Association#(?:scope|reflection_scope|build_scope|loader_query)\z/],
    ["Named scope bodies (_exec_scope)", /Relation#_exec_scope\z/],
    ["default_scope evaluation", /#(?:build_default_scope|evaluate_default_scope)\z/],
    ["Relation::Merger#merge", /Relation::Merger#merge\z/],
    ["Relation copies (spawn, initialize_copy)", /#(?:spawn|initialize_copy)\z/],
    ["build_arel", /QueryMethods#build_arel\z/],
    ["Arel visitor compile", /Arel::Visitors::\w+#(?:compile|accept)\z/],
    ["to_sql_and_binds", /#to_sql_and_binds\z/],
    ["StatementCache#execute (all of it, incl. DB)", /StatementCache#execute\z/],
    ["StatementCache.create (first use)", /StatementCache\.create\z/],
    ["Query cache lookup (cache_sql)", /QueryCache#cache_sql\z/],
    ["QueryLogs", /QueryLogs/],
  ].freeze

  module_function

  def shares(path)
    d = PMapReport.load(path)
    interval_ms = d["interval_us"] / 1000.0
    total = Hash.new(0.0)
    hit = Hash.new { |h, k| h[k] = Hash.new(0.0) }
    d["threads"].each do |t|
      worker = t["name"].match?(/tp \d+\z/)
      puma = t["name"].match?(/\Apuma (srv|reactor)\z/)
      next unless worker || puma
      t["samples"].each do |stack, category, window, n|
        next if window.nil?
        frames = d["stacks"].fetch(stack.to_s)
        ms = n * interval_ms
        if category == 0 || (worker && category != 2 && PMapLayers.in_request?(frames))
          total[window] += ms
        else
          next
        end
        next unless category == 0 && worker
        ROWS.each do |name, m|
          match = m.is_a?(Proc) ? m.call(frames) : frames.any? { |label, _, _| label.match?(m) }
          hit[window][name] += ms if match
        end
      end
    end
    d["windows"].each_with_index { |w, i| total[i] += w["gc_ns"] / 1e6 }
    n = d["windows"].size
    [d["app"], ROWS.to_h { |name, _| [name, d["windows"].each_index.sum { 100.0 * hit[_1][name] / total[_1] } / n] }]
  end
end

if $PROGRAM_NAME == __FILE__
  apps = ARGV.map { QBMechanisms.shares(_1) }
  puts "| Mechanism (inclusive) | #{apps.map(&:first).join(" | ")} | mean |\n|---|#{"---:|" * (apps.size + 1)}"
  QBMechanisms::ROWS.each do |name, _|
    vals = apps.map { _2[name] }
    puts "| #{name} | #{vals.map { format("%.2f", _1) }.join(" | ")} | #{format("%.2f", vals.sum / vals.size)} |"
  end
end
