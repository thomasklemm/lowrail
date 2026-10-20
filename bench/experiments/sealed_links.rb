# frozen_string_literal: true

# Revised, literal-name-only link price. Not installed in Lowrail. URL selection,
# option conversion, input escaping and PRE_CONTENT_STRINGS consumption stay live.
if ENV["SEALED_LINK_WORKER"]
  if ENV["SEALED_LINK_PROVENANCE"]
    require_relative "sealed_provenance"
    unless ENV["SEALED_LINK_WORKER"] == "original"
      ENV["LOWRAIL"] = "1"
      factory_path, delivery = SealedBuilderCost.install
    end
  end
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
  require File.expand_path("../../gem/lib/lowrail/templates", __dir__)
  delivery&.disable
  raise "factory delivery absent" if delivery && SealedBuilderCost::SERVED != [factory_path]
  SealedBuilderCost::ACTIVE[0] = true if ENV["SEALED_LINK_PROVENANCE"]

  module SealedLinkCost
    PROVENANCE = !!ENV["SEALED_LINK_PROVENANCE"]
    SINGLETON = Kernel.instance_method(:singleton_class)
    METHOD = Module.instance_method(:instance_method)
    PUBLIC = Module.instance_method(:public_method_defined?)
    PRIVATE = Module.instance_method(:private_method_defined?)
    EQUAL = UnboundMethod.instance_method(:==)
    ENCODING = String.instance_method(:encoding)
    VALID = String.instance_method(:valid_encoding?)
    BUILDER = ActionView::Helpers::TagHelper::TagBuilder
    CONTENT = BUILDER.instance_method(:content_tag_string)
    OPTIONS = BUILDER.instance_method(:tag_options)
    OPTION = BUILDER.instance_method(:tag_option)
    EPOCH = [0]
    Thread.current[:lowrail_sealed_price] = true

    def self.check(view, url, html, css)
      # Charge an epoch read at every hit as well as request-local permission:
      # conservative versus reading the epoch only at request entry.
      return false unless Ractor.current.equal?(Ractor.main) &&
        Thread.current[:lowrail_sealed_price] && EPOCH[0] == 0 &&
        String === url && ENCODING.bind_call(url) == Encoding::UTF_8 && VALID.bind_call(url) &&
        html.size == 2 && html["class"] == css && html["href"].equal?(url)
      builder = view.send(:tag_builder)
      return SealedBuilderCost::BUILDERS.key?(builder) if PROVENANCE
      return false unless BUILDER === builder
      holder = SINGLETON.bind_call(builder)
      # Current UnboundMethods allocate on stock Ruby; these are NOT called
      # allocation-free. Check the private tag_option as well as public methods.
      EQUAL.bind_call(METHOD.bind_call(holder, :content_tag_string), CONTENT) &&
        EQUAL.bind_call(METHOD.bind_call(holder, :tag_options), OPTIONS) &&
        EQUAL.bind_call(METHOD.bind_call(holder, :tag_option), OPTION) &&
        PUBLIC.bind_call(holder, :content_tag_string) && PUBLIC.bind_call(holder, :tag_options) &&
        PRIVATE.bind_call(holder, :tag_option)
    end
  end

  links = []
  trace = TracePoint.new(:call) do |event|
    next unless event.method_id == :link_to && event.defined_class == ActionView::Helpers::UrlHelper
    context = event.binding
    next if context.local_variable_get(:block)
    options = context.local_variable_get(:html_options)
    name = context.local_variable_get(:name)
    next unless options.instance_of?(Hash) && options.keys == [:class] && options[:class].instance_of?(String)
    # The two show names are source literals; this is not a claim that the
    # generated article.title expression is eligible on index.
    next unless ["Edit this article", "Back to articles"].include?(name)
    links << [event.self, name, context.local_variable_get(:options), options]
  end
  trace.enable do
    response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
    raise "request failed: #{response.status}" unless response.status == 200
  end
  raise "expected two literal show links" unless links.size == 2
  operations = links.map do |view, name, target, options|
    # Boot certificate: only the literal class/href entries are folded.
    types = ActionView::Helpers::TagHelper::TAG_TYPES
    raise "unsupported TAG_TYPES" unless types.frozen? && types["class"].nil? && types["href"].nil?
    url = view.url_for(target)
    css = options.fetch(:class).dup.freeze
    static_options = {class: css}.freeze
    html = view.send(:convert_options_to_data_attributes, url, static_options)
    html["href"] = url
    prefix = "<a class=\"#{Lowrail::Html.attr(css)}\" href=\"".freeze
    suffix = "#{Lowrail::Html.content(name)}</a>".freeze
    render = ->(value) { "#{prefix}#{Lowrail::Html.attr(value)}\">#{ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS['a']}#{suffix}".html_safe }
    original = -> { view.link_to(name, url, {class: css}) }
    checks = -> { SealedLinkCost.check(view, url, html, css) }
    if SealedLinkCost::PROVENANCE && ENV["SEALED_LINK_WORKER"] == "original"
      # Off workers leave the factory untouched. Certify the pristine captured
      # holder solely for untimed boundary probes; timed off calls never read
      # this map, and every iteration constructs its own stock builder.
      SealedBuilderCost::BUILDERS[view.send(:tag_builder)] = true
    end
    prelude = -> {
      converted = view.send(:convert_options_to_data_attributes, url, static_options)
      selected = view.send(:url_target, name, url)
      converted["href"] ||= selected
      nil
    }
    residue = -> { render.call(url) }
    candidate = -> {
      converted = view.send(:convert_options_to_data_attributes, url, static_options)
      selected = view.send(:url_target, name, url)
      converted["href"] ||= selected
      if SealedLinkCost.check(view, selected, converted, css)
        render.call(selected)
      else
        # Callee-local continuation: never repeat URL selection/conversion.
        view.content_tag("a", name, converted)
      end
    }
    expected = original.call
    actual = candidate.call
    raise "bytes/safety/encoding differ" unless expected == actual && expected.html_safe? == actual.html_safe? && expected.encoding == actual.encoding
    builder = view.send(:tag_builder)
    # Private singleton overrides and singleton prepend both escaped v1's
    # singleton_methods scan. Every refusal is checked before timed windows.
    if SealedLinkCost::PROVENANCE
      # A factory-issued builder is structurally immutable under SEAL001.
      # Test a preexisting foreign holder instead, including reinitialization:
      # initialize alone must NEVER confer constructor provenance.
      builder = SealedLinkCost::BUILDER.new(view)
      original_builder = view.instance_variable_get(:@tag_builder)
      view.instance_variable_set(:@tag_builder, builder)
    end
    builder.define_singleton_method(:tag_option) { |*| "changed" }
    builder.singleton_class.send(:private, :tag_option)
    raise "private override accepted" if checks.call
    raise "fallback differs" unless candidate.call == original.call
    builder.singleton_class.remove_method(:tag_option)
    builder.singleton_class.send(:private, :content_tag_string)
    raise "visibility accepted" if checks.call
    builder.singleton_class.send(:remove_method, :content_tag_string)
    if SealedLinkCost::PROVENANCE
      builder.send(:initialize, view)
      raise "reinitialized foreign builder accepted" if checks.call
      view.instance_variable_set(:@tag_builder, original_builder)
    end
    original_builder = view.instance_variable_get(:@tag_builder)
    substitute = SealedLinkCost::BUILDER.new(view)
    extension = Module.new { private; def tag_option(*) = "changed" }
    substitute.singleton_class.prepend(extension)
    view.instance_variable_set(:@tag_builder, substitute)
    raise "singleton prepend accepted" if checks.call
    raise "prepend fallback differs" unless candidate.call == original.call
    view.instance_variable_set(:@tag_builder, original_builder)
    table = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
    old = table.default_proc
    table["a"] = "before content"
    raise "table entry differs" unless candidate.call == original.call
    table.delete("a")
    table.default_proc = ->(*) { "new default" }
    raise "table default differs" unless candidate.call == original.call
    table.default_proc = old
    original_url = url
    ["/safe<&\"".html_safe, "/latin".b, "/wide".encode(Encoding::UTF_16LE), "\xFF".dup.force_encoding(Encoding::UTF_8)].each do |value|
      url = value
      html["href"] = value
      outcomes = [original, candidate].map do |operation|
        result = operation.call
        [:value, result.b, result.encoding, result.html_safe?]
      rescue StandardError => error
        [:error, error.class]
      end
      raise "input boundary differs" unless outcomes[0] == outcomes[1]
    end
    url = +"/coercion"
    coercions = 0
    url.define_singleton_method(:to_s) { coercions += 1; "/live&value" }
    expected = original.call
    raise "original coercion count" unless coercions == 1
    coercions = 0
    raise "coercion differs" unless candidate.call == expected && coercions == 1
    url = original_url
    html["href"] = url
    raise "restoration failed" unless checks.call && candidate.call == original.call
    {original: original, checks: checks, prelude: prelude, residue: residue, candidate: candidate}
  end
  calls = operations.map { _1.fetch(ENV.fetch("SEALED_LINK_WORKER").to_sym) }
  views = links.map(&:first).uniq
  iterate = -> {
    views.each { _1.instance_variable_set(:@tag_builder, nil) } if SealedLinkCost::PROVENANCE
    calls.each(&:call)
  }
  200.times { iterate.call }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), ["link"])
  anchors = HeapWindows.run(windows) do |n, _|
    n.times { iterate.call }
    # Symmetric N=0/N=200 collection charges weak-key cleanup to the slope;
    # total includes it, no_gc excludes it. No cleanup hidden in warmup.
    GC.start if SealedLinkCost::PROVENANCE
  end
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
    windows: windows, heap_anchors: anchors, ar_installed: 0, links: links.size,
    provenance: SealedLinkCost::PROVENANCE, fresh_builder_contexts: views.size,
    operations: {link: {invocations_per_iteration: links.size}})}"
  exit
end

require_relative "../request_pairs"
app, out = ARGV.first(2).map { File.expand_path(_1) }
abort "usage: sealed_links.rb APP NEW_OUTDIR [--provenance]" unless app && out
raise "unknown price mode" unless ARGV.size == 2 || ARGV[2..] == ["--provenance"]
provenance = ARGV[2] == "--provenance"
raise "output directory must be new" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0"}
environments = %w[off_a off_b checks prelude residue candidate].to_h do |arm|
  [arm, env.merge("SEALED_LINK_WORKER" => arm.start_with?("off") ? "original" : arm,
    "SEALED_LINK_PROVENANCE" => provenance ? "1" : nil)]
end
sources = [__FILE__, File.expand_path("../heap_windows.rb", __dir__), File.expand_path("../request_pairs.rb", __dir__),
  File.expand_path("sealed_provenance.rb", __dir__),
  *Dir[File.expand_path("../../gem/lib/**/*.rb", __dir__)]].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources, provenance: provenance}
accepted = RequestPairs.heap_instructions(environments, app, out, "GET:/articles/1", metadata,
  worker: File.expand_path(__FILE__), requests: 200)
raise "study source changed" unless sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
exit(accepted ? 0 : 2)
