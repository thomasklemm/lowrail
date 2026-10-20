# frozen_string_literal: true

module Lowrail
  # One catalog for static hints, exercised violations, doctor and MCP.
  module SealRules
    RULES = {
      "SEAL001" => ["Post-seal method, constant, visibility or ancestor mutation",
        "Move definitions and lazy generation before sealing, or exclude the target."],
      "SEAL002" => ["Request-dependent default_url_options",
        "Pass request/Current-dependent URL options explicitly, or keep URL generation live."],
      "SEAL003" => ["Custom to_param needs a purity certificate",
        "Use stock to_param or a pure conversion of explicit model values; otherwise keep the helper live."],
      "SEAL004" => ["Notifications subscriber set changes after sealing",
        "Register subscribers before sealing; retain all existing event delivery."],
      "SEAL005" => ["Runtime configuration, route or resolver mutation",
        "Move changes to boot and restart to publish them; pass runtime state as explicit inputs."],
      "SEAL006" => ["Unresolved dynamic dispatch in a certified path",
        "Use an explicit finite dispatch table with certified targets, or keep this call live."],
      "SEAL007" => ["Template locals shape is not declared",
        "Declare strict locals where feasible, or certify a finite set of locals shapes."],
      "SEAL008" => ["Certified framework table contents or defaults changed",
        "Set table contents/defaults before sealing, or retain the table-consuming call live and exclude its expansion."],
      "SEAL009" => ["Production code observes generated delivery internals",
        "Keep stack/TracePoint/ISeq/old-method-handle inspection out of certified production paths, or refuse sealed delivery."]
    }.transform_values { |explanation, remedy| {"explanation" => explanation, "remedy" => remedy}.freeze }.freeze
    PATTERNS = {"method_or_constant_mutation" => "SEAL001", "notifications_changed" => "SEAL004",
      "config_changed" => "SEAL005", "routes_changed" => "SEAL005",
      "framework_table_changed" => "SEAL008"}.freeze

    def self.origin(file, root, gems = Gem.loaded_specs.values)
      # Gem sources can live in app/vendor; classify the longest gem prefix first.
      spec = gems.select { |gem| file.start_with?("#{gem.full_gem_path}/") }.max_by { _1.full_gem_path.length }
      return {"kind" => "gem", "name" => spec.name, "version" => spec.version.to_s} if spec
      return {"kind" => "app"} if file.start_with?("#{root}/")
      {"kind" => "ruby_or_external"}
    end

    def self.finding(rule, confidence:, file:, line:, root:, gems: Gem.loaded_specs.values, **detail)
      origin = origin(file, root, gems)
      advice = if origin["kind"] == "gem"
        "Open an upstream issue for #{origin['name']} #{origin['version']}, or exclude the certified target; do not rewrite app code to patch this gem."
      else
        RULES.fetch(rule).fetch("remedy")
      end
      {"rule" => rule, "confidence" => confidence, "file" => file, "line" => line,
        "origin" => origin, **RULES.fetch(rule), "remedy" => advice, **detail.transform_keys(&:to_s)}
    end
  end
end
