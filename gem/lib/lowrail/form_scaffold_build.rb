# frozen_string_literal: true

require "prism"
require_relative "form_scaffold"
require_relative "form_scaffold_inventory"

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
      sources = [__FILE__, File.join(__dir__, "form_scaffold.rb"), File.join(__dir__, "form_scaffold_inventory.rb"),
        File.join(__dir__, "sealed.rb"), File.join(__dir__, "templates.rb"), path, Rails.root.join("Gemfile.lock").to_s,
        *Dir[Rails.root.join("{app,config,lib}/**/*.{rb,yml}")]].uniq
      unit = {"pass" => pass, "kind" => "method", "target" => "ArticlesController#form_with", "facts" => [], "sites" => 1,
        "data" => {"sources" => sources.to_h { [_1, Manifest.sha256_file(_1)] }, "inventory" => inventory,
          "site" => {"source_location" => [path, line], "handler_sha256" => Digest::SHA256.hexdigest(code)}}}
      {units: [unit], files: [], ledger: [{"pass" => pass, "file" => path, "line" => line,
        "helper" => "form_with", "outcome" => "lowered"}]}
    rescue StandardError, ScriptError => error
      refusal.call("declined: #{error.class}: #{error.message.lines.first&.strip}")
    end
  end
end
