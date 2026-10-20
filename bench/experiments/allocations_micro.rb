# frozen_string_literal: true

# Handwritten, conditional measurement specimens. Never installed into Rails.
# FACTS models an already-valid invalidatable method/source/schema certificate;
# this file does NOT implement its invalidation machinery or claim support.
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false unless ENV.fetch("BENCH_JIT", "0") == "1"
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "digest"
require_relative "../heap_windows"
require_relative "../jit_stability"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
raise "wrong Rails/JIT" unless Rails.version == "8.1.4" &&
  !!RubyVM::YJIT.enabled? == (ENV.fetch("BENCH_JIT", "0") == "1")
raise "must not load Lowrail" if defined?(Lowrail)

module AllocationsMicro
  FACTS = [true]
  def self.repeat(n, operation)
    n.times { operation.call }
  end

  def self.dom(view, record)
    if FACTS[0] && record.instance_of?(Article)
      id = record.id
      return "article_#{id}" if id.instance_of?(Integer)
    end
    view.dom_id(record)
  end
end

records = {}
checks = []
if ENV.fetch("ALLOC_MICRO_APP") == "blog"
  controller = ArticlesController.new
  request = ActionDispatch::TestRequest.create
  controller.set_request!(request)
  controller.set_response!(ArticlesController.make_response!(request))
  view = controller.view_context
  article = Article.find(1)
  records["dom_id"] = { off: -> { view.dom_id(article) }, on: -> { AllocationsMicro.dom(view, article) } }
  [nil, -17, 9081].each do |id|
    model = Article.new(id: id)
    [true, false].each do |flag|
      AllocationsMicro::FACTS[0] = flag
      raise "DOM differs" unless view.dom_id(model) == AllocationsMicro.dom(view, model)
      checks << "dom/#{id.inspect}/#{flag}"
    end
  end
  AllocationsMicro::FACTS[0] = true

  handler = ActionView::Template.handler_for_extension("erb")
  source = '<%= label_tag "article_title", "Title" %><%= text_field_tag "article[title]", value, id: "article_title" %>'
  template = ->(text, name) {
    ActionView::Template.new(text, "allocations/#{name}", handler, locals: [:value], format: :html)
  }
  original = template.call(source, "original")
  envelope = original.render(view, { value: "LOWRAIL_VALUE_MARKER" }).to_s
  raise "marker not unique" unless envelope.scan("LOWRAIL_VALUE_MARKER").size == 1
  optimized = template.call(envelope.sub("LOWRAIL_VALUE_MARKER", "<%= value %>"), "envelope")
  variant = ->(value) {
    if AllocationsMicro::FACTS[0] && value.instance_of?(String) && value.encoding == Encoding::UTF_8
      optimized.render(view, { value: value })
    else
      original.render(view, { value: value })
    end
  }
  ["plain", "<&\"'雪\n", "", "&amp;", "safe <b>\"".html_safe, nil].each do |value|
    [true, false].each do |flag|
      AllocationsMicro::FACTS[0] = flag
      a, b = original.render(view, { value: value }), variant.call(value)
      raise "form differs: #{value.inspect}" unless a == b && a.class == b.class && a.encoding == b.encoding && a.html_safe? == b.html_safe?
      checks << "form/#{value.class}/#{flag}"
    end
  end
  AllocationsMicro::FACTS[0] = true
  value = '<Current & "live">'
  records["form"] = { off: -> { original.render(view, { value: value }) }, on: -> { variant.call(value) } }
elsif ENV.fetch("ALLOC_MICRO_APP") == "frozen"
  # Keep real loading/reloading and return the same live FrozenRecord object.
  # The fact token must certify an unmodified, unscoped current Scope and its
  # lookup/read/comparison methods; no permanent result cache is introduced.
  scope = CFP.current_scope
  lookup = ->(id) {
    if AllocationsMicro::FACTS[0] && id.instance_of?(String) && CFP.current_scope.equal?(scope) &&
        CFP.index_definitions.empty? && scope.instance_variable_get(:@where_values).empty? &&
        scope.instance_variable_get(:@where_not_values).empty? && scope.instance_variable_get(:@order_values).empty? &&
        scope.instance_variable_get(:@limit).nil? && scope.instance_variable_get(:@offset).nil?
      rows = CFP.load_records
      unless FrozenRecord.enforce_max_records_scan && CFP.max_records_scan && rows.size > CFP.max_records_scan
        next rows.find { |record| id == record["id"] }
      end
    end
    CFP.find_by(id: id)
  }
  ["primary-2026", "primary", "workshops", "absent", nil, ["primary", "workshops"]].each do |id|
    [true, false].each do |flag|
      AllocationsMicro::FACTS[0] = flag
      raise "FrozenRecord identity differs" unless CFP.find_by(id: id).equal?(lookup.call(id))
      checks << "frozen/#{id.inspect}/#{flag}"
    end
  end
  AllocationsMicro::FACTS[0] = true
  id = "primary-2026"
  records["frozen_lookup"] = { off: -> { CFP.find_by(id: id) }, on: -> { lookup.call(id) } }
