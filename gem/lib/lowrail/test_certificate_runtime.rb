# frozen_string_literal: true

require_relative "test_certificate"
require_relative "ar_instantiate"
require_relative "form_scaffold"
require_relative "test_certificate_render"

module Lowrail
  # These seams exist only for explicit test verification. Default and
  # production installers never load/prepend them.
  module TestCertificateRuntime
    module_function

    def install(manifest)
      TestCertificateRender.install
      selected = ENV["LOWRAIL_UNITS"]&.split(",")&.map { Integer(_1) }
      manifest.units.group_by { _1.fetch("pass") }.each do |pass, units|
        units = units.select { selected.include?(_1.fetch("id")) } if selected
        next if units.empty?
        runtime = {"active_record/instantiate" => ARInstantiate, "sealed/link_to" => Sealed,
          "sealed/form_scaffold" => FormScaffold, "sealed/token_tag" => TokenTag,
          "sealed/collection_render" => CollectionRender}.fetch(pass)
        runtime.install(units)
        if pass == "sealed/link_to"
          require_relative "templates"
          # Pending source can be delivered, but every fast predicate below
          # refuses. Otherwise first natural compilation would be missed.
          Templates.install(units.first.fetch("sealed").fetch("templates"))
        end
        TestCertificate.defer { runtime.activate }
      end
    end

    module Entry
      def valid?
        return false unless TestCertificate.allowed?(id)
        return false unless verification_builder_current?
        result = super
        if result
          TestCertificate.watch(id, [klass, klass.singleton_class])
          result = TestCertificate.allowed?(id)
        end
        result
      end

      def current? = TestCertificate.allowed?(id) && verification_builder_current? && super

      private

      # 8.1's audited getter memoizes this exact object. A schema reset must
      # retire a hoisted recipe even if a custom reset bypassed Rails' hooks.
      # No getter is invoked, and the old recipe is never silently reauthorized.
      def verification_builder_current?
        return true unless @builder
        return TestCertificate.retire(id, "verification_schema_epoch_changed") unless AR.epoch(klass) == @epoch
        TestCertificate::IVAR.bind_call(klass, :@attributes_builder).equal?(@builder) ||
          TestCertificate.retire(id, "verification_attributes_builder_replaced")
      end
    end

    module Link
      def activate
        return false unless @unit && TestCertificate.allowed?(@unit.fetch("id"))
        super
        if Sealed::ACTIVE[0]
          holders = [@view_class, ActionView::Helpers::TagHelper::TagBuilder, String, Hash, ERB::Util.singleton_class]
          TestCertificate.watch(@unit.fetch("id"), holders)
        end
      end

      def view?(view) = @unit && TestCertificate.allowed?(@unit.fetch("id")) && super

      def link?(...) = TestCertificate.allowed?(@unit.fetch("id")) ? super : count(false)

      def request_allowed? = @unit && TestCertificate.allowed?(@unit.fetch("id")) && super
    end

    module Form
      def activate
        return false unless @unit && TestCertificate.allowed?(@unit.fetch("id"))
        super
      end

      def admitted? = @unit && TestCertificate.allowed?(@unit.fetch("id")) && super

      def observe(view, block)
        if @unit && block && FormScaffold::BLOCK_SOURCE.bind_call(block) == @data.fetch("site").fetch("source_location")
          Stats.count(@unit.fetch("id"), false)
        end
        return unless @unit && TestCertificate.allowed?(@unit.fetch("id"))
        # This is the existing natural-render seam. No Inventory/check or
        # passive_certificate call is permitted in runtime admission.
        Sealed.activate unless Sealed::ACTIVE[0]
        super
        if @active
          TestCertificate.watch(@unit.fetch("id"), [@view_class, @model_class, @model_class.singleton_class,
            @article_class, @article_class.singleton_class, @form_class, @builder_class, String, Hash])
        end
      end

      def valid?(...) = TestCertificate.allowed?(@unit.fetch("id")) ? super : count(false, "verification authority retired")
    end

    module GuardGate
      def validate(id, **options) = TestCertificate.allowed?(id) && super
    end
  end

  ARInstantiate::Entry.prepend(TestCertificateRuntime::Entry)
  Sealed.singleton_class.prepend(TestCertificateRuntime::Link)
  FormScaffold.singleton_class.prepend(TestCertificateRuntime::Form)
end
