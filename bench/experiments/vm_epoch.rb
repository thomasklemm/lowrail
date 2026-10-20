# frozen_string_literal: true

# Local patched-VM experiment only. No Lowrail activation or source lowering.
# ruby vm_epoch.rb micro NEW_OUTDIR | probe
require "json"
require_relative "../request_pairs"
require_relative "../heap_windows"

if ENV["VM_EPOCH_WORKER"]
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  abort "patched Ruby required" unless RubyVM.respond_to?(:mutation_epoch)
  source = {
    "off_a" => "true", "off_b" => "true",
    "read" => "RubyVM.mutation_epoch",
    "compare" => "RubyVM.mutation_epoch == saved",
    "branch" => 'raise "epoch changed" unless RubyVM.mutation_epoch == saved'
  }.fetch(ENV.fetch("VM_EPOCH_WORKER"))
  # Same enclosing method and N/0 seam for every arm; no arm dispatch in loop.
  Object.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
    def epoch_operation(n)
      saved = RubyVM.mutation_epoch
      n.times { #{source} }
      raise "unexpected mutation" unless RubyVM.mutation_epoch == saved
    end
  RUBY
  epoch_operation(100_000)
  jit_warmup = JitStability.warm { |n| epoch_operation(n) } if RubyVM::YJIT.enabled?
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
  anchors = HeapWindows.run(windows, observe: RubyVM::YJIT.enabled? ? JitStability.method(:snapshot) : nil) do |n|
    epoch_operation(n)
  end
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
    jit_warmup: jit_warmup, windows: windows, heap_anchors: anchors, ar_installed: 0)}"
  exit
end

