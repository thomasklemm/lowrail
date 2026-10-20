# frozen_string_literal: true

# Cost gate only, NOT an endpoint installer or a complete certificate. Capture
# the two real show-page links, then price an optimistic subset of the checks
# required by caller-side expansion. No template/controller/route is replaced.
if ENV["ENDPOINT_SECTION_WORKER"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json"
  require_relative "../heap_windows"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil

  module SectionCost
    HOLDER = Kernel.instance_method(:singleton_class)
    METHOD = Module.instance_method(:instance_method)
    PUBLIC_METHOD = Module.instance_method(:public_instance_method)
    PUBLIC = Module.instance_method(:public_method_defined?)
    PRIVATE = Module.instance_method(:private_method_defined?)
    EQUAL = UnboundMethod.instance_method(:==)

    def self.condition(holder, name, index, visibility, combined: false)
      getter = combined && visibility == "PUBLIC" ? "PUBLIC_METHOD" : "METHOD"
      identity = "::SectionCost::EQUAL.bind_call(::SectionCost::#{getter}.bind_call(#{holder}, #{name.inspect}), facts[#{index}])"
      getter == "PUBLIC_METHOD" ? identity : "#{identity} && ::SectionCost::#{visibility}.bind_call(#{holder}, #{name.inspect})"
    end
  end

  links = []
  trace = TracePoint.new(:call) do |event|
    next unless event.method_id == :link_to && event.defined_class == ActionView::Helpers::UrlHelper
    context = event.binding
    name = context.local_variable_get(:name)
    next unless ["Edit this article", "Back to articles"].include?(name)
    raise "unexpected block" if context.local_variable_get(:block)
    links << [event.self, name, context.local_variable_get(:options), context.local_variable_get(:html_options)]
  end
  trace.enable do
    response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
    raise "show failed: #{response.status}" unless response.status == 200
  end
  raise "expected the two actual show links" unless links.map { _1[1] } == ["Edit this article", "Back to articles"]

  operations = links.map do |view, name, url, options|
    raise "unexpected shape" unless String === name && String === url && Hash === options && options.keys == [:class]
    context = view.instance_eval { binding }
    holder = SectionCost::HOLDER.bind_call(view)
    builder_holder = SectionCost::HOLDER.bind_call(view.send(:tag_builder))
    facts = []
    checks = []
    combined_checks = []
    # This omits remote-option helpers, Hash/String/escaping primitives, value
    # shape checks and repeated checks after callbacks: an optimistic floor,
    # never a closure or permission to execute an accelerated source arm.
    [
      ["holder", holder, :link_to],
      ["holder", holder, :convert_options_to_data_attributes],
      ["holder", holder, :url_target],
      ["holder", holder, :url_for],
      ["holder", holder, :content_tag],
      ["holder", holder, :ensure_valid_html5_tag_name],
      ["holder", holder, :tag_builder],
      ["builder_holder", builder_holder, :content_tag_string],
      ["builder_holder", builder_holder, :tag_options],
      ["builder_holder", builder_holder, :tag_option]
    ].each do |expression, object, method|
      visibility = SectionCost::PUBLIC.bind_call(object, method) ? "PUBLIC" : "PRIVATE"
      facts << SectionCost::METHOD.bind_call(object, method)
      checks << SectionCost.condition(expression, method, facts.size - 1, visibility)
      combined_checks << SectionCost.condition(expression, method, facts.size - 1, visibility, combined: true)
    end
    {name: name, url: url, options: options, holder: holder, builder_holder: builder_holder, facts: facts}.each do |key, value|
      context.local_variable_set(key, value)
    end
    original = context.eval("-> { link_to(name, url, options) }")
    thin_source = <<~RUBY
      -> {
        if #{checks.first}
          target = url || {}
          attributes = convert_options_to_data_attributes(target, options)
          href = url_target(name, target)
          attributes["href"] ||= href
          content_tag("a", name || href, attributes)
        else
          link_to(name, url, options)
        end
      }
    RUBY
    thin = context.eval(thin_source)
    thin_combined = context.eval(thin_source.sub(checks.first, combined_checks.first))
    check_only = context.eval("-> { #{checks.join(' && ')} }")
    check_combined = context.eval("-> { #{combined_checks.join(' && ')} }")
    expected = original.call
    [thin, thin_combined].each do |operation|
      actual = operation.call
      raise "thin stock specimen differs" unless expected == actual && expected.html_safe? == actual.html_safe? && expected.encoding == actual.encoding
    end
    raise "check floor failed" unless check_only.call && check_combined.call
    {original: original, thin: thin, thin_combined: thin_combined, check_only: check_only, check_combined: check_combined}
  end
  arm = ENV.fetch("ENDPOINT_SECTION_WORKER").to_sym
  calls = operations.map { _1.fetch(arm) }
  200.times { calls.each(&:call) }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
  # c9d2397 operation protocol: keep captured context; only request workers
  # execute a settling request. No request is replayed by an endpoint.
  anchors = HeapWindows.run(windows) { |n| n.times { calls.each(&:call) } }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
    windows: windows, heap_anchors: anchors, ar_installed: 0, links: links.size, checks_per_link: 10)}"
  exit
end

require_relative "../request_pairs"
app, out = ARGV.map { File.expand_path(_1) }
abort "usage: endpoint_sections.rb APP NEW_OUTDIR" unless app && out
raise "output directory must be new" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0"}
environments = %w[off_a off_b thin thin_combined check_only check_combined].to_h do |arm|
  [arm, env.merge("ENDPOINT_SECTION_WORKER" => arm.start_with?("off") ? "original" : arm)]
end
metadata = {seed: 41231, rounds: 6, workers: {},
  sources: [__FILE__, File.expand_path("../heap_windows.rb", __dir__), File.expand_path("../request_pairs.rb", __dir__)].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}
accepted = RequestPairs.heap_instructions(environments, app, out, "GET:/articles/1", metadata,
  worker: File.expand_path(__FILE__), requests: 200)
raise "study source changed" unless metadata.fetch(:sources).all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
raw = JSON.parse(File.read(File.join(out, "samples.json")))
raise "capture shape changed" unless raw.fetch("workers").values.all? { _1.fetch("links") == 2 && _1.fetch("checks_per_link") == 10 }
prices = %w[instructions_total instructions_no_gc].to_h do |metric|
  rows = raw.fetch("samples")
  [metric, {
    original_two_links: RequestPairs.estimate(rows.map { _1.fetch("off_a").fetch(metric) }, seed: 41231),
    thin_increment: RequestPairs.estimate(rows.map { _1.fetch("thin").fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231),
    thin_combined_increment: RequestPairs.estimate(rows.map { _1.fetch("thin_combined").fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231),
    checks_minus_entire_links: RequestPairs.estimate(rows.map { _1.fetch("check_only").fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231),
    check_only_two_links: RequestPairs.estimate(rows.map { _1.fetch("check_only").fetch(metric) }, seed: 41231),
    combined_checks_minus_entire_links: RequestPairs.estimate(rows.map { _1.fetch("check_combined").fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231),
    check_combined_two_links: RequestPairs.estimate(rows.map { _1.fetch("check_combined").fetch(metric) }, seed: 41231)
  }]
end
File.write(File.join(out, "section-budget.json"), JSON.pretty_generate({accepted: accepted, prices: prices,
  caveat: "Optimistic caller-side checks, not a complete certificate, generated pilot or request performance result."}))
puts JSON.pretty_generate(prices)
exit(accepted ? 0 : 2)