else
  # Only the tuple-producing iteration changes. All metadata, lazy evaluation,
  # recursion, partial/once/deferred/rescue behavior remains the gem's code.
  klass = InertiaRails::PropsResolver
  file, start = klass.instance_method(:deep_transform_props).source_location
  lines = File.readlines(file)
  finish = (start...lines.size).find { lines[_1].start_with?("    def transform_array(") }
  source = lines[(start - 1)...finish].join
  needle = "      props.each_with_object({}) do |(key, prop), transformed_props|"
  raise "unknown resolver recipe" unless source.include?(needle)
  source = source.sub(needle, <<~RUBY.chomp)
        return super unless AllocationsMicro::FACTS[0] && props.instance_of?(Hash)
        transformed_props = {}
        props.each_pair do |key, prop|
  RUBY
  source = source.sub(/    end\n\s*\z/, "      transformed_props\n    end\n")
  source = source.gsub(/\bBaseProp\b/, "InertiaRails::BaseProp")
  variant = Class.new(klass)
  variant.class_eval(source, "(allocation-props-variant)", 1)
  variant.send(:private, :deep_transform_props)
  evaluator = InertiaRails::PropEvaluator.new(ApplicationController.new)
  props = { auth: { id: 17, name: "雪<&", admin: false }, count: 31, empty: {}, values: [3, nil, false],
    lazy: -> { { odd: 7, even: 12 } }, blank: nil }
  [props, { "auth.name" => "live", "auth.id" => 19 }].each do |input|
    [{}, { component: true, only: ["auth.name", "lazy.odd"] }, { component: true, except: ["auth.id"] }].each do |visit|
      [true, false].each do |flag|
        AllocationsMicro::FACTS[0] = flag
        a = klass.new(input, evaluator: evaluator, visit: visit).resolve
        b = variant.new(input, evaluator: evaluator, visit: visit).resolve
        raise "props differ" unless a == b
        raise "not fresh" if b.equal?(variant.new(input, evaluator: evaluator, visit: visit).resolve)
        checks << "props/#{visit}/#{flag}"
      end
    end
  end
  AllocationsMicro::FACTS[0] = true
  records["props"] = {
    off: -> { klass.new(props, evaluator: evaluator).resolve },
    on: -> { variant.new(props, evaluator: evaluator).resolve }
  }
end

arm = ENV.fetch("ALLOC_MICRO_ARM") == "on" ? :on : :off
operations = records.transform_values { _1.fetch(arm) }
operations.each_value { AllocationsMicro.repeat(5000, _1) }
operation = ->(count, id) { AllocationsMicro.repeat(count, operations.fetch(id)) }
jit_warmup = JitStability.warm { |count| operations.each_key { operation.call(count, _1) } } if RubyVM::YJIT.enabled?
n = Integer(ENV.fetch("BENCH_REQUESTS", "1000"))
windows = HeapWindows.windows(n, operations.keys)
anchors = HeapWindows.run(windows, observe: RubyVM::YJIT.enabled? ? JitStability.method(:snapshot) : nil, &operation)
puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?, windows: windows,
  heap_anchors: anchors, operations: operations.keys.to_h { [_1, { invocations_per_iteration: 1 }] },
  checks: checks, jit_warmup: jit_warmup, specimen_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  seam_sha256: %w[heap_windows.rb jit_stability.rb request_pairs.rb].to_h { [_1, Digest::SHA256.file(File.expand_path("../#{_1}", __dir__)).hexdigest] })}"
