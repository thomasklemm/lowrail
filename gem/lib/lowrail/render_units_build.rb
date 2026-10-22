# frozen_string_literal: true

require_relative "render_units"
require_relative "form_scaffold_inventory"

module Lowrail
  module RenderUnitsBuild
    module_function

    def build(pass, denied:)
      refusal = ->(reason) { {units: [], files: [], ledger: [{"pass" => pass, "outcome" => reason}]} }
      return refusal.call("denylisted by verify --bisect") if denied.any? { _1["pass"] == pass }
      return refusal.call("requires production Ruby 4.0.7 / Rails 8.1.4") unless
        ENV["RAILS_ENV"] == "production" && RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      reason = FormScaffoldInventory.source_inventory(gems: pass == TokenTag::PASS ? %w[actionview activesupport] : %w[actionview])
      return refusal.call(reason) if reason
      context = Sealed.view_context_fact
      return refusal.call("custom view context dispatch; keep original") unless context
      native = Lowrail.loaded_constant("Lowrail::Native")
      return refusal.call("missing actual-holder primitive; run rake compile") unless native
      exact = native.method(:exact_class?)
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return refusal.call("custom actual-holder primitive") unless binary && exact.source_location.nil? &&
        exact.owner.equal?(native.singleton_class) && exact.original_name == :exact_class?
      controllers = {}
      ledger = []
      if pass == TokenTag::PASS
        ActionController::Base.descendants.sort_by { _1.name.to_s }.each do |controller|
          next unless controller.name && Lowrail.loaded_constant(controller.name).equal?(controller)
          view = controller.view_context_class
          names = %i[token_tag tag tag_builder]
          expected = names.to_h do |name|
            method = view.instance_method(name)
            fact = FormScaffoldInventory.stock_fact(method)
            [name.to_s, fact && fact.merge("visibility" => Sealed.visibility(view, name))]
          end
          if expected.values.all?
            controllers[controller.name] = expected
          else
            ledger << {"pass" => pass, "target" => controller.name, "outcome" => "custom token/tag helper; keep original"}
          end
        end
        return refusal.call("no loaded controller with stock token/tag helpers") if controllers.empty?
      end
      methods = if pass == TokenTag::PASS
        {"ActionView::Helpers::TagHelper::TagBuilder" => [ActionView::Helpers::TagHelper::TagBuilder, %i[tag_options tag_option]],
          "String" => [String, %i[to_s html_safe html_safe? gsub include?]], "Hash" => [Hash, %i[merge]], "Symbol" => [Symbol, %i[to_s]]}
      else
        {"ActionView::CollectionRenderer" => [ActionView::CollectionRenderer, %i[collection_with_template]]}
      end
      facts = methods.flat_map do |name, (type, names)|
        names.map do |method_name|
          fact = FormScaffoldInventory.stock_fact(type.instance_method(method_name))
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
        File.join(__dir__, "guard.rb"),
        File.join(__dir__, "form_scaffold_inventory.rb"), File.join(__dir__, "sealed.rb"), binary,
        Rails.root.join("Gemfile.lock").to_s, *Dir[Rails.root.join("{app,config,lib}/**/*.{rb,yml,erb}")],
        *facts.filter_map { _1.dig("body", "source_location", 0) },
        *controllers.values.flat_map { |entries| entries.values.filter_map { _1.dig("source_location", 0) } }].uniq.select { File.file?(_1) }
      observer = pass == TokenTag::PASS ? TokenTag::Variant.instance_method(:token_tag) :
        CollectionRender::Variant.instance_method(:collection_with_template)
      data = {"version" => 2, "application_class" => Rails.application.class.name, "controllers" => controllers,
        "native_method" => Sealed.signature(exact), "observer" => Sealed.signature(observer), "view_context" => context,
        "sources" => sources.to_h { [_1, Manifest.sha256_file(_1)] }, "methods" => facts}
      {units: [{"pass" => pass, "kind" => "method", "target" => pass == TokenTag::PASS ? "ActionView::Helpers::UrlHelper#token_tag" :
        "ActionView::CollectionRenderer#collection_with_template", "facts" => [], "data" => data}], files: [],
        ledger: ledger + [{"pass" => pass, "outcome" => "lowered"}]}
    rescue StandardError, ScriptError => error
      refusal.call("declined: #{error.class}: #{error.message.lines.first&.strip}")
    end
  end

  module TokenTagBuild
    def self.build(denied: []) = RenderUnitsBuild.build(TokenTag::PASS, denied: denied)
  end

  module CollectionRenderBuild
    def self.build(denied: []) = RenderUnitsBuild.build(CollectionRender::PASS, denied: denied)
  end
end
