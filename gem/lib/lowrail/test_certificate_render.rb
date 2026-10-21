# frozen_string_literal: true

require_relative "render_units"

module Lowrail
  # Verification-only authority. Production RenderUnits::Admission and its
  # Seal epoch are never used by these installers.
  module TestCertificateRender
    module_function

    def install
      TokenTag.singleton_class.prepend(Admission) unless TokenTag.singleton_class < Admission
      CollectionRender.singleton_class.prepend(Admission) unless CollectionRender.singleton_class < Admission
      TokenTag.singleton_class.prepend(Token) unless TokenTag.singleton_class < Token
    end

    def revoke
      [TokenTag, CollectionRender].each do |unit|
        unit.instance_variable_set(:@active, false)
        unit.instance_variable_set(:@pending, false)
        %i[holder view_class builder_class renderer_class].each { unit.instance_variable_set(:"@#{_1}", nil) }
        unit.instance_variable_set(:@admission, {state: "refused", reason: "verification authority retired"}.freeze)
      end
    end

    # Branch evidence is passive and symmetric, including LOWRAIL=0. A
    # targeted line observer never invokes protection/generation a second time.
    # These offsets describe the independently pinned Rails 8.1.4 stock body;
    # any other source remains an unknown observation, not protected coverage.
    def observe_operations
      return if @observing
      @observing = true
      @branch_pid, @branches = Process.pid, Hash.new(0)
      # The production tail seam has only a view argument. A targeted return
      # observes both actual holders after the complete original operation,
      # without changing that shared seam or retaining a renderer/request.
      @collection_trace = TracePoint.new(:return) do |event|
        next unless Ractor.current.equal?(Ractor.main) && TestCertificate.active?
        next unless TestCertificate::IVAR.bind_call(CollectionRender, :@pending) &&
          TestCertificate::CLASS.bind_call(event.return_value).equal?(Array)
        frame = event.binding
        next unless frame.local_variable_get(:template) && !frame.local_variable_get(:layout)
        CollectionRender.observe(frame.local_variable_get(:view), renderer: event.self, completed: true)
      rescue StandardError, ScriptError
        CollectionRender.retire_render("completion unknown") if TestCertificate::IVAR.bind_call(CollectionRender, :@pending)
      end
      @collection_trace.enable(target: CollectionRender::Variant.instance_method(:collection_with_template))
      require_relative "load_hooks"
      LoadHooks.active_support do
        ::ActiveSupport.on_load(:action_view) do
          helper = Lowrail.loaded_constant("ActionView::Helpers::UrlHelper")
          method = helper && Module.instance_method(:instance_method).bind_call(helper, :token_tag)
          path, line = method&.source_location
          unless path&.end_with?("/action_view/helpers/url_helper.rb") && line == 770
            Lowrail::TestCertificateRender.branch("unknown_original_source")
            next
          end
          trace = TracePoint.new(:line) do |event|
            branch = {774 => "original_generation", 780 => "original_tag", 782 => "original_empty"}[event.lineno]
            Lowrail::TestCertificateRender.branch(branch) if branch
          end
          trace.enable(target: method)
          Lowrail::TestCertificateRender.instance_variable_set(:@branch_trace, trace)
        rescue StandardError, ScriptError
          Lowrail::TestCertificateRender.branch("unknown_original_source")
        end
      end
    end

    def branch(name)
      if @branch_pid != Process.pid
        @branch_pid, @branches = Process.pid, Hash.new(0)
      end
      @branches[name] += 1
    end

    def branches
      if @branch_pid != Process.pid
        @branch_pid, @branches = Process.pid, Hash.new(0)
      end
      %w[original_generation original_tag original_empty protected_fast continuation_fallback
        empty_fast empty_retired unknown_original_source].to_h { [_1, @branches[_1]] }
    end

    module Admission
      def install(units)
        @unit = units.fetch(0)
        @data = @unit.fetch("verification_render")
        @lock = Mutex.new
        @active = @pending = false
        @admission = {state: "pending", attempts: 0}.freeze
      end

      def activate
        return false unless TestCertificate.allowed?(@unit.fetch("id"), pending: true)
        @epoch = TestCertificate.epoch(@unit.fetch("id"))
        @pending = true
        @refusal = "verification_original_operation_pending"
      end

      def admitted?
        return false unless Ractor.current.equal?(Ractor.main)
        @unit && TestCertificate.allowed?(@unit.fetch("id")) && @active && @epoch[0].zero?
      end

      def observe(view, renderer: nil, completed: false)
        return unless Ractor.current.equal?(Ractor.main)
        return unless @unit
        count(false) unless completed || (@active && TestCertificate.allowed?(@unit.fetch("id")))
        return if equal?(CollectionRender) && !completed
        return unless @pending && TestCertificate.allowed?(@unit.fetch("id"), pending: true) && @lock.try_lock
        begin
          return unless @pending
          native = Lowrail.loaded_constant("Lowrail::Native")
          exact = native&.method(:exact_class?)
          @admission = {state: "pending", attempts: @admission.fetch(:attempts) + 1}.freeze
          return retire_render("actual-holder primitive changed") unless exact && Sealed.signature(exact) == @data.fetch("native_method")
          return retire_render("view context dispatch changed; rebuild") unless Sealed.view_context_fact == @data.fetch("view_context")
          binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
          return retire_render("actual-holder binary not certified") unless @data.fetch("sources").key?(binary)
          return retire_render("source changed") unless @data.fetch("sources").all? { |path, sha| File.file?(path) && Manifest.sha256_file(path) == sha }
          controller = Lowrail.loaded_constant("ArticlesController")
          view_class = controller && TestCertificate::IVAR.bind_call(controller, :@view_context_class)
          # A foreign/missing context is local, not a mutation of this unit.
          return unless view_class && exact.call(view, view_class)
          if equal?(CollectionRender)
            renderer_class = Lowrail.loaded_constant("ActionView::CollectionRenderer")
            return unless renderer_class && exact.call(renderer, renderer_class)
          end
          holders, names = [native.singleton_class], [:exact_class?]
          @data.fetch("methods").each do |entry|
            type = entry.fetch("holder") == "view" ? view_class : Lowrail.loaded_constant(entry.fetch("holder"))
            return retire_render("dependency not naturally loaded") unless type
            owner = entry.fetch("singleton") ? type.singleton_class : type
            holders << owner
            names << entry.fetch("method").to_sym
            method = SealSnapshot::METHOD.bind_call(owner, entry.fetch("method"))
            if [TokenTag::Variant, CollectionRender::Variant].include?(method.owner)
              return retire_render("observer changed") unless Sealed.signature(method) == @data.fetch("observer")
              method = method.super_method
            end
            return retire_render("visibility changed") unless Sealed.visibility(owner, entry.fetch("method")) == entry.fetch("visibility")
            entry.fetch("chain").each do |body|
              actual = method && FormScaffoldInventory.runtime_fact(method)
              if actual != body && entry.fetch("holder") == "view" && entry.fetch("method") == "tag_builder" && method
                # Only the existing independently compiled, source-delivered
                # cached-builder factory is accepted. No generic unwrap or
                # active link witness; this unit still validates the actual
                # cached builder at entry AND after live token generation.
                path = method.source_location&.first
                delivery = Lowrail.manifest.units.find { _1["pass"] == Sealed::PASS }&.dig("sealed", "delivery", path)
                actual = body if delivery && delivery["holder"] == "ActionView::Helpers::TagHelper" &&
                  delivery["method"] == "tag_builder" && delivery["signature"] == actual && Loader.served?(path)
              end
              return retire_render("method/super chain changed") unless actual == body
              method = method.super_method
            end
            return retire_render("super chain added") if method
          end
          @holder, @view_class = exact, view_class
          constants = if equal?(TokenTag)
            @builder_class = Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TagBuilder")
            builder = TestCertificate::IVAR.bind_call(view, :@tag_builder)
            return unless @builder_class && exact.call(builder, @builder_class) &&
              TestCertificate::IVAR.bind_call(builder, :@view_context).equal?(view)
            names.concat(%i[protect_against_forgery? request_forgery_protection_token form_authenticity_token])
            return retire_render("protection helper missing") unless view_class.method_defined?(:protect_against_forgery?) || view_class.private_method_defined?(:protect_against_forgery?)
            types = Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TAG_TYPES")
            regexp = Lowrail.loaded_constant("ERB::Util::SAFE_XML_TAG_NAME_REGEXP")
            return retire_render("literal table/escaping changed") unless Sealed.literal_state?(exact_class: exact) &&
              %i[type name value autocomplete].all? { types[_1].nil? && types[_1.to_s].nil? && regexp.match?(_1.to_s) }
            {Object => %i[ActionView ERB String Hash NilClass Array Regexp], ActionView => [:Helpers], ActionView::Helpers => [:TagHelper],
              Lowrail.loaded_constant("ActionView::Helpers::TagHelper") => %i[TAG_TYPES TagBuilder],
              ERB => [:Util], ERB::Util => [:SAFE_XML_TAG_NAME_REGEXP], String => [:BLANK_RE]}
          else
            @renderer_class = Lowrail.loaded_constant("ActionView::CollectionRenderer")
            return unless @renderer_class && Lowrail.loaded_constant("ActionView::PartialIteration")
            ancestors = SealSnapshot::ANCESTORS.bind_call(@renderer_class)
            return retire_render("collection lexical constant shadow") if ancestors.any? { SealSnapshot::DEFINED.bind_call(_1, :PartialIteration, false) }
            ancestors.to_h { [_1, [:PartialIteration]] }.merge(Object => %i[ActionView PartialIteration],
              ActionView => %i[PartialIteration CollectionRenderer])
          end
          constants[Lowrail] = [:Sealed]
          constants[Sealed] = [:VIEW_CONTEXT]
          TestCertificate.watch(@unit.fetch("id"), holders, names: names.uniq, constants: constants)
          return unless TestCertificate.allowed?(@unit.fetch("id"), pending: true) && @epoch[0].zero?
          return unless TestCertificate.release_pending(@unit.fetch("id"))
          @refusal = nil
          @pending = false
          @admission = {state: "active", attempts: @admission.fetch(:attempts)}.freeze
          @active = true # Publish last, after a complete original operation.
        rescue StandardError, ScriptError
          retire_render("observation unknown")
        ensure
          @lock.unlock
        end
      end

      def retire_render(reason)
        @active = @pending = false
        @refusal = "verification_render_#{reason.tr(' /', '__')}"
        @admission = {state: "refused", reason: @refusal}.freeze
        TestCertificate.retire(@unit.fetch("id"), @refusal)
      end

      def valid?(*arguments)
        return count(false, "verification authority retired") unless TestCertificate.allowed?(@unit.fetch("id"))
        if equal?(CollectionRender)
          renderer, view, template, layout = arguments
          return count(template && !layout && @holder.call(renderer, @renderer_class) && @holder.call(view, @view_class),
            "unknown renderer/view holder, missing template or layout")
        end
        view, token, options = arguments
        return count(false, "explicit token or unknown options") unless @holder.call(token, NilClass) && @holder.call(options, Hash) &&
          options.size == 2 && options.key?(:action) && options.key?(:method)
        builder = TestCertificate::IVAR.bind_call(view, :@tag_builder)
        return count(false, "unknown view/builder holder") unless @holder.call(view, @view_class) &&
          @holder.call(builder, @builder_class) && TestCertificate::IVAR.bind_call(builder, :@view_context).equal?(view)
        true
      end
    end

    module Token
      # Keep the original prefix and each live operation in stock order.
      # This test-only continuation rechecks its own epoch/policy AFTER them;
      # production keeps the independently reviewed render implementation.
      def render(view, form_options)
        unit, id, epoch, holder, builder_class = self, @unit.fetch("id"), @epoch, @holder, @builder_class
        Sealed::VIEW_CONTEXT.bind_call(view) do
          unless defined?(protect_against_forgery?) && protect_against_forgery?
            ok = TestCertificate.allowed?(id) && epoch[0].zero?
            unit.count(ok)
            TestCertificateRender.branch(ok ? "empty_fast" : "empty_retired")
            next ""
          end
          token = form_authenticity_token(form_options: form_options.merge(authenticity_token: nil))
          name = request_forgery_protection_token.to_s
          autocomplete = ActionView::Base.remove_hidden_field_autocomplete
          builder = TestCertificate::IVAR.bind_call(view, :@tag_builder)
          unless TestCertificate.allowed?(id) && epoch[0].zero? &&
              holder.call(name, String) && holder.call(token, String) && holder.call(builder, builder_class) &&
              TestCertificate::IVAR.bind_call(builder, :@view_context).equal?(view)
            unit.count(false, "live token/name/builder or verification authority changed")
            TestCertificateRender.branch("continuation_fallback")
            attributes = {type: "hidden", name: name, value: token}
            attributes[:autocomplete] = "off" unless autocomplete
            next tag(:input, **attributes)
          end
          unit.count(true)
          TestCertificateRender.branch("protected_fast")
          suffix = autocomplete ? "" : ' autocomplete="off"'
          name = ERB::Util.unwrapped_html_escape(name)
          name = name.gsub('"', "&quot;") if name.include?('"')
          token = ERB::Util.unwrapped_html_escape(token)
          token = token.gsub('"', "&quot;") if token.include?('"')
          %(<input type="hidden" name="#{name}" value="#{token}"#{suffix} />).html_safe
        end
      end
    end
  end
end
