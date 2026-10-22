# frozen_string_literal: true

require_relative "render_units"
require_relative "form_scaffold_inventory"

module Lowrail
  module RenderUnitsBuild
    COLLECTION_SOURCE = "77bfca2ca74e35adf0633c414fc13dda6a07041d3d6361c4c9324ef6edaf424f"
    module_function

    def build(pass, denied:)
      refusal = ->(reason) { {units: [], files: [], ledger: [{"pass" => pass, "outcome" => reason}]} }
      return refusal.call("denylisted by verify --bisect") if denied.any? { _1["pass"] == pass }
      # Collection rendering passes the view through unchanged. It folds no
      # form/model/helper behavior, so it needs no blog constructor inventory.
      inventory = pass == CollectionRender::PASS ? collection_inventory : FormScaffoldInventory.check
      return refusal.call(inventory) if String === inventory
      context = Sealed.view_context_fact
      return refusal.call("custom view context dispatch; keep original") unless context
      native = Lowrail.loaded_constant("Lowrail::Native")
      return refusal.call("missing actual-holder primitive; run rake compile") unless native
      exact = native.method(:exact_class?)
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return refusal.call("custom actual-holder primitive") unless binary && exact.source_location.nil? &&
        exact.owner.equal?(native.singleton_class) && exact.original_name == :exact_class?
      controller = "ArticlesController" if pass == TokenTag::PASS
      view = ArticlesController.view_context_class if controller
      methods = if pass == TokenTag::PASS
        {"view" => [view, %i[token_tag tag tag_builder]],
          "ActionView::Helpers::TagHelper::TagBuilder" => [ActionView::Helpers::TagHelper::TagBuilder, %i[tag_options tag_option]],
          "String" => [String, %i[to_s html_safe html_safe? gsub include?]], "Hash" => [Hash, %i[merge]], "Symbol" => [Symbol, %i[to_s]]}
      else
        {"ActionView::CollectionRenderer" => [ActionView::CollectionRenderer, %i[collection_with_template]]}
      end
      facts = methods.flat_map do |name, (type, names)|
        names.map do |method_name|
          fact = pass == CollectionRender::PASS ? inventory.fetch("method") :
            FormScaffoldInventory.stock_fact(type.instance_method(method_name))
          return refusal.call("custom #{name}##{method_name}; keep original") unless fact
          {"holder" => name, "method" => method_name.to_s,
            "body" => fact.merge("visibility" => Sealed.visibility(type, method_name))}
        end
      end
      if pass == TokenTag::PASS
        %i[unwrapped_html_escape xml_name_escape].each do |method_name|
          fact = FormScaffoldInventory.stock_fact(ERB::Util.method(method_name))
          return refusal.call("custom ERB escaping; keep original") unless fact
          facts << {"holder" => "ERB::Util", "method" => method_name.to_s, "singleton" => true, "body" => fact}
        end
      end
      sources = [__FILE__, File.join(__dir__, "render_units.rb"), File.join(__dir__, "setup.rb"),
        File.join(__dir__, "form_scaffold_inventory.rb"), File.join(__dir__, "sealed.rb"), binary,
        Rails.root.join("Gemfile.lock").to_s, *Dir[Rails.root.join("{app,config,lib}/**/*.{rb,yml,erb}")],
        *facts.filter_map { _1.dig("body", "source_location", 0) }].uniq.select { File.file?(_1) }
      observer = pass == TokenTag::PASS ? TokenTag::Variant.instance_method(:token_tag) :
        CollectionRender::Variant.instance_method(:collection_with_template)
      data = {"version" => 1, "application_class" => inventory.fetch("application_class"),
        "controller" => controller,
        "native_method" => Sealed.signature(exact), "observer" => Sealed.signature(observer), "view_context" => context,
        "sources" => sources.to_h { [_1, Manifest.sha256_file(_1)] }, "methods" => facts}
      {units: [{"pass" => pass, "kind" => "method", "target" => pass == TokenTag::PASS ? "ArticlesController#token_tag" :
        "ActionView::CollectionRenderer#collection_with_template", "facts" => [], "data" => data}], files: [],
        ledger: [{"pass" => pass, "outcome" => "lowered"}]}
    rescue StandardError, ScriptError => error
      refusal.call("declined: #{error.class}: #{error.message.lines.first&.strip}")
    end

    def collection_inventory
      return "requires eager-loaded production Ruby 4.0.7 / Rails 8.1.4" unless ENV["RAILS_ENV"] == "production" &&
        RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" && Rails.application.config.eager_load
      type = ActionView::CollectionRenderer
      method = type.instance_method(:collection_with_template)
      path = File.join(Gem.loaded_specs.fetch("actionview").full_gem_path, "lib/action_view/renderer/collection_renderer.rb")
      return "non-stock collection renderer source; keep original" unless Manifest.sha256_file(path) == COLLECTION_SOURCE
      return "custom collection renderer; keep original" unless method.owner.equal?(type) && method.source_location&.first == path
      sequence = FormScaffoldInventory.find(RubyVM::InstructionSequence.compile_file(method.source_location.first),
        "collection_with_template", method.source_location.last)
      return "custom collection renderer body; keep original" unless sequence &&
        Sealed.signature(method) == Sealed.signature(method, sequence: sequence.to_a)
      {"application_class" => Rails.application.class.name, "method" => Sealed.signature(method)}
    end
  end

  module TokenTagBuild
    def self.build(denied: []) = RenderUnitsBuild.build(TokenTag::PASS, denied: denied)
  end

  module CollectionRenderBuild
    def self.build(denied: []) = RenderUnitsBuild.build(CollectionRender::PASS, denied: denied)
  end
end