case ARGV.fetch(0)
when "micro"
  abort "patched Ruby required" unless RubyVM.respond_to?(:mutation_epoch)
  out = File.expand_path(ARGV.fetch(1))
  abort "output must be new" if File.exist?(out)
  FileUtils.mkdir_p(out, mode: 0o700)
  sources = [File.expand_path(__FILE__)] + %w[../heap_windows.rb ../request_pairs.rb ../jit_stability.rb].map { File.expand_path(_1, __dir__) }
  metadata = {seed: 41231, rounds: 6, workers: {}, ruby: RUBY_DESCRIPTION,
    sources: sources.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}
  environments = %w[off_a off_b read compare branch].to_h do |arm|
    [arm, {"VM_EPOCH_WORKER" => arm, "RUBYOPT" => nil, "LOWRAIL_SPECULATE" => nil}]
  end
  accepted = RequestPairs.heap_instructions(environments, Dir.pwd, out, "epoch", metadata,
    worker: File.expand_path(__FILE__), requests: 100_000)
  raise "sources changed" unless metadata.fetch(:sources).all? { |path, hash| Digest::SHA256.file(path).hexdigest == hash }
  samples = JSON.parse(File.read(File.join(out, "samples.json"))).fetch("samples")
  prices = %w[instructions_total instructions_no_gc].to_h do |metric|
    [metric, %w[read compare branch].to_h do |arm|
      [arm, RequestPairs.estimate(samples.map { _1.fetch(arm).fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231)]
    end]
  end
  File.write(File.join(out, "prices.json"), JSON.pretty_generate(accepted: accepted, prices: prices))
  puts JSON.pretty_generate(accepted: accepted, prices: prices)
  exit(accepted ? 0 : 2)
when "probe"
  require "tmpdir"
  require "zeitwerk"
  require "action_dispatch"
  require "action_controller"
  require "action_view"
  # Keep original counterexample drivers unchanged; add the epoch as a stat
  # key only in this disposable process so the old constant matrix observes it.
  epoch = RubyVM.method(:mutation_epoch)
  rows = []
  observe = ->(name, catches: true, &operation) do
    before = epoch.call
    result = operation.call
    delta = epoch.call - before
    raise "#{name}: expected catches=#{catches}, delta=#{delta}" unless delta.positive? == catches
    rows << {case: name, delta: delta, detected: delta.positive?, result: result}
  end
  klass = Class.new { def foo = 7 }
  object = klass.new
  # Hooks are installed BEFORE snapshots: a definition must be seen even when
  # a pre-existing application hook consumes the subsequent notification.
  klass.define_singleton_method(:method_added) { |_| }
  observe.call("suppressed_method_added") { klass.define_method(:foo) { 19 }; object.foo }
  klass.define_singleton_method(:method_added) { |name| name == :foo ? nil : super(name) }
  raise unless RubyVM::InstructionSequence.of(klass.method(:method_added)).disasm.include?("invokesuper")
  observe.call("conditional_super") { klass.define_method(:foo) { 23 }; object.foo }
  object.define_singleton_method(:singleton_method_added) { |_| }
  observe.call("suppressed_singleton_method_added") { object.define_singleton_method(:foo) { 29 }; object.foo }
  observe.call("own_visibility") { klass.send(:private, :foo); klass.public_method_defined?(:foo) }
  observe.call("public_visibility") { klass.send(:public, :foo); klass.public_method_defined?(:foo) }
  observe.call("alias") { klass.alias_method(:bar, :foo); klass.new.bar }
  observe.call("remove") { klass.remove_method(:bar); klass.method_defined?(:bar) }
  observe.call("undef") { klass.undef_method(:foo); klass.method_defined?(:foo) }
  %i[include prepend extend].each do |operation|
    target = operation == :extend ? Object.new : Class.new
    mixin = Module.new { def epoch_mixin = 37 }
    observe.call(operation.to_s) { target.send(operation, mixin); (operation == :extend ? target : target.new).epoch_mixin }
  end
  fresh = Object.new
  observe.call("singleton_class_creation") { fresh.singleton_class; true }
  observe.call("ordinary_dispatch", catches: false) { 10.times { object.foo }; object.foo }

  host = Module.new
  replacement = Class.new
  host.const_set(:Target, Class.new)
  host.define_singleton_method(:const_added) { |_| }
  observe.call("constant_replacement_suppressed_const_added") { host.const_set(:Target, replacement); host.const_get(:Target).equal?(replacement) }
  observe.call("constant_removal") { host.send(:remove_const, :Target); host.const_defined?(:Target, false) }
  host.const_set(:PrivateTarget, 43)
  observe.call("constant_visibility") { host.private_constant(:PrivateTarget); true }

  # A mutation boundary may itself call application Ruby. Cache clearing at
  # the END of remove_const is too late for an overridable Warning.warn.
  host.const_set(:DeprecatedTarget, 47)
  host.deprecate_constant(:DeprecatedTarget)
  warning = Warning.method(:warn)
  deprecated = Warning[:deprecated]
  warnings = []
  removal_epoch = nil
  Warning.define_singleton_method(:warn) do |message, **|
    warnings << {epoch_changed: epoch.call != removal_epoch,
      present: host.const_defined?(:DeprecatedTarget, false)}
  end
  Warning[:deprecated] = true
  removal_epoch = epoch.call
  observe.call("deprecated_removal_warning_reentry") do
    host.send(:remove_const, :DeprecatedTarget)
    raise unless warnings == [{epoch_changed: true, present: false}]
    warnings
  end
  Warning.define_singleton_method(:warn, warning)
  Warning[:deprecated] = deprecated

  # Real Rails receivers, not stand-in method names. Restore each definition
  # outside its observed interval; force TagBuilder before capturing facts.
  view = ActionView::Base.empty
  builder = view.send(:tag_builder)
  [[view, %i[convert_options_to_data_attributes link_to_remote_options? url_target url_for content_tag ensure_valid_html5_tag_name tag_builder]],
    [builder, %i[content_tag_string tag_options tag_option]]].each do |receiver, methods|
    holder = receiver.singleton_class
    holder.define_method(:singleton_method_added) { |_| }
    methods.each do |name|
      original = receiver.method(name).unbind
      observe.call("rails_method/#{name}") do
        holder.define_method(name) { |*| :changed }
        receiver.method(name).unbind != original
      end
      holder.remove_method(name)
      holder.define_method(name, original)
      holder.send(:public, name)
      observe.call("rails_visibility/#{name}") { holder.send(:private, name); !holder.public_method_defined?(name) }
      holder.remove_method(name)
    end
  end
  replacement_builder = ActionView::Helpers::TagHelper::TagBuilder.new(view)
  observe.call("tag_builder_ivar_replacement", catches: false) { view.instance_variable_set(:@tag_builder, replacement_builder); view.send(:tag_builder).equal?(replacement_builder) }
  tag_helper = ActionView::Helpers::TagHelper
  stock_tags = tag_helper::TAG_TYPES
  # The stock table is frozen. Rebinding to a mutable copy bumps first; if a
  # later certificate accepts that copy, its future in-place edits do not.
  tags = stock_tags.dup
  observe.call("TAG_TYPES_rebinding") { tag_helper.const_set(:TAG_TYPES, tags); true }
  observe.call("TAG_TYPES_in_place", catches: false) { tags["epoch-probe"] = :void; tags.delete("epoch-probe") }
  tag_helper.const_set(:TAG_TYPES, stock_tags)
  strings = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
  previous_default = strings.default_proc
  observe.call("PRE_CONTENT_STRINGS_contents", catches: false) { strings["epoch-probe"] = "changed"; strings.fetch("epoch-probe") }
  strings.delete("epoch-probe")
  observe.call("PRE_CONTENT_STRINGS_default", catches: false) { strings.default = "changed"; strings["unknown-probe"] }
  strings.default_proc = previous_default
  config = {limit: 7, nested: {mode: :old}}
  observe.call("direct_config_and_nested_mutation", catches: false) { config[:limit] = 31; config[:nested][:mode] = :new; config }
  name = +"safe"
  observe.call("input_encoding_safety", catches: false) { name.force_encoding(Encoding::ASCII_8BIT); [name.encoding.name, name.html_safe?] }

  # Actual Notifications start subscriber; a warmed helper changes between
  # entry and the later call. No Lowrail guard or request replay is involved.
  helper = ActionView::Helpers::UrlHelper
  original = helper.instance_method(:link_to)
  helper.define_singleton_method(:method_added) { |_| }
  view.link_to("link", "/target")
  entry_epoch = epoch.call
  subscriber = Object.new
  subscriber.define_singleton_method(:start) do |*|
    helper.define_method(:link_to) { |*args| original.bind_call(self, *args) + "<!-- live helper -->".html_safe }
  end
  subscriber.define_singleton_method(:finish) { |*| }
  token = ActiveSupport::Notifications.subscribe("process_action.action_controller", subscriber)
  observe.call("process_action_subscriber") do
    result = ActiveSupport::Notifications.instrument("process_action.action_controller") { view.link_to("link", "/target") }
    raise unless result.include?("<!-- live helper -->")
    result
  end
  raise unless epoch.call != entry_epoch
  ActiveSupport::Notifications.unsubscribe(token)
  helper.define_method(:link_to, original)

  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw { resources :widgets }
  context = routes.url_helpers
  route = routes.named_routes.get(:widget)
  argument = Object.new
  conversions = 0
  armed = false
  argument.define_singleton_method(:to_param) do
    conversions += 1
    if armed
      route.define_singleton_method(:singleton_method_added) { |_| }
      route.define_singleton_method(:format) { |_| +"/changed" }
    end
    "7"
  end
  raise unless context.widget_path(argument) == "/widgets/7"
  conversions = 0
  armed = true
  observe.call("to_param_changes_route_format") do
    result = context.widget_path(argument)
    raise unless result == "/changed" && conversions == 1
    {path: result, conversions: conversions}
  end
  builder = view.send(:tag_builder)
  observe.call("name_changes_builder") do
    calls = 0
    label = -> { calls += 1; builder.define_singleton_method(:content_tag_string) { |*| "<!-- changed builder -->".html_safe }; "link" }
    result = view.link_to(label.call, "/target")
    raise unless result == "<!-- changed builder -->" && calls == 1
    {html: result, name_calls: calls}
  end

  # The measured ordinary Ruby API is not a non-overridable VM instruction.
  # Structural detection works, but an unchecked call to the getter can lie.
  saved_epoch = epoch.call
  observe.call("ordinary_getter_override_hazard") do
    RubyVM.define_singleton_method(:mutation_epoch) { saved_epoch }
    result = {ordinary_compare_stale_true: RubyVM.mutation_epoch == saved_epoch,
      captured_reader_detected: epoch.call != saved_epoch}
    raise unless result.values.all?
    result
  end
  RubyVM.define_singleton_method(:mutation_epoch, epoch)

  # Execute the existing constant/autoload/Zeitwerk matrix with exactly its
  # original fixtures and assertions, while collecting the extra generation.
  original_stat = RubyVM.method(:stat)
  RubyVM.define_singleton_method(:stat) do |*args|
    result = original_stat.call(*args)
    args.empty? ? result.merge(mutation_epoch: epoch.call) : result
  end
  constant_output = StringIO.new
  saved_stdout, $stdout = $stdout, constant_output
  begin
    load File.expand_path("constant_epoch.rb", __dir__)
  ensure
    $stdout = saved_stdout
  end
  constants = JSON.parse(constant_output.string)
  raise "missed constant mutation" unless constants.fetch("cases").all? { _1.fetch("delta").fetch("mutation_epoch").positive? }
  puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, rails: ActionPack::VERSION::STRING,
    zeitwerk: Zeitwerk::VERSION, cases: rows, constants: constants.fetch("cases"))
else
  abort "usage: vm_epoch.rb micro NEW_OUTDIR | probe"
end
