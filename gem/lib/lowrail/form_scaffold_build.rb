# frozen_string_literal: true

require "prism"
require_relative "form_scaffold"
require_relative "form_scaffold_inventory"
require_relative "form_scaffold_admission"

module Lowrail
  module FormScaffoldBuild
    # First generator domain: this exact literal blank-comment block. Changes
    # are refusals, not permission to copy a stale scaffold into a new form.
    SOURCE = <<~'ERB'.freeze
      <%= form_with model: [@article, Comment.new], class: "space-y-4" do |form| %>
        <div>
          <%= form.label :commenter, class: "block font-medium" %>
          <%= form.text_field :commenter, class: "block w-full border rounded p-2" %>
        </div>
        <div>
          <%= form.label :body, class: "block font-medium" %>
          <%= form.text_area :body, rows: 3, class: "block w-full border rounded p-2" %>
        </div>
        <%= form.submit "Add Comment", class: "bg-blue-600 text-white px-4 py-2 rounded" %>
      <% end %>
    ERB

    module_function

    def build(denied: [])
      pass = FormScaffold::PASS
      path = Rails.root.join("app/views/articles/show.html.erb").to_s
      refusal = ->(reason) { {units: [], files: [], ledger: [{"pass" => pass, "file" => path,
        "helper" => "form_with", "outcome" => reason}]} }
      return refusal.call("denylisted by verify --bisect") if denied.any? { _1["pass"] == pass }
      inventory = FormScaffoldInventory.check
      return refusal.call(inventory) if String === inventory
      return refusal.call("unknown template; only the literal blank-comment form is certified") unless File.file?(path)
      source = File.read(path)
      return refusal.call("unknown form shape; use the fixed blank-comment scaffold or keep Rails") unless source.scan(SOURCE).size == 1
      line = source[0...source.index(SOURCE)].count("\n") + 1
      code = FormScaffoldInventory.template(path)
      parsed = Prism.parse("def __lowrail_form__;#{code}\nend")
      return refusal.call("unsupported compiled template") unless parsed.success?
      calls = []
      visit = ->(node) {
        calls << node if Prism::CallNode === node && node.name == :form_with && node.receiver.nil?
        node.compact_child_nodes.each { visit.call(_1) }
      }
      visit.call(parsed.value)
      return refusal.call("unknown compiled form site") unless calls.size == 1 && Prism::BlockNode === calls.first.block
      passive = passive_certificate(path, line)
      sources = [__FILE__, File.join(__dir__, "form_scaffold.rb"), File.join(__dir__, "form_scaffold_inventory.rb"),
        File.join(__dir__, "form_scaffold_admission.rb"), File.join(__dir__, "setup.rb"),
        File.join(__dir__, "sealed.rb"), File.join(__dir__, "templates.rb"), passive.delete("native_file"), path, Rails.root.join("Gemfile.lock").to_s,
        *Dir[Rails.root.join("{app,config,lib}/**/*.{rb,yml}")]].uniq
      unit = {"pass" => pass, "kind" => "method", "target" => "ArticlesController#form_with", "facts" => [], "sites" => 1,
        "data" => {"sources" => sources.to_h { [_1, Manifest.sha256_file(_1)] }, "inventory" => inventory,
          "passive" => passive,
          "site" => {"source_location" => [path, line], "handler_sha256" => Digest::SHA256.hexdigest(code)}}}
      {units: [unit], files: [], ledger: [{"pass" => pass, "file" => path, "line" => line,
        "helper" => "form_with", "outcome" => "lowered"}]}
    rescue StandardError, ScriptError => error
      refusal.call("declined: #{error.class}: #{error.message.lines.first&.strip}")
    end

    # These synthetic operations remain strictly build-time. Runtime admission
    # compares the already-running block, never reconstructs this template.
    def passive_certificate(path, line)
      native = Lowrail.loaded_constant("Lowrail::Native")
      raise ArgumentError, "missing actual-holder primitive; run rake compile" unless native
      exact = native.method(:exact_class?)
      raise ArgumentError, "custom actual-holder primitive" unless exact.source_location.nil? &&
        exact.owner.equal?(native.singleton_class) && exact.original_name == :exact_class?
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      raise ArgumentError, "actual-holder binary missing" unless binary
      readers = {Comment => :__class_attr___callbacks, ArticlesController => :__class_attr_default_url_options}.to_h do |type, name|
        method = type.method(name)
        sequence = RubyVM::InstructionSequence.of(method)
        raise ArgumentError, "custom cache reader #{type.name}.#{name}" unless sequence &&
          method.source_location == [File.join(Gem.loaded_specs.fetch("activesupport").full_gem_path, "lib/active_support/class_attribute.rb"), 15] &&
          sequence.to_a.last.grep(Array) == [[:getlocal_WC_1, 3], [:leave]] && sequence.to_a.fetch(11).empty?
        ["#{type.name}.#{name}", Sealed.signature(method)]
      end
      resolver = ArticlesController.view_paths.paths.find { _1.instance_of?(ActionView::FileSystemResolver) && path.start_with?("#{_1.path}/") }
      raise ArgumentError, "unknown template resolver" unless resolver
      template = resolver.send(:build_unbound_template, path).bind_locals([])
      view = ArticlesController.new.view_context
      template.send(:compile!, view)
      method = view.class.instance_method(template.method_name)
      block = FormScaffoldInventory.find(RubyVM::InstructionSequence.of(method), "block in #{template.method_name}", line)
      raise ArgumentError, "unknown compiled form block" unless block
      polymorphic = ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder
      key = polymorphic.get(nil, :path).instance_variable_get(:@key_strategy)
      {"version" => 1, "native_file" => binary, "native_method" => Sealed.signature(exact), "readers" => readers,
        "translations" => FormScaffoldAdmission.translations(I18n.backend, exact),
        "polymorphic_key" => Sealed.signature(key.method(:call), sequence: RubyVM::InstructionSequence.of(key).to_a),
        "block_iseq" => FormScaffoldAdmission.block_signature(block, template.method_name)}
    end
  end
end
