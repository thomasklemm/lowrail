# frozen_string_literal: true

# Finite pre-implementation price. Not a pass, installer or endpoint. Captures
# real blog links, conservatively prices link_to with an already resolved URL,
# and measures the proposed residual predicate separately from original work.
if ENV["SEALED_HELPER_WORKER"]
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

  module SealedHelperCost
    INSTANCE = Kernel.instance_method(:instance_of?)
    SINGLETON_METHODS = Kernel.instance_method(:singleton_methods)
    IDENTITY = BasicObject.instance_method(:equal?)
    EPOCH = [0]
    TABLE = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
    TABLE_COPY = TABLE.to_h.transform_values { _1.dup.freeze }.freeze
    DEFAULT = TABLE.default
    DEFAULT_PROC = TABLE.default_proc
    BUILDER = ActionView::Helpers::TagHelper::TagBuilder
    TYPES = ActionView::Helpers::TagHelper::TAG_TYPES
    raise "non-stock tag tables" unless TYPES.frozen? && TYPES["class"].nil? && TYPES["href"].nil? &&
      TABLE["a"] == "" && DEFAULT.nil? && DEFAULT_PROC&.source_location ==
        [Gem.loaded_specs.fetch("actionview").full_gem_path + "/lib/action_view/helpers/tag_helper.rb", 42]

    def self.string?(value)
      INSTANCE.bind_call(value, String) && SINGLETON_METHODS.bind_call(value).empty? &&
        value.encoding == Encoding::UTF_8 && value.valid_encoding?
    end

    def self.check(view, name, url)
      # The epoch is charged at EVERY hit here, a conservative cost relative
      # to one request-entry read. No method-identity/visibility lookup remains.
      EPOCH[0] == 0 && string?(name) && string?(url) &&
        INSTANCE.bind_call(builder = view.send(:tag_builder), BUILDER) && SINGLETON_METHODS.bind_call(builder).empty? &&
        TABLE == TABLE_COPY && IDENTITY.bind_call(TABLE.default, DEFAULT) &&
        IDENTITY.bind_call(TABLE.default_proc, DEFAULT_PROC)
    end
  end

  links = []
  trace = TracePoint.new(:call) do |event|
    next unless event.method_id == :link_to && event.defined_class == ActionView::Helpers::UrlHelper
    context = event.binding
    next if context.local_variable_get(:block)
    options = context.local_variable_get(:html_options)
    next unless options.instance_of?(Hash) && options.keys == [:class] && options[:class].instance_of?(String)
    links << [event.self, context.local_variable_get(:name), context.local_variable_get(:options), options]
  end
  path = ARGV.fetch(0).split(":", 2).last
  trace.enable do
    response = Rack::MockRequest.new(Rails.application).get(path, "HTTP_HOST" => "localhost", "HTTPS" => "on")
    raise "request failed: #{response.status}" unless response.status == 200
  end
  raise "no links" if links.empty?
  require File.expand_path("../../gem/lib/lowrail/templates", __dir__)
  require File.expand_path("../../gem/lib/lowrail/routes", __dir__)
  operations = links.map do |view, name, target, options|
    url = view.url_for(target)
    raise "unsupported observed inputs" unless SealedHelperCost.check(view, name, url)
    # Only the build-literal class attribute is precomputed. URL/content are
    # live and escaped once. Mutable tables are checked, never silently folded.
    prefix = "<a class=\"#{Lowrail::Html.attr(options.fetch(:class))}\" href=\""
    original = -> { view.link_to(name, url, options) }
    checks = -> { SealedHelperCost.check(view, name, url) }
    residue = -> { "#{prefix}#{Lowrail::Html.attr(url)}\">#{Lowrail::Html.content(name)}</a>".html_safe }
    candidate = -> { checks.call ? residue.call : original.call }
    expected = original.call
    actual = candidate.call
    raise "bytes/safety/encoding differ" unless expected == actual && expected.html_safe? == actual.html_safe? && expected.encoding == actual.encoding
    {original: original, checks: checks, residue: residue, candidate: candidate}
  end
  view = links.first.first
  article = Article.find(1)
  routes = Rails.application.routes
  original_route = -> { view.edit_article_path(article) }
  route_checks = -> {
    SealedHelperCost::EPOCH[0] == 0 && SealedHelperCost::INSTANCE.bind_call(article, Article) &&
      SealedHelperCost::SINGLETON_METHODS.bind_call(article).empty? && article.id.instance_of?(Integer) &&
      view._routes.equal?(routes) && view.send(:optimize_routes_generation?)
  }
  # url_options, defaults merge, conversion, segment escaping, dynamic script
  # name and URL completion stay live, in Rails' order. This price is only for
  # stock scalar-id Article#to_param; arbitrary conversions are not certified.
  route_residue = -> {
    options = view.url_options.merge(routes.named_routes.get(:edit_article).defaults)
    param = article.to_param
    Lowrail::Routes.finish(+"/articles/" << Lowrail::Routes.seg(param) << "/edit", options, view, false)
  }
  route_candidate = -> { route_checks.call ? route_residue.call : original_route.call }
  expected, actual = original_route.call, route_candidate.call
  raise "route bytes/encoding differ" unless expected == actual && expected.encoding == actual.encoding
  # Boundary probes are outside all timed windows. Failure refuses the study;
  # these do not establish purity or closure for arbitrary application code.
  bad = "label".dup
  def bad.html_safe? = true
  raise "instance override accepted" if SealedHelperCost.string?(bad)
  raise "encoding accepted" if SealedHelperCost.string?("label".encode(Encoding::UTF_16LE))
  raise "subclass accepted" if SealedHelperCost.string?("label".html_safe)
  table = SealedHelperCost::TABLE
  table["a"] = "changed"
  raise "table mutation accepted" if SealedHelperCost.check(view, "label", "/")
  table.delete("a")
  original_default = table.default_proc
  table.default_proc = ->(*) { "changed" }
  raise "default mutation accepted" if SealedHelperCost.check(view, "label", "/")
  table.default_proc = original_default
  original_builder = view.instance_variable_get(:@tag_builder)
  view.instance_variable_set(:@tag_builder, Object.new)
  raise "foreign builder accepted" if SealedHelperCost.check(view, "label", "/")
  view.instance_variable_set(:@tag_builder, original_builder)
  article.define_singleton_method(:to_param) { "changed" }
  raise "instance conversion override accepted" if route_checks.call
  article.singleton_class.remove_method(:to_param)
  raise "restoration failed" unless SealedHelperCost.check(view, "label", "/") && route_checks.call
  groups = {"link" => operations, "route" => [{original: original_route, checks: route_checks,
    residue: route_residue, candidate: route_candidate}]}
  calls = groups.transform_values { |rows| rows.map { _1.fetch(ENV.fetch("SEALED_HELPER_WORKER").to_sym) } }
  200.times { calls.each_value { _1.each(&:call) } }
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), calls.keys)
  anchors = HeapWindows.run(windows) { |n, key| n.times { calls.fetch(key).each(&:call) } }
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
    windows: windows, heap_anchors: anchors, ar_installed: 0, links: links.size,
    operations: groups.transform_values { {invocations_per_iteration: _1.size} })}"
  exit
