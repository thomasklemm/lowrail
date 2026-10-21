# frozen_string_literal: true

module Lowrail
  # The first sealed pilot is deliberately narrower than the contract: stock
  # Rails 8.1.4 blog views, literal link names/classes, and live URL generation.
  # No invalidation claim: production must honor SEAL001–009. Test processes
  # refuse this delivery; seal-check observes their original executions.
  module Sealed
    PASS = "sealed/link_to"
    ACTIVE = [false]
    BUILDERS = ObjectSpace::WeakKeyMap.new
    EPOCH = [0]
    REQUEST = :__lowrail_sealed_request
    ENCODING = String.instance_method(:encoding)
    VALID = String.instance_method(:valid_encoding?)

    class << self
      attr_reader :refusal

      # Parser IDs/source hashes are compilation metadata, not method code.
      # Keep instructions, operands, locals, catches, paths and line events.
      def signature(method, sequence: RubyVM::InstructionSequence.of(method)&.to_a)
        clean = ->(value) do
          return value unless Array === value
          value = value.map { clean.call(_1) }
          if value.first == "YARVInstructionSequence/SimpleDataFormat"
            value[4] = value[4].reject { |key, _| %i[node_id node_ids code_location source_hash].include?(key) }
          end
          value
        end
        {"owner" => method.owner.name, "source_location" => method.source_location,
          "parameters" => method.parameters.map { _1.map(&:to_s) },
          "original_name" => method.original_name.to_s,
          "iseq" => sequence && Manifest.digest.hexdigest(Marshal.dump(clean.call(sequence)))}
      end

      def install(units)
        @unit = units.fetch(0)
        @data = @unit.fetch("sealed")
      end

      def decline(reason)
        @refusal = reason
        ACTIVE[0] = false
        Lowrail.debug("sealed refused: #{reason}")
      end

      # The default preserves the separate build-time form audit. Link always
      # supplies its native predicate; it never falls back to objspace.
      def literal_state?(exact_class: ->(object, expected) { ObjectSpace.internal_class_of(object).equal?(expected) })
        types = ActionView::Helpers::TagHelper::TAG_TYPES
        blank = String::BLANK_RE
        names = ERB::Util::SAFE_XML_TAG_NAME_REGEXP
        native_escape = ERB::Util.method(:html_escape).super_method
        exact_class.call(types, Hash) && types.frozen? &&
          types.default.nil? && types.default_proc.nil? && types["class"].nil? && types["href"].nil? &&
          exact_class.call(blank, Regexp) && blank.frozen? && blank == /\A[[:space:]]*\z/ &&
          exact_class.call(names, Regexp) && names.frozen? &&
          names.match?("class") && names.match?("href") && native_escape &&
          native_escape.owner.equal?(ERB::Util.singleton_class) && native_escape.source_location.nil?
      end

      def activate
        return decline("production_only; this test runs unoptimized") unless ENV["RAILS_ENV"] == "production"
        return decline("unsupported Ruby/Rails") unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
        return decline("application class differs from certificate") unless Rails.application.class.name == @data.fetch("application_class")
        # Certification may prepare a disposable build process. Admission may
        # only observe the real app. The optional primitive was loaded equally
        # in both arms at gem require, never compiled or replaced here.
        native = Lowrail.loaded_constant("Lowrail::Native")
        return decline("Lowrail native actual-holder primitive unavailable; run rake compile; keep original") unless native
        @holder = native.method(:exact_class?)
        native_file = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
        return decline("loaded native actual-holder binary not certified; rebuild required") unless @data.fetch("sources").key?(native_file)
        dependencies = ["ActionView::Helpers::TagHelper::TagBuilder", "ActionView::Helpers::TagHelper::TAG_TYPES",
          "String::BLANK_RE", "ERB::Util::SAFE_XML_TAG_NAME_REGEXP", *@data.fetch("primitive_methods").map { _1.fetch("holder") }]
        return decline("helper dependencies not already loaded; keep original") unless dependencies.all? { Lowrail.loaded_constant(_1) }
        return decline("stale sources") unless @data.fetch("sources").all? { |path, sha| File.file?(path) && Manifest.sha256_file(path) == sha }
        return decline("cold factory/entry delivery missing") unless @data.fetch("delivery").keys.all? { Loader.served?(_1) }
        controller = Lowrail.loaded_constant(@data.fetch("controller"))
        return decline("controller missing") unless controller
        @view_class = controller.instance_variable_get(:@view_context_class)
        return decline("view context class not already materialized; keep original") unless @view_class
        @data.fetch("view_methods").each do |name, expected|
          actual = @view_class.instance_method(name)
          return decline("view method #{name}") unless signature(actual) == expected.fetch("signature") &&
            visibility(@view_class, name) == expected.fetch("visibility")
        end
        @data.fetch("builder_methods").each do |name, expected|
          holder = ActionView::Helpers::TagHelper::TagBuilder
          return decline("builder method #{name}") unless signature(holder.instance_method(name)) == expected.fetch("signature") &&
            visibility(holder, name) == expected.fetch("visibility")
        end
        @data.fetch("primitive_methods").each do |expected|
          holder = Lowrail.loaded_constant(expected.fetch("holder"))
          actual = expected["singleton"] ? holder.method(expected.fetch("method")) : holder.instance_method(expected.fetch("method"))
          return decline("primitive #{expected['holder']}##{expected['method']}") unless signature(actual) == expected.fetch("signature")
        end
        @data.fetch("delivery").each_value do |expected|
          holder = Lowrail.loaded_constant(expected.fetch("holder"))
          return decline("edited body #{expected['method']}") unless holder &&
            signature(holder.instance_method(expected.fetch("method"))) == expected.fetch("signature")
        end
        builder = ActionView::Helpers::TagHelper::TagBuilder
        return decline("custom constructor") unless signature(builder.method(:new)) == @data.fetch("constructor")
        return decline("custom literal tables") unless literal_state?(exact_class: @holder)
        # This native read does not CREATE a singleton class (unlike
        # #singleton_class). It also rejects preexisting private overrides and
        # singleton prepends. It is main-Ractor-only; callers gate first.
        @epoch = defined?(Lowrail::Seal) ? Lowrail::Seal::EPOCH : EPOCH
        require_relative "templates"
        Templates.install(Lowrail.manifest.templates.merge(@data.fetch("templates")))
        ACTIVE[0] = true
        @refusal = nil
      rescue StandardError, ScriptError => error
        decline("#{error.class}: #{error.message.lines.first&.strip}")
      end

      def visibility(holder, name)
        holder.public_method_defined?(name) ? "public" : holder.protected_method_defined?(name) ? "protected" : "private"
      end

      # Called once at the real request entry. The entry body restores a prior
      # token in ensure, including nested dispatch, exceptions and threads.
      # Authorization stays behind this seam so a future trusted VM provider
      # can replace test certification without regenerating template bodies.
      def request_allowed?
        return false unless Ractor.current.equal?(Ractor.main) && @data
        # A dependency may become available through the app's own requires
        # after initialize!. Retry at the existing request entry, without
        # forcing any loading or warming an application cache.
        activate unless ACTIVE[0]
        ACTIVE[0] && @epoch[0].zero?
      end

      def view?(view)
        Ractor.current.equal?(Ractor.main) && ACTIVE[0] && Thread.current[REQUEST] &&
          @epoch[0].zero? && @holder.call(view, @view_class)
      end

      def link?(view, url, html, css)
        # Recheck diagnostic deopt after live conversion/URL code. It is NOT
        # a structural VM epoch and cannot enforce the production promise.
        return count(false) unless @epoch[0].zero? && String === url &&
          ENCODING.bind_call(url) == Encoding::UTF_8 && VALID.bind_call(url) &&
          html.size == 2 && html["class"] == css && html["href"].equal?(url)
        count(BUILDERS.key?(view.send(:tag_builder)))
      end

      def count(ok)
        Stats.count(@unit.fetch("id"), ok) if defined?(Stats) && Stats.enabled?
        ok
      end
    end
  end

  module Passes
    Sealed = Lowrail::Sealed
  end
end
