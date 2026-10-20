# frozen_string_literal: true

# Design/cost experiment only. Never loaded by the gem or a real endpoint.
require "json"
require "digest"
require "tmpdir"
require "fileutils"
require "rbconfig"
require "open3"

module BodyCost
  LIB = File.expand_path("../../gem/lib", __dir__)
  METHOD = Module.instance_method(:instance_method)
  PUBLIC_METHOD = Module.instance_method(:public_instance_method)
  PUBLIC = Module.instance_method(:public_method_defined?)
  PRIVATE = Module.instance_method(:private_method_defined?)
  EQUAL = UnboundMethod.instance_method(:==)
  SERVED = []

  # Use the actual Compiler/Manifest/Loader, not eval/class_eval replacement.
  # This local experimental unit has no runtime pass and authorizes no fast arm.
  def self.install(path, text, dir, boot: false)
    $LOAD_PATH.unshift(LIB)
    require "lowrail/compiler"
    lowered = File.join(dir, "lowered.rb")
    File.write(lowered, text)
    input = {"out" => dir,
      "files" => [{"path" => path, "lowered" => lowered}],
      "units" => [{"id" => 0, "kind" => "file", "pass" => "experiment/body_cost",
        "file" => path, "method" => "body_cost", "facts" => []}]}
    if boot
      input["rails_env"] = "production"
      units = File.join(dir, "units.json")
      File.write(units, JSON.generate(input))
      stdout, stderr, status = Open3.capture3({"LOWRAIL" => "0"}, RbConfig.ruby,
        File.join(LIB, "../exe/lowrail-compile"), units)
      raise "compile boot failed: #{stderr}" unless status.success?
      raise "file not compiled: #{stderr}" unless JSON.parse(File.read(File.join(dir, "manifest.json"))).fetch("files").key?(path)
    else
      Lowrail::Compiler.compile(input)
    end
    raise "manifest refused" unless Lowrail.setup(root: Dir.pwd, dir: dir)
    trace = TracePoint.new(:return) do |event|
      if event.method_id == :serve && event.self.equal?(Lowrail::Loader) && event.return_value
        SERVED << event.binding.local_variable_get(:path)
      end
    end
    trace.enable
    trace
  end

  def self.condition(holder, name, index, public:)
    getter = public ? "PUBLIC_METHOD" : "METHOD"
    check = "::BodyCost::EQUAL.bind_call(::BodyCost::#{getter}.bind_call(::BodyCost::#{holder}, #{name.inspect}), ::BodyCost::FACTS[#{index}])"
    public ? check : "#{check} && ::BodyCost::PRIVATE.bind_call(::BodyCost::#{holder}, #{name.inspect})"
  end

  # Ten facts, not a closure: the outer link_to is entered normally. The
  # previously omitted remote predicate replaces its caller-side identity.
  FACT_NAMES = [
    ["VIEW", :convert_options_to_data_attributes, false],
    ["VIEW", :link_to_remote_options?, false],
    ["VIEW", :url_target, false],
    ["VIEW", :url_for, true],
    ["VIEW", :content_tag, true],
    ["VIEW", :ensure_valid_html5_tag_name, false],
    ["VIEW", :tag_builder, false],
    ["BUILDER", :content_tag_string, true],
    ["BUILDER", :tag_options, true],
    ["BUILDER", :tag_option, false]
  ].freeze

  def self.guard
    FACT_NAMES.each_with_index.map { |(holder, name, public), i| condition(holder, name, i, public: public) }.join(" && ")
  end
end

