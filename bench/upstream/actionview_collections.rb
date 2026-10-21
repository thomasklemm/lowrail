# frozen_string_literal: true

# Stock Rails, no Lowrail. Run before and after in separate idle processes:
#   ruby actionview_collections.rb RAILS_CHECKOUT LABEL OUTPUT_PREFIX
#   ruby --yjit actionview_collections.rb RAILS_CHECKOUT LABEL OUTPUT_PREFIX
# Use a fresh prefix per mode. benchmark-ips 2.15.1 save! loads earlier runs.
# Timings are exploratory helper measurements, not request-speed claims.
require "benchmark/ips"
require "tmpdir"
require "fileutils"

rails, label, prefix = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless prefix
%w[activesupport actionpack actionview activemodel].each do |component|
  $LOAD_PATH.unshift File.join(File.expand_path(rails), component, "lib")
end

require "action_controller"
require "action_view"

class CollectionBenchController < ActionController::Base
end

class CollectionBenchRecord < Struct.new(:name, :id, :path)
  def to_partial_path
    path
  end

  def cache_key
    "records/#{id}"
  end
end

puts RUBY_DESCRIPTION
puts "benchmark-ips #{Benchmark::IPS::VERSION}; label=#{label}; rails=#{File.expand_path(rails)}"
puts "warmup=2s; time=5s; allocations=2,000 warmed operations, GC enabled"

Dir.mktmpdir("actionview-collections") do |directory|
  FileUtils.mkdir_p(File.join(directory, "bench"))
  {
    "_item.html.erb" => "<i><%= record.name %></i>",
    "_other.html.erb" => "<b><%= record.name %></b>",
    "_layout.html.erb" => "[<%= yield %>]",
    "_static.html" => "static"
  }.each { |name, source| File.write(File.join(directory, "bench", name), source) }

  view = Class.new(ActionView::Base.with_empty_template_cache) do
    def view_cache_dependencies; []; end
    def combined_fragment_cache_key(key); [:views, key]; end
  end.with_view_paths([directory])
  view.lookup_context.prefixes = ["bench"]
  view.controller = CollectionBenchController.new
  view.controller.perform_caching = true

  records = Array.new(20) { |i| CollectionBenchRecord.new("R#{i}<&", i, "bench/item") }
  mixed = records.each_with_index.map do |record, i|
    CollectionBenchRecord.new(record.name, record.id, i.even? ? "bench/item" : "bench/other")
  end
  cold_store = ActiveSupport::Cache::MemoryStore.new
  warm_store = ActiveSupport::Cache::MemoryStore.new
  ActionView::PartialRenderer.collection_cache = warm_store
  view.render(partial: "bench/item", collection: records, as: :record, cached: true)

  scenarios = {
    "partial control" => -> { view.render(partial: "bench/item", locals: { record: records.first }) },
    "object control" => -> { view.render(partial: records.first, as: :record) },
    "shared ERB control (20)" => -> { view.render(partial: "bench/item", collection: records, as: :record) },
    "return-value HTML (20)" => -> { view.render(partial: "bench/static", collection: records) },
    "per-item layout (20)" => -> { view.render(partial: "bench/item", collection: records, as: :record, layout: "bench/layout") },
    "heterogeneous (20)" => -> { view.render(partial: mixed, as: :record) },
    "cached cold (20)" => -> {
      ActionView::PartialRenderer.collection_cache = cold_store
      cold_store.clear
      view.render(partial: "bench/item", collection: records, as: :record, cached: true)
    },
    "cached warm control (20)" => -> {
      ActionView::PartialRenderer.collection_cache = warm_store
      view.render(partial: "bench/item", collection: records, as: :record, cached: true)
    }
  }
  escaped = records.map { |record| ERB::Util.html_escape(record.name) }
  expected = [
    "<i>#{escaped.first}</i>", "<i>#{escaped.first}</i>",
    escaped.map { |name| "<i>#{name}</i>" }.join,
    "static" * records.size,
    escaped.map { |name| "[<i>#{name}</i>]" }.join,
    escaped.each_with_index.map { |name, i| tag = i.even? ? "i" : "b"; "<#{tag}>#{name}</#{tag}>" }.join
  ]
  expected.concat([expected[2], expected[2]])

  scenarios.each_with_index do |(name, operation), index|
    output = operation.call
    raise "wrong output for #{name}: #{output.inspect}" unless output == expected[index] && output.html_safe? && output.encoding == Encoding::UTF_8
    100.times { operation.call }
    GC.start
    before = GC.stat(:total_allocated_objects)
    2_000.times { operation.call }
    allocated = GC.stat(:total_allocated_objects) - before
    puts "#{name}: #{allocated.fdiv(2_000)} objects/op"

    Benchmark.ips do |x|
      x.config(warmup: 2, time: 5)
      x.report("#{label}: #{name}", &operation)
      x.save!("#{prefix}-#{index}")
      x.compare!(order: :baseline)
    end
  end
end
