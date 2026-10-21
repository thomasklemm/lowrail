# frozen_string_literal: true

# Compare the JSON from two Rails checkouts; this is an investigation script,
# not a framework test or a claim about every possible override/interleaving.
require "tmpdir"
require "fileutils"
require "json"

rails = File.expand_path(ARGV.fetch(0))
%w[activesupport actionpack actionview activemodel].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "action_controller"
require "action_view"

class CollectionControlController < ActionController::Base
end

class CollectionControlRecord < Struct.new(:name, :id, :path, :calls)
  def to_partial_path
    calls << name
    path
  end

  def cache_key
    "records/#{id}"
  end
end

class YieldObservingCollection < Array
  attr_reader :yield_results

  def each
    @yield_results = []
    super { |item| @yield_results << yield(item) }
  end
end

Dir.mktmpdir("actionview-controls") do |directory|
  FileUtils.mkdir_p(File.join(directory, "bench"))
  item = "<% observe(local_assigns) %><%= (local_assigns[:record] || local_assigns[:entry] || local_assigns[:item]).name %>;"
  {
    "_item.html.erb" => item,
    "_other.html.erb" => "B#{item.sub('[:item]', '[:other]')}",
    "_single.html.erb" => "<% observe(local_assigns) %><%= record.name %>",
    "_strict.html.erb" => "<%# locals: (record:) %><%= record.name %>;",
    "_layout.html.erb" => "[<% observe(local_assigns) %><%= yield %>]",
    "_spacer.html.erb" => "<% observe(local_assigns) %>|",
    "_static.html" => "static",
    "_boom.html.erb" => '<% raise "render failure" %>'
  }.each { |name, source| File.write(File.join(directory, "bench", name), source) }

  view_class = Class.new(ActionView::Base.with_empty_template_cache) do
    attr_accessor :observations

    def view_cache_dependencies; []; end
    def combined_fragment_cache_key(key); [:views, key]; end

    def observe(locals)
      observations << locals.sort_by { |key, _| key.to_s }.map do |key, value|
        value = case value
        when CollectionControlRecord then ["record", value.name]
        when ActionView::PartialIteration then ["iteration", value.index, value.size, value.first?, value.last?]
        else value
        end
        [key, value]
      end
    end
  end
  resolver = ActionView::FileSystemResolver.new(directory)
  view = view_class.with_view_paths([resolver])
  view.lookup_context.prefixes = ["bench"]
  view.controller = CollectionControlController.new
  view.controller.perform_caching = true
  ActionView::PartialRenderer.collection_cache = ActiveSupport::Cache::MemoryStore.new
  calls = []
  a = CollectionControlRecord.new("A<&", 1, "bench/item", calls)
  b = CollectionControlRecord.new("B", 2, "bench/other", calls)
  c = CollectionControlRecord.new("C", 3, "bench/item", calls)
  results = {}
  events = []
  subscriber = ActiveSupport::Notifications.subscribe(/\Arender_(partial|collection)\.action_view\z/) do |name, _, _, _, payload|
    event = payload.slice(:identifier, :layout, :count, :cache_hits, :cache_hit)
    event[:identifier] = event[:identifier]&.delete_prefix("#{directory}/")
    event[:locals] = payload[:locals]&.keys&.sort_by(&:to_s) if payload.key?(:locals)
    event[:exception] = payload[:exception] if payload.key?(:exception)
    events << [name, event]
  end

  run = ->(name, error: nil, &operation) do
    view.observations = []
    events.clear
    calls.clear
    result = begin
      body = operation.call
      raise "expected #{error}" if error
      [body, body&.html_safe?, body&.encoding&.name]
    rescue StandardError, NotImplementedError => exception
      raise unless error && exception.is_a?(error)
      [exception.class.name, exception.message.gsub(directory, "VIEWS")]
    end
    results[name] = [result, view.observations.dup, Marshal.load(Marshal.dump(events)), calls.dup]
  end

  run.call("partial") { view.render(partial: "bench/single", locals: { record: a }) }
  run.call("object") { view.render(partial: a, as: :record) }
  run.call("shared") { view.render(partial: "bench/item", collection: [a, c], as: :record) }
  run.call("as string layout spacer") { view.render(partial: "bench/item", collection: [a, c], as: "entry", layout: "bench/layout", spacer_template: "bench/spacer", locals: { note: false }) }
  run.call("mixed implicit locals") { view.render(partial: [a, b, c]) }
  run.call("mixed as") { view.render(partial: [a, b, c], as: :entry, spacer_template: "bench/spacer") }
  run.call("strict layout") { view.render(partial: "bench/strict", collection: [a, c], as: :record, layout: "bench/layout") }
  run.call("returning handler") { view.render(partial: "bench/static", collection: [a, c]) }
  run.call("cached cold duplicates") { view.render(partial: "bench/item", collection: [a, c, a], as: :record, cached: true, spacer_template: "bench/spacer") }
  run.call("cached warm duplicates") { view.render(partial: "bench/item", collection: [a, c, a], as: :record, cached: true, spacer_template: "bench/spacer") }
  run.call("cached partial hits") { view.render(partial: "bench/item", collection: [a, b, c], as: :record, cached: true) }
  run.call("cached mixed refusal", error: NotImplementedError) { view.render(partial: [a, b], cached: true) }
  run.call("cached callable") { view.render(partial: "bench/item", collection: [a, c], as: :record, cached: ->(record) { [record.id, "callable"] }) }
  run.call("empty") { view.render(partial: "bench/item", collection: [], spacer_template: "bench/spacer") }
  run.call("invalid as", error: ArgumentError) { view.render(partial: "bench/item", collection: [a], as: "bad name") }
  run.call("missing", error: ActionView::MissingTemplate) { view.render(partial: "bench/absent", collection: [a]) }
  run.call("exception", error: ActionView::Template::Error) { view.render(partial: "bench/boom", collection: [a], layout: "bench/layout") }
  run.call("block") { view.render(layout: "bench/layout", collection: [a, c]) { "block" } }
  observing = YieldObservingCollection.new([a, c])
  run.call("yield results") { view.render(partial: "bench/item", collection: observing, layout: "bench/layout") }
  raise "changed yield results" unless observing.yield_results == [nil, nil]
  results["yield values"] = observing.yield_results

  renderer_class = Class.new(ActionView::CollectionRenderer) do
    attr_reader :bodies

    private
      def build_rendered_collection(templates, spacer)
        @bodies = templates.map(&:body)
        super
      end
  end
  run.call("subclass") do
    renderer = renderer_class.new(view.lookup_context, locals: {}, as: :record)
    rendered = renderer.render_collection_with_partial([a, c], "bench/item", view, nil)
    raise "lost item bodies" unless renderer.bodies == ["A&lt;&amp;;", "C;"]
    rendered.body
  end
  ActiveSupport::Notifications.unsubscribe(subscriber)

  context = view.lookup_context
  first = context.find!("bench/item", [], true, [:record])
  raise "warm template not reused" unless context.find!("bench/item", [], true, [:record]).equal?(first)
  extra = context.find!("bench/item", [], true, [:record, :note])
  raise "local signatures collapsed" if extra.equal?(first)
  File.write(File.join(directory, "bench", "_item.html.erb"), "changed")
  raise "uncleared template changed" unless context.find!("bench/item", [], true, [:record]).equal?(first)
  resolver.clear_cache
  raise "clear did not invalidate" if context.find!("bench/item", [], true, [:record]).equal?(first)
  results["resolver controls"] = "warm reuse, local signatures, stale until clear, invalidation passed"

  outputs = 4.times.map do
    Thread.new do
      own_view = view_class.with_view_paths([resolver])
      own_view.observations = []
      20.times.map { own_view.render(partial: "bench/static", collection: [1, 2, 3]) }.uniq
    end
  end.map(&:value)
  raise "thread smoke failed" unless outputs == Array.new(4) { ["staticstaticstatic"] }
  results["thread smoke"] = "4 independent views x 20 renders passed"
  puts JSON.pretty_generate(results)
end