if ENV["ENDPOINT_BODY_CONTRACT"]
  path = File.expand_path(ARGV.fetch(0))
  arm = ENV.fetch("ENDPOINT_BODY_CONTRACT")
  trace = []
  observer = TracePoint.new(:line, :call, :c_call) do |event|
    trace << [event.event, event.lineno, event.method_id] if event.path == path
  end
  Dir.mktmpdir("body-contract") do |dir|
    source = File.read(path)
    edited = source.sub("def value(x = 2, *rest, flag: 3, **kw, &block)",
      "def value(x = 2, *rest, flag: 3, **kw, &block); ::BodyFixture::TOKEN.equal?(::BodyFixture::TOKEN)")
    raise "fixture edit missed" if source == edited
    delivery = BodyCost.install(path, arm == "edited" ? edited : source, dir) unless arm == "off"
    observer.enable { require path }
    delivery&.disable
    raise "delivery absent" if arm != "off" && BodyCost::SERVED != [path]
    load_stack = $body_load_stack
    load_frame = $body_load_frame
    object = BodyFixture::Child.new
    method = object.method(:value)
    unbound = BodyFixture::Child.instance_method(:value)
    frames = nil
    begin
      object.value(:raise)
    rescue => error
      frames = error.backtrace_locations.select { _1.absolute_path == path }.map { [_1.lineno, _1.label, _1.base_label] }
    end
    call_trace = []
    observer.enable { object.value { |x| call_trace << x; x + 1 } }
    metadata = {owner: method.owner.name, name: method.name, original_name: method.original_name,
      source_location: method.source_location, parameters: method.parameters, arity: method.arity,
      super_owner: method.super_method.owner.name,
      repeated_bound_equal: method == object.method(:value), repeated_unbound_equal: unbound == BodyFixture::Child.instance_method(:value),
      alias_equal: method == object.method(:alias_value), bound_unbound_equal: method.unbind == unbound,
      rebound_equal: unbound.bind(object) == method, private: BodyFixture::Child.private_method_defined?(:hidden),
      result: object.value(5, 7, flag: 11, more: 13) { _1 * 2 }, block_values: call_trace, exception_frames: frames}
    # Suppressed hooks are irrelevant to normal VM dispatch. Active frame,
    # alias and saved handles retain the old body; the next send sees new def.
    $body_entry = -> do
      $body_entry = nil
      BodyFixture::Child.class_eval { def value(...) = :changed }
    end
    mutation = {active: object.value, next: object.value, alias: object.alias_value, saved: method.call, rebound: unbound.bind_call(object)}
    fresh = BodyFixture::Child.instance_method(:value)
    load path
    reload = {old_handle_survives: unbound.bind_call(object),
      old_equal_reloaded: unbound == BodyFixture::Child.instance_method(:value),
      replaced_equal_reloaded: fresh == BodyFixture::Child.instance_method(:value)}
    puts JSON.generate(metadata: metadata, mutation: mutation, reload: reload,
      trace: trace, load_stack: load_stack, load_frame: load_frame,
      iseq_sha256: Digest::SHA256.hexdigest(RubyVM::InstructionSequence.of(method).to_binary),
      served: BodyCost::SERVED.size)
  end
  exit
end

if ENV["ENDPOINT_BODY_WORKER"]
  arm = ENV.fetch("ENDPOINT_BODY_WORKER")
  require File.expand_path("config/boot", Dir.pwd)
  path = Gem::Specification.find_by_name("actionview").full_gem_path + "/lib/action_view/helpers/url_helper.rb"
  raise "UrlHelper already loaded" if $LOADED_FEATURES.include?(path)
  Dir.mktmpdir("body-cost") do |dir|
    source = File.read(path)
    signature = "def link_to(name = nil, options = nil, html_options = nil, &block)"
    # Executed checks, then UNCHANGED original body, regardless of their result.
    # This is only guard pricing, not an accelerated or exact full certificate.
    edited = source.sub(signature, "#{signature}; if defined?(::BodyCost::FACTS); #{BodyCost.guard}; end")
    raise "stock signature changed" if edited == source
    delivery = BodyCost.install(path, arm == "guards" ? edited : source, dir, boot: true) unless arm == "off"
    require File.expand_path("config/application", Dir.pwd)
    Rails.application.config.yjit = false
    require File.expand_path("config/environment", Dir.pwd)
    Rails.application.eager_load!
    delivery&.disable
    raise "delivery absent" if arm != "off" && BodyCost::SERVED != [path]
    body = RubyVM::InstructionSequence.of(ActionView::Helpers::UrlHelper.instance_method(:link_to))
    raise "wrong method body" unless body.disasm.include?("BodyCost") == (arm == "guards")
    require "rack/mock"
    require_relative "../heap_windows"
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    Rails.logger.level = :error
    ActiveRecord::Base.logger = nil
    links = []
    capture = TracePoint.new(:call) do |event|
      next unless event.method_id == :link_to && event.defined_class == ActionView::Helpers::UrlHelper
      context = event.binding
      name = context.local_variable_get(:name)
      next unless ["Edit this article", "Back to articles"].include?(name)
      raise "unexpected block" if context.local_variable_get(:block)
      links << [event.self, name, context.local_variable_get(:options), context.local_variable_get(:html_options)]
    end
    capture.enable do
      response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
      raise "show failed: #{response.status}" unless response.status == 200
    end
    raise "expected two show links" unless links.map { _1[1] } == ["Edit this article", "Back to articles"]
    raise "different views" unless links[0][0].equal?(links[1][0])
    view = links[0][0]
    BodyCost.const_set(:VIEW, Kernel.instance_method(:singleton_class).bind_call(view))
    BodyCost.const_set(:BUILDER, Kernel.instance_method(:singleton_class).bind_call(view.send(:tag_builder)))
    BodyCost.const_set(:FACTS, BodyCost::FACT_NAMES.map { |holder, name, _| BodyCost::METHOD.bind_call(BodyCost.const_get(holder), name) })
    raise "floor fact false" unless BodyCost.module_eval(BodyCost.guard)
    calls = links.map do |receiver, name, url, options|
      raise "unexpected shape" unless String === name && String === url && Hash === options && options.keys == [:class]
      -> { receiver.link_to(name, url, options) }
    end
    results = calls.map { |operation| value = operation.call; [value, value.encoding.name, value.html_safe?] }
    200.times { calls.each(&:call) }
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    anchors = HeapWindows.run(windows) { |n| n.times { calls.each(&:call) } }
    puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
      windows: windows, heap_anchors: anchors, ar_installed: 0, links: links.size, results: results,
      facts_per_link: BodyCost::FACT_NAMES.size, served: BodyCost::SERVED.size,
      source_sha256: Digest::SHA256.hexdigest(source), iseq_sha256: Digest::SHA256.hexdigest(body.to_binary))}"
  end
  exit
