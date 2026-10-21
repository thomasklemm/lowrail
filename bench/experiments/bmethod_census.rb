# frozen_string_literal: true

# Research only. Run with LOWRAIL=0, never in a timing/instruction worker.
# static APP OUTPUT; boot APP OUTPUT [BOOT_FIXTURE]; micro OUTPUT
require "json"
require "digest"
require "prism"

module BmethodCensus
  MODULE_NAME = Module.instance_method(:name)
  module_function

  def write(path, data)
    File.write(path, JSON.pretty_generate(data) + "\n")
  end

  def static(app, output)
    descriptions = %i[enum store store_accessor delegate delegate_missing_to class_attribute
      attribute belongs_to has_one has_many has_and_belongs_to_many accepts_nested_attributes_for
      has_secure_password has_secure_token generates_token_for define_method define_singleton_method]
    sites, errors, hashes = [], [], {}
    Dir["#{app}/{app,lib,config}/**/*.rb"].sort.each do |path|
      source = File.read(path)
      relative = path.delete_prefix(app + "/")
      hashes[relative] = Digest::SHA256.hexdigest(source)
      parsed = Prism.parse(source)
      errors.concat(parsed.errors.map { [relative, _1.location.start_line, _1.message] })
      visit = lambda do |node|
        if Prism::CallNode === node && descriptions.include?(node.name)
          sites << {file: relative, line: node.location.start_line, macro: node.name,
            source: node.location.slice, arguments: node.arguments&.arguments&.map { _1.location.slice }}
        end
        node.compact_child_nodes.each { visit.call(_1) }
      end
      visit.call(parsed.value)
    end
    write(output, {kind: "static_description_sites_not_expanded_methods", sites: sites, errors: errors,
      source_sha256: hashes, counts: sites.group_by { _1[:macro] }.transform_values(&:size)})
  end

  def label(holder)
    MODULE_NAME.bind_call(holder) || if holder.singleton_class? && Module === holder.attached_object
      "singleton(#{label(holder.attached_object)})"
    else
      @anonymous[holder] ||= "anonymous:#{@anonymous.size + 1}"
    end
  end

  def shape(method)
    iseq = RubyVM::InstructionSequence.of(method)
    {owner: label(method.owner), source_location: method.source_location,
      parameters: method.parameters, arity: method.arity,
      iseq_type: iseq&.to_a&.fetch(9), iseq_label: iseq&.label}
  end

  def visibility(holder, name)
    return "public" if holder.public_method_defined?(name)
    return "protected" if holder.protected_method_defined?(name)
    return "private" if holder.private_method_defined?(name)
    "undefined"
  end

  def start
    @anonymous = {}.compare_by_identity
    @generated = {}
    @eval_methods = Hash.new { |hash, key| hash[key] = [] }
    @trace = TracePoint.new(:c_return, :script_compiled) do |event|
      if event.event == :script_compiled
        if (source = event.eval_script)
          visit = lambda do |iseq|
            if iseq.to_a[9] == :method
              @eval_methods[[iseq.path, iseq.first_lineno, iseq.label]] <<
                {iseq: iseq.to_a, eval_sha256: Digest::SHA256.hexdigest(source)}
            end
            iseq.each_child { visit.call(_1) }
          end
          visit.call(event.instruction_sequence)
        end
        next
      end
      next unless %i[define_method define_singleton_method].include?(event.method_id)
      name = event.return_value
      next unless Symbol === name || String === name
      holder = event.method_id == :define_singleton_method ? event.self.singleton_class : event.self
      next unless Module === holder
      begin
        method = Module.instance_method(:instance_method).bind_call(holder, name)
        key = [holder.__id__, name.to_sym]
        if @generated.key?(key)
          (@generated[key][:later_definitions] ||= []) << shape(method)
        else
          @generated[key] = {holder: holder, method: method, definition_at: [event.path, event.lineno],
            enum_generator: caller_locations(0, 20).any? { _1.path.end_with?("/active_record/enum.rb") }}
        end
      rescue NameError
        # A method_added hook can remove the method before define_method returns.
      end
    end
    @trace.enable
  end

  def snapshot
    @trace.disable
    consumers = Hash.new { |hash, key| hash[key] = [] }.compare_by_identity
    ObjectSpace.each_object(Module) do |receiver|
      next unless MODULE_NAME.bind_call(receiver) || (receiver.singleton_class? && Module === receiver.attached_object && MODULE_NAME.bind_call(receiver.attached_object))
      receiver.ancestors.each { consumers[_1] << receiver }
    end
    overrides = lambda do |holder, name, original|
      consumers[holder].filter_map do |receiver|
        effective = receiver.instance_method(name) rescue nil
        next if effective == original
        {receiver: label(receiver), effective: effective && shape(effective), visibility: visibility(receiver, name)}
      end
    end
    rows = @generated.map do |(_id, name), generation|
      holder = generation.fetch(:holder)
      original = generation.fetch(:method)
      current = holder.instance_method(name) rescue nil
      {name: name, holder: label(holder), generated: shape(original),
        visibility: visibility(holder, name), current: current && shape(current),
        replaced_on_holder: current != original, definition_at: generation[:definition_at],
        later_definitions: generation[:later_definitions] || [],
        enum_generator: generation[:enum_generator], ancestors: holder.ancestors.map { label(_1) },
        consumer_overrides: overrides.call(holder, name, original)}
    end
    # Include block-backed methods loaded before instrumentation (e.g. Bundler).
    known = @generated.keys.to_h { [_1, true] }
    ObjectSpace.each_object(Module) do |holder|
      names = holder.public_instance_methods(false) | holder.protected_instance_methods(false) | holder.private_instance_methods(false)
      names.each do |name|
        next if known[[holder.__id__, name]]
        method = holder.instance_method(name) rescue next
        iseq = RubyVM::InstructionSequence.of(method)
        next unless iseq
        generated_eval = @eval_methods.fetch([iseq.path, iseq.first_lineno, iseq.label], []).find { _1[:iseq] == iseq.to_a }
        next unless iseq.to_a[9] == :block || generated_eval
        rows << {name: name, holder: label(holder), generated: shape(method), current: shape(method),
          visibility: visibility(holder, name), replaced_on_holder: false,
          definition_at: nil, enum_generator: false, ancestors: holder.ancestors.map { label(_1) },
          eval_sha256: generated_eval && generated_eval[:eval_sha256],
          consumer_overrides: overrides.call(holder, name, method)}
      end
    end
    @rows = rows.sort_by { [_1[:holder], _1[:name].to_s] }
  end

  def enums
    return [] unless defined?(ActiveRecord::Base)
    ActiveRecord::Base.descendants.sort_by { _1.name.to_s }.filter_map do |model|
      next if model.defined_enums.empty?
      owner = model.send(:_enum_methods_module)
      definitions = @rows.select do |row|
        row[:enum_generator] && ((row[:holder] == label(owner) && row.dig(:generated, :source_location, 0)&.end_with?("/active_record/enum.rb")) ||
          (row[:holder] == label(model.singleton_class) && row.dig(:generated, :source_location, 0)&.end_with?("/active_record/scoping/named.rb")))
      end
      methods = definitions.map do |row|
        receiver = row[:holder] == label(owner) ? model : model.singleton_class
        effective = receiver.instance_method(row[:name]) rescue nil
        generated = @generated.find { |(_id, name), generation| label(generation[:holder]) == row[:holder] && name == row[:name] }&.last&.fetch(:method)
        {name: row[:name], kind: row[:holder] == label(owner) ? (row[:name].to_s.end_with?("!") ? "bang" : "predicate") : "scope",
          generated_owner: row[:holder], generated: row[:generated], effective: effective && shape(effective),
          overridden: effective != generated, visibility: visibility(receiver, row[:name]),
          lookup_chain: receiver.ancestors.map { label(_1) }}
      end
      {model: model.name, values: model.defined_enums, methods: methods}
    end
  end

  def report
    {kind: "untimed_boot_generation_census_not_support_or_price", ruby: RUBY_DESCRIPTION,
      rails: defined?(Rails) && Rails.version, environment: ENV["RAILS_ENV"], lowrail: ENV["LOWRAIL"],
      lock_sha256: Digest::SHA256.file(File.join(@app || Rails.root.to_s, "Gemfile.lock")).hexdigest,
      methods: @rows, enums: enums,
      counts: {methods: @rows.size, bmethods: @rows.count { _1.dig(:generated, :iseq_type) == :block },
        replaced_on_holder: @rows.count { _1[:replaced_on_holder] }}}
  end

  def boot(app, output, fixture = nil)
    @app = app
    start
    begin
      if fixture
        load fixture
      else
        require File.join(app, "config/environment")
      end
      Rails.application.eager_load!
      snapshot
      write(output, report.merge(boot: "ok"))
    rescue Exception => error
      @trace.disable
      snapshot
      write(output, report.merge(boot: "failed_partial_inventory", error: {class: error.class.name,
        message: error.message, backtrace: error.backtrace&.first(8)}))
      raise
    end
  end

  def micro(output)
    klass = Class.new do
      def status_for_database = @status
      def initialize = (@status = 1)
      name, value = :status, 1
      define_method(:block_dynamic?) { public_send(:"#{name}_for_database") == value }
      define_method(:block_fixed?) { status_for_database == 1 }
      def plain? = status_for_database == 1
      def plain_dynamic? = public_send(:status_for_database) == 1
    end
    object = klass.new
    # Distinct loops avoid a shared polymorphic dispatch site; include loop cost.
    %i[block_dynamic? block_fixed? plain? plain_dynamic?].each do |name|
      klass.class_eval("def loop_#{name.to_s.delete('?')}(n); n.times { #{name} }; end", __FILE__, __LINE__)
    end
    n = 2_000_000
    names = %i[block_dynamic block_fixed plain plain_dynamic]
    names.each { object.public_send(:"loop_#{_1}", 100_000) }
    samples = Array.new(5) do |round|
      names.rotate(round).to_h do |name|
        GC.start
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        object.public_send(:"loop_#{name}", n)
        [name, (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1e9 / n]
      end
    end
    write(output, {kind: "wall_clock_micro_not_price_or_request_cohort", ruby: RUBY_DESCRIPTION,
      yjit: RubyVM::YJIT.enabled?, iterations: n, warmup: 100_000, ns_per_iteration: samples,
      medians: names.to_h { |name| [name, samples.map { _1.fetch(name) }.sort[2]] }})
  end
end

if $PROGRAM_NAME == __FILE__
  command, app, output, fixture = ARGV
  case command
  when "static" then BmethodCensus.static(File.realpath(app), output)
  when "boot" then BmethodCensus.boot(File.realpath(app), output, fixture)
  when "micro" then BmethodCensus.micro(app)
  else abort "usage: bmethod_census.rb static|boot APP OUTPUT [BOOT_FIXTURE] | micro OUTPUT"
  end
end