end

require_relative "../request_pairs"
app, out = ARGV.map { File.expand_path(_1) }
abort "usage: sealed_helpers.rb APP NEW_OUTDIR [GET:/articles|GET:/articles/1]" unless app && out
route = ARGV.fetch(2, "GET:/articles/1")
raise "output directory must be new" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0"}
environments = %w[off_a off_b checks residue candidate].to_h do |arm|
  [arm, env.merge("SEALED_HELPER_WORKER" => arm.start_with?("off") ? "original" : arm)]
end
sources = [__FILE__, File.expand_path("../heap_windows.rb", __dir__), File.expand_path("../request_pairs.rb", __dir__),
  *%w[templates routes].map { File.expand_path("../../gem/lib/lowrail/#{_1}.rb", __dir__) }].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources}
accepted = RequestPairs.heap_instructions(environments, app, out, route, metadata,
  worker: File.expand_path(__FILE__), requests: 200)
raise "study source changed" unless sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
raw = JSON.parse(File.read(File.join(out, "samples.json")))
raise "link count changed" unless raw.fetch("workers").values.map { _1.fetch("links") }.uniq.size == 1
prices = %w[link route].to_h do |group|
  [group, %w[instructions_total instructions_no_gc].to_h do |metric|
    value = ->(row, arm) { row.fetch(arm).fetch("operations").fetch(group).fetch(metric) }
    [metric, %w[off_a checks residue candidate].to_h do |arm|
      [arm, RequestPairs.estimate(raw.fetch("samples").map { value.call(_1, arm) }, seed: 41231)]
    end.merge("candidate_minus_original" => RequestPairs.estimate(raw.fetch("samples").map {
      value.call(_1, "candidate") - value.call(_1, "off_a") }, seed: 41231))]
  end]
end
File.write(File.join(out, "sealed-budget.json"), JSON.pretty_generate(accepted: accepted, prices: prices,
  caveat: "Finite blog-shaped pre-implementation price, not deployed code or a request saving. Per-hit epoch read is conservatively charged."))
puts JSON.pretty_generate(prices)
exit(accepted ? 0 : 2)