end

require_relative "../request_pairs"
app, out = ARGV.first(2).map { File.expand_path(_1) }
abort "usage: endpoint_bodies.rb APP NEW_OUTDIR [contract-only]" unless app && out
raise "output directory must be new" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "RUBYOPT" => nil,
  "LOWRAIL_UNITS" => nil, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "BENCH_JIT" => "0"}
fixture = File.join(out, "fixture.rb")
File.write(fixture, <<~'RUBY')
  module BodyFixture
    TOKEN = Object.new unless const_defined?(:TOKEN, false)
    class Base
      def value(x) = x + 17
    end
    class Child < Base
      def value(x = 2, *rest, flag: 3, **kw, &block)
        $body_entry.call if $body_entry
        raise "body fixture" if x == :raise
        x = block.call(x) if block
        [super(x), rest, flag, kw]
      end
      alias alias_value value
      private
      def hidden = :hidden
    end
  end
  $body_load_stack = caller_locations.map { [_1.path, _1.lineno, _1.label] }
  $body_load_frame = caller_locations(0, 1).map { [_1.path, _1.lineno, _1.label] }
RUBY
contract = %w[off original edited].to_h do |arm|
  stdout, stderr, status = Open3.capture3(env.merge("ENDPOINT_BODY_CONTRACT" => arm), RbConfig.ruby, "--disable-yjit",
    File.expand_path(__FILE__), fixture)
  File.write(File.join(out, "contract-#{arm}.log"), stdout + stderr)
  raise "contract #{arm} failed" unless status.success?
  [arm, JSON.parse(stdout.lines.last)]
end
%w[original edited].each do |arm|
  %w[metadata mutation reload].each do |key|
    raise "#{arm} #{key} differs" unless contract.fetch("off").fetch(key) == contract.fetch(arm).fetch(key)
  end
end
File.write(File.join(out, "contract.json"), JSON.pretty_generate(contract))
puts "Cold metadata, exception frames, handles, super/alias and mutation results identical (off/original/edited). Trace/load-stack/ISeq differences retained."
exit if ARGV[2] == "contract-only"
raise "interpreter study only" if ENV.fetch("BENCH_JIT", "0") != "0"
environments = %w[off_a off_b original guards].to_h do |arm|
  [arm, env.merge("ENDPOINT_BODY_WORKER" => arm.start_with?("off") ? "off" : arm)]
end
sources = [__FILE__, File.expand_path("../heap_windows.rb", __dir__), File.expand_path("../request_pairs.rb", __dir__),
  *Dir[File.join(BodyCost::LIB, "lowrail/**/*.rb")], File.join(BodyCost::LIB, "lowrail.rb")].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources}
accepted = RequestPairs.heap_instructions(environments, app, out, "GET:/articles/1", metadata,
  worker: File.expand_path(__FILE__), requests: 200)
raise "study source changed" unless sources.all? { |file, sha| Digest::SHA256.file(file).hexdigest == sha }
raw = JSON.parse(File.read(File.join(out, "samples.json")))
raise "link output changed" unless raw.fetch("workers").values.map { _1.fetch("results") }.uniq.size == 1
prices = %w[instructions_total instructions_no_gc].to_h do |metric|
  rows = raw.fetch("samples")
  guards = rows.map { _1.fetch("guards").fetch(metric) - _1.fetch("original").fetch(metric) }
  [metric, {
    original_two_links: RequestPairs.estimate(rows.map { _1.fetch("off_a").fetch(metric) }, seed: 41231),
    original_delivery_increment: RequestPairs.estimate(rows.map { _1.fetch("original").fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231),
    internal_guard_floor: RequestPairs.estimate(guards, seed: 41231),
    guards_minus_entire_links: RequestPairs.estimate(rows.zip(guards).map { |row, cost| cost - row.fetch("off_a").fetch(metric) }, seed: 41231)
  }]
end
File.write(File.join(out, "body-budget.json"), JSON.pretty_generate(accepted: accepted, prices: prices,
  caveat: "Checks plus unchanged body, not an accelerated implementation or complete certificate. Ten internal-method facts only; omits holders, primitives, mutable tables and repeated boundaries."))
puts JSON.pretty_generate(prices)
exit(accepted ? 0 : 2)
