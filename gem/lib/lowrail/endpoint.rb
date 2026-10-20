# frozen_string_literal: true

module Lowrail
  # An incremental endpoint pilot, NOT the hand-written ceiling specimen.
  # Rails runs process, callbacks, actions, renderers and events exactly once.
  module Endpoint
    PASS = "endpoint/action"
    CLASS = Kernel.instance_method(:class)
    SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
    IVAR_GET = Kernel.instance_method(:instance_variable_get)
    INSTANCE_METHOD = Module.instance_method(:instance_method)
    PUBLIC = Module.instance_method(:public_method_defined?)
    CURRENT = ObjectSpace::WeakKeyMap.new

    class << self
      attr_reader :entries

      def method_signature(method)
        iseq = RubyVM::InstructionSequence.of(method)
        {"owner" => method.owner.name, "source_location" => method.source_location,
          "original_name" => method.original_name.to_s,
          "iseq" => iseq && Manifest.digest.hexdigest(Marshal.dump(iseq.to_a))}
      end

      def template_signature(method)
        sequence = RubyVM::InstructionSequence.of(method)&.to_a
        return unless sequence
        label = sequence.fetch(5)
        canonicalize = ->(value) do
          return value unless Array === value
          value = value.map { canonicalize.call(_1) }
          if value.first == "YARVInstructionSequence/SimpleDataFormat"
            # These fields describe parser locations, not executed code. The
            # compiled-template name contains an intentionally process-local ID,
            # also included in Ruby 4.1's source_hash. Keep all executable fields.
            value[4] = value[4].reject { |key, _| %i[node_id node_ids code_location source_hash].include?(key) }
            value[5] = value[5].gsub(label, "<template>")
          end
          value
        end
        Manifest.digest.hexdigest(Marshal.dump(canonicalize.call(sequence)))
      end

      def install(units) = @units = units

      def activate
        require "digest"
        @entries = {}
        return unless Rails.version == "8.1.4" && Rails.application.class.name == "RealBlogR4::Application"
        @units.group_by { _1.fetch("endpoint").fetch("controller") }.each do |name, units|
          klass = Object.const_get(name)
          valid = units.select do |unit|
            data = unit.fetch("endpoint")
            data.fetch("sources").all? { |path, sha| File.file?(path) && Manifest.sha256_file(path) == sha } &&
              method_signature(klass.instance_method(:process)) == data.fetch("process")
          end
          next if valid.empty?
          data = valid.first.fetch("endpoint")
          helper = klass.view_context_class.instance_method(:link_to)
          next unless method_signature(helper) == data.fetch("helper")
          factory = File.join(Lowrail.manifest.dir, data.fetch("iseq"))
          next unless Manifest.sha256_file(factory) == data.fetch("iseq_sha256")
          wrapper, runners = RubyVM::InstructionSequence.load_from_binary(File.binread(factory)).eval
          view_class = klass.view_context_class
          run = view_class.instance_method(:_run)
          next unless method_signature(run) == data.fetch("run")
          valid.each do |unit|
            @entries[[klass, unit.fetch("endpoint").fetch("action")]] = Entry.new(klass, helper, unit, run, runners)
          end
          runners.each { view_class.prepend(_1) }
          klass.prepend(wrapper)
        rescue StandardError, ScriptError => e
          Lowrail.debug("endpoint declined: #{e.class}: #{e.message}")
        end
        unless @entries.empty?
          require_relative "templates"
          templates = @entries.values.flat_map { _1.templates.to_a }.to_h
          Templates.install(Lowrail.manifest.templates.merge(templates))
        end
      rescue StandardError, ScriptError => error
        @entries = {}
        Lowrail.debug("endpoint inactive: #{error.class}: #{error.message}")
      end

      def enter(controller, action)
        klass = CLASS.bind_call(controller)
        entry = @entries && @entries[[klass, action.to_s]]
        return unless entry
        hit = entry.admit?(controller)
        Stats.count(entry.id, false) if !hit && defined?(Stats) && Stats.enabled?
        hit ? Execution.new(entry) : nil
      end

      def current(view)
        return unless ::Ractor.current.equal?(::Ractor.main)
        # Do not call app-overridable #controller, #class or #method to
        # establish facts about the receiver whose dispatch is being removed.
        controller = IVAR_GET.bind_call(view, :@_controller)
        controller && CURRENT[controller]
      end
    end

    # Request-local accounting and permission, kept off observable controller
    # ivars/view_assigns. A local deopt never restarts the controller process.
    class Execution
      def initialize(entry)
        @entry = entry
        @counted = {}
      end

      def template_current?(...)
        current = @entry.template_current?(...)
        count(true) if current
        current
      end

      def helper_current?(view)
        current = @entry.helper_current?(view)
        count(false) unless current
        current
      end

      private

      def count(hit)
        return unless defined?(Stats) && Stats.enabled? && !@counted[hit]
        Stats.count(@entry.id, hit)
        @counted[hit] = true
      end
    end

    class Entry
      attr_reader :id, :templates

      def initialize(klass, helper, unit, run, runners)
        @klass, @helper, @unit = klass, helper, unit
        @run, @runners = run, runners
        @compiled = {}
        @id = unit.fetch("id")
        @templates = unit.fetch("endpoint").fetch("templates")
        @callbacks = klass._process_action_callbacks
      end

      def admit?(controller)
        klass = CLASS.bind_call(controller)
        valid = if defined?(Stats) && Stats.enabled?
          Guard.validate(id, klass: klass) # Entry validation is not template execution.
        else
          klass.equal?(K[id]) || Lowrail.ok?(id, klass)
        end
        return false unless valid
        request = controller.request
        expected = @unit.fetch("endpoint").fetch("action") == "show" ? %w[action controller id] : %w[action controller]
        request.get? && request.format == Mime[:html] && request.variant.empty? &&
          request.parameters.keys.sort == expected && Object.const_get(@klass.name).equal?(@klass) &&
          I18n.locale.to_s == @unit.fetch("endpoint").fetch("locale") &&
          @klass._process_action_callbacks.equal?(@callbacks) &&
          @klass.view_context_class.instance_method(:link_to) == @helper &&
          @templates.all? { |path, data| File.file?(path) && Manifest.sha256_file(path) == data.fetch("source_sha256") }
      rescue StandardError
        false
      end

      def template_current?(view, method, template, locals, path)
        return false unless template.identifier == path
        data = @templates.fetch(path)
        return false unless locals.keys.map(&:to_s).sort == data.fetch("locals")
        holder = SINGLETON_CLASS.bind_call(view)
        run = INSTANCE_METHOD.bind_call(holder, :_run)
        run = run.super_method while run && @runners.include?(run.owner)
        return false unless run == @run
        current = INSTANCE_METHOD.bind_call(holder, method)
        return false unless PUBLIC.bind_call(holder, method)
        return true if @compiled[method] == current
        return false unless Endpoint.template_signature(current) == data.fetch("template_iseq")
        @compiled[method] = current
        true
      rescue NameError, TypeError
        false
      end

      def helper_current?(view)
        # Direct effective lookup and visibility close suppressed-hook,
        # singleton/prepend and own-private holes; K is only the entry cache.
        holder = SINGLETON_CLASS.bind_call(view)
        INSTANCE_METHOD.bind_call(holder, :link_to) == @helper && PUBLIC.bind_call(holder, :link_to)
      rescue NameError, TypeError
        false
      end
    end
  end

  module Passes
    Endpoint = Lowrail::Endpoint
  end
end
