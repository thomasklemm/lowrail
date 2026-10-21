# frozen_string_literal: true

require_relative "render_units"
require_relative "form_scaffold_inventory"

module Lowrail
  # Build-only stock audit. Capture natural holders BEFORE any synthetic form
  # inventory; none of that inventory can provide a runtime witness.
  module TestCertificateRenderBuild
    module_function

    def capture
      controller = Lowrail.loaded_constant("ArticlesController")
      view = controller && TestCertificate::IVAR.bind_call(controller, :@view_context_class)
      builder = Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TagBuilder")
      renderer = Lowrail.loaded_constant("ActionView::CollectionRenderer")
      {TokenTag::PASS => view && builder && {view: view, type: builder},
        CollectionRender::PASS => view && renderer && {view: view, type: renderer}}
    end

    def build(pass, context:, denied:)
      refusal = ->(reason) { {units: [], files: [], ledger: [{"pass" => pass, "outcome" => "refused", "reason" => reason}]} }
      return refusal.call("denylisted by verify --bisect") if denied.any? { _1["pass"] == pass }
      return refusal.call("verification render holders not naturally available") unless context
      inventory = FormScaffoldInventory.check(verification_test: true)
      return refusal.call(inventory) if String === inventory
      controller = Lowrail.loaded_constant("ArticlesController")
      return refusal.call("natural view class changed during build-only audit") unless
        TestCertificate::IVAR.bind_call(controller, :@view_context_class).equal?(context.fetch(:view))
      native = Lowrail.loaded_constant("Lowrail::Native")
      exact = native&.method(:exact_class?)
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return refusal.call("missing stock actual-holder primitive") unless exact && binary && exact.source_location.nil? &&
        exact.owner.equal?(native.singleton_class) && exact.original_name == :exact_class?
      view = context.fetch(:view)
      methods = if pass == TokenTag::PASS
        {"view" => [view, %i[token_tag tag tag_builder ensure_valid_html5_tag_name]],
          "ActionView::Helpers::TagHelper::TagBuilder" => [context.fetch(:type), %i[tag_options tag_option]],
          "Hash" => [Hash, %i[merge each_pair empty? blank? [] []= default default_proc key? size]],
          "String" => [String, %i[to_s html_safe html_safe? gsub include? empty? blank? match? nil? <<]],
          "NilClass" => [NilClass, %i[nil? == !=]],
          "Symbol" => [Symbol, %i[to_s blank? empty? nil?]], "Regexp" => [Regexp, %i[match?]]}
      else
        {"ActionView::CollectionRenderer" => [context.fetch(:type), %i[collection_with_template]]}
      end
      facts = methods.flat_map do |name, (type, names)|
        names.map { audit(type, name, _1) }
      end
      if pass == TokenTag::PASS
        %i[unwrapped_html_escape xml_name_escape].each { facts << audit(ERB::Util, "ERB::Util", _1, singleton: true) }
        [Array, Hash, Regexp].each { facts << audit(_1, _1.name, :===, singleton: true) }
      end
      observer = pass == TokenTag::PASS ? TokenTag::Variant.instance_method(:token_tag) :
        CollectionRender::Variant.instance_method(:collection_with_template)
      source, line = observer.source_location
      expected = FormScaffoldInventory.find(RubyVM::InstructionSequence.compile_file(source), observer.original_name.to_s, line)
      return refusal.call("non-stock symmetric render observer") unless expected &&
        Sealed.signature(observer, sequence: expected.to_a) == Sealed.signature(observer)
      sources = [binary, source, *facts.flat_map { _1.fetch("chain").filter_map { |body| body.dig("source_location", 0) } }].uniq.select { File.file?(_1) }
      data = {"version" => 1, "native_method" => Sealed.signature(exact), "observer" => Sealed.signature(observer),
        "methods" => facts, "sources" => sources.to_h { [_1, Manifest.sha256_file(_1)] }}
      {units: [{"pass" => pass, "kind" => "runtime", "target" => pass == TokenTag::PASS ? "ArticlesController#token_tag" :
        "ActionView::CollectionRenderer#collection_with_template", "facts" => [], "verification_render" => data}],
        files: [], ledger: [{"pass" => pass, "outcome" => "lowered", "reason" => "pending first complete original operation"}]}
    rescue StandardError, ScriptError => error
      refusal.call("verification render audit: #{error.class}: #{error.message.lines.first&.strip}")
    end

    def audit(type, holder, name, singleton: false)
      method = singleton ? type.method(name) : type.instance_method(name)
      method = method.super_method if [TokenTag::Variant, CollectionRender::Variant].include?(method.owner)
      chain = []
      while method
        fact = FormScaffoldInventory.stock_fact(method)
        # These C methods are owned by the pinned Ruby/ERB runtime. Do not
        # accept an arbitrary Ruby body or an unknown native owner.
        if !fact && method.source_location.nil? && !RubyVM::InstructionSequence.of(method) &&
            [NilClass, Regexp, ERB::Util.singleton_class].include?(method.owner)
          fact = FormScaffoldInventory.runtime_fact(method)
        end
        raise "custom #{holder}##{name}" unless fact
        chain << fact
        method = method.super_method
      end
      {"holder" => holder, "method" => name.to_s, "singleton" => singleton,
        "visibility" => Sealed.visibility(singleton ? type.singleton_class : type, name), "chain" => chain}
    end
  end
end
