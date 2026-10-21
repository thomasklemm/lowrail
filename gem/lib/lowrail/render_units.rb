# frozen_string_literal: true

require_relative "sealed"

module Lowrail
  # Two independent passive admissions. Neither retains a view, renderer,
  # template, collection or request. The original operation supplies the
  # witness; admission only reads already-existing holders and bodies.
  module RenderUnits
    IVAR = Object.instance_method(:instance_variable_get)

    def self.observe
      require_relative "load_hooks"
      LoadHooks.active_support do
        ::ActiveSupport.on_load(:action_view) do
          require_relative "form_scaffold_inventory"
          helper = Lowrail.loaded_constant("ActionView::Helpers::UrlHelper")
          helper.prepend(TokenTag::Variant) if helper && !(helper < TokenTag::Variant)
        end
        # This seam needs only Zeitwerk's completed require aliasing, not a
        # certified initialized app. Do not allocate an initialize! TracePoint:
        # even a disabled targeted trace correctly retires sealed memo units.
        ::ActiveSupport.on_load(:after_initialize) { ::Lowrail::RenderUnits.activate }
      end
    end

    def self.activate
      # Native require observation must follow Zeitwerk's require aliasing.
      # Never resolve this autoload merely to install the symmetric seam.
      LoadHooks.when_loaded(["ActionView::CollectionRenderer"]) do
        type = Lowrail.loaded_constant("ActionView::CollectionRenderer")
        type.prepend(CollectionRender::Variant) unless type < CollectionRender::Variant
      end
    end

    def self.check(data, view)
      native = Lowrail.loaded_constant("Lowrail::Native")
      return "missing actual-holder primitive; keep original" unless native
      exact = native.method(:exact_class?)
      return "actual-holder primitive changed; rebuild" unless Sealed.signature(exact) == data.fetch("native_method")
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return "actual-holder binary not certified; rebuild" unless data.fetch("sources").key?(binary)
      return "stale sources; rebuild" unless data.fetch("sources").all? { |file, sha| File.file?(file) && Manifest.sha256_file(file) == sha }
      controller = Lowrail.loaded_constant("ArticlesController")
      view_class = controller && IVAR.bind_call(controller, :@view_context_class)
      return "view class not naturally cached; keep original" unless view_class && exact.call(view, view_class)
      return "application class changed; rebuild" unless Rails.application.class.name == data.fetch("application_class")
      data.fetch("methods").each do |entry|
        type = entry.fetch("holder") == "view" ? view_class : Lowrail.loaded_constant(entry.fetch("holder"))
        return "dependency #{entry['holder']} not already loaded; keep original" unless type
        method = entry["singleton"] ? type.method(entry.fetch("method")) : type.instance_method(entry.fetch("method"))
        if [TokenTag::Variant, CollectionRender::Variant].include?(method.owner)
          return "observer body changed; rebuild" unless Sealed.signature(method) == data.fetch("observer")
          method = method.super_method
        end
        expected = entry.fetch("body")
        return "method #{entry['holder']}##{entry['method']} changed; rebuild" unless
          FormScaffoldInventory.runtime_fact(method) == expected.reject { |key, _| key == "visibility" }
        return "visibility #{entry['holder']}##{entry['method']} changed; rebuild" if expected["visibility"] &&
          Sealed.visibility(type, entry.fetch("method")) != expected.fetch("visibility")
      end
      {holder: exact, view_class: view_class}
    end

    module Admission
      attr_reader :refusal, :input_refusal, :admission

      def install(units)
        return decline("admission already configured; restart before another setup") if @unit
        @unit = units.fetch(0)
        @data = @unit.fetch("data")
        @lock = Mutex.new
        @attempted = false
        @active = false
        @admission = {state: "pending", attempts: 0}.freeze
      end

      def activate
        return false if @attempted
        return decline("production_only; this test runs unoptimized") unless ENV["RAILS_ENV"] == "production"
        return decline("unknown passive certificate; rebuild; keep original") unless @data.fetch("version") == 1
        @epoch = defined?(Lowrail::Seal) ? Lowrail::Seal::EPOCH : Sealed::EPOCH
        @pending = true
        @refusal = "pending first natural original operation"
      rescue StandardError, ScriptError => error
        decline("#{error.class}: #{error.message.lines.first&.strip}")
      end

      def decline(reason)
        @active = @pending = false
        @attempted = true
        @refusal = "#{reason}; terminal admission"
        @admission = {state: "refused", attempts: @admission&.fetch(:attempts, 0) || 0, reason: @refusal}.freeze
        Lowrail.debug("#{name} refused: #{@refusal}")
        false
      end

      def observe(view)
        return unless @pending && !@attempted && Ractor.current.equal?(Ractor.main) && @lock.try_lock
        begin
          return if @attempted || !@pending
          @attempted = true
          @admission = {state: "pending", attempts: 1}.freeze
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = RenderUnits.check(@data, view)
          return decline(result) if String === result
          result.each { |key, value| instance_variable_set(:"@#{key}", value) }
          reason = witness(view)
          return decline(reason) if reason
          return decline("seal epoch changed during admission; keep original") unless @epoch[0].zero?
          @refusal = nil
          @pending = false
          @admission = {state: "active", attempts: 1,
            witness_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started}.freeze
          @active = true
        rescue StandardError, ScriptError => error
          decline("passive admission: #{error.class}: #{error.message.lines.first&.strip}; keep original")
        ensure
          @lock.unlock
        end
      end

      def admitted? = @active

      def count(ok, reason = nil)
        @input_refusal = reason unless ok
        Stats.count(@unit.fetch("id"), ok) if defined?(Stats) && Stats.enabled?
        ok
      end
    end
  end

  module TokenTag
    PASS = "sealed/token_tag"
    extend RenderUnits::Admission

    module Variant
      private

      def token_tag(token = nil, form_options: {})
        if ::Lowrail::TokenTag.admitted? && ::Lowrail::TokenTag.valid?(self, token, form_options)
          ::Lowrail::TokenTag.render(self, form_options)
        else
          result = super
          ::Lowrail::TokenTag.observe(self)
          result
        end
      end
    end

    class << self
      def witness(view)
        @builder_class = Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TagBuilder")
        builder = RenderUnits::IVAR.bind_call(view, :@tag_builder)
        return "tag builder not naturally cached; keep original" unless @builder_class && @holder.call(builder, @builder_class) &&
          RenderUnits::IVAR.bind_call(builder, :@view_context).equal?(view)
        return "protection helper unavailable; keep original" unless @view_class.method_defined?(:protect_against_forgery?) ||
          @view_class.private_method_defined?(:protect_against_forgery?)
        types = Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TAG_TYPES")
        return "custom literal escaping/tables; keep original" unless types && Sealed.literal_state?(exact_class: @holder) &&
          %i[type name value autocomplete].all? { types[_1].nil? && types[_1.to_s].nil? }
        nil
      end

      def valid?(view, token, options)
        return count(false, "seal epoch changed or foreign Ractor") unless Ractor.current.equal?(Ractor.main) && @epoch[0].zero?
        return count(false, "explicit token or unknown options") unless token.nil? && @holder.call(options, Hash) &&
          options.size == 2 && options.key?(:action) && options.key?(:method)
        builder = RenderUnits::IVAR.bind_call(view, :@tag_builder)
        return count(false, "unknown view/builder holder") unless @holder.call(view, @view_class) &&
          @holder.call(builder, @builder_class) && RenderUnits::IVAR.bind_call(builder, :@view_context).equal?(view)
        true
      end

      def render(view, options)
        unless view.send(:protect_against_forgery?)
          count(true)
          return ""
        end
        value = view.form_authenticity_token(form_options: options.merge(authenticity_token: nil))
        name = view.send(:request_forgery_protection_token).to_s
        remove_autocomplete = ActionView::Base.remove_hidden_field_autocomplete
        unless @epoch[0].zero? && @holder.call(name, String) && @holder.call(value, String)
          # Continue AFTER live generation/conversion. Re-entering token_tag
          # would generate/mask a token twice and replay app-defined effects.
          count(false, "live token/name holder or seal epoch changed")
          attributes = {type: "hidden", name: name, value: value}
          attributes[:autocomplete] = "off" unless remove_autocomplete
          return view.send(:tag, :input, **attributes)
        end
        count(true)
        autocomplete = remove_autocomplete ? "" : ' autocomplete="off"'
        name = ERB::Util.unwrapped_html_escape(name)
        name = name.gsub('"', "&quot;") if name.include?('"')
        value = ERB::Util.unwrapped_html_escape(value)
        value = value.gsub('"', "&quot;") if value.include?('"')
        %(<input type="hidden" name="#{name}" value="#{value}"#{autocomplete} />).html_safe
      end
    end
  end

  module CollectionRender
    PASS = "sealed/collection_render"
    extend RenderUnits::Admission

    module Variant
      private

      def collection_with_template(view, template, layout, collection)
        if ::Lowrail::CollectionRender.admitted? && ::Lowrail::CollectionRender.valid?(self, view, template, layout)
          # Keep the live iterator (including preloading), dynamic local
          # names, cache key/hash effects, Template#render and result objects.
          # Only the already-proved nonnil-template/no-layout branches vanish.
          locals = @locals
          cache = {}
          partial_iteration = ::ActionView::PartialIteration.new(collection.size)
          collection.each_with_info.map do |object, (path, as, counter, iteration)|
            index = partial_iteration.index
            locals[as] = object
            locals[counter] = index
            locals[iteration] = partial_iteration
            current = (cache[path] ||= template)
            content = current.render(view, locals, implicit_locals: [counter, iteration])
            partial_iteration.iterate!
            build_rendered_template(content, current)
          end
        else
          result = super
          ::Lowrail::CollectionRender.observe(view) if template && !layout
          result
        end
      end
    end

    class << self
      def witness(_view)
        @renderer_class = Lowrail.loaded_constant("ActionView::CollectionRenderer")
        return "custom collection iteration constant; keep original" if @renderer_class.ancestors.any? do |type|
          type.const_defined?(:PartialIteration, false)
        end
        nil
      end

      def valid?(renderer, view, template, layout)
        return count(false, "seal epoch changed or foreign Ractor") unless Ractor.current.equal?(Ractor.main) && @epoch[0].zero?
        count(template && !layout && @holder.call(renderer, @renderer_class) && @holder.call(view, @view_class),
          "unknown renderer/view holder, missing template or layout")
      end
    end
  end

  module Passes
    TokenTag = Lowrail::TokenTag
    CollectionRender = Lowrail::CollectionRender
  end
end
