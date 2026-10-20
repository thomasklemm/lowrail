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

    # Relevance is separate from proof. In particular a test stack somewhere
    # above an app definition cannot excuse that definition. Unknown provenance
    # remains reviewable, never silently counted as compatible or incompatible.
    def self.classify(row, root:, environment:)
      test_file = ->(path) do
        path && (path.start_with?("#{root}/test/", "#{root}/spec/") ||
          path.match?(%r{/(?:minitest[^/]*/|rspec[^/]*/|capybara[^/]*/|webmock[^/]*/|mocha[^/]*/|rails-dom-testing[^/]*/)}) ||
          path.match?(%r{/lib/(?:active_support|active_record|active_job|action_controller|action_dispatch|action_mailer|action_cable|turbo)/(?:testing/|test_|fixtures\.rb|executor/test_helper\.rb|broadcastable/test_helper\.rb)}) ||
          path.match?(%r{/lib/(?:action_cable|action_view|rails)/(?:(?:channel|connection|generators)/)?(?:test_|testing/)}))
      end
      classify_source = ->(path) do
        if environment == "test" && test_file.call(path)
          "test_only"
        elsif path && path.start_with?("#{root}/app/", "#{root}/lib/")
          "production_relevant"
        else
          "needs_review"
        end
      end
      changes = row["changes"]
      parts = []
      if changes
        changes.fetch("methods", []).each do |method|
          path = method.dig("after", "source_location", 0)
          kind = classify_source.call(path)
          # Only additions from named Rails generators are materialization.
          # Replacement/removal/visibility changes are not excused by a stack.
          if !method["before"] && kind == "needs_review" && path&.match?(%r{/lib/(?:active_record|active_model)/.*(?:attribute|association|delegation)})
            kind = "lazy_materialization"
          end
          parts << {"part" => "method #{method['name']}", "kind" => kind, "source" => path}
        end
        changes.fetch("constant_sources", []).each do |constant|
          path = constant.dig("after_source", 0)
          kind = classify_source.call(path)
          if kind == "needs_review" && constant["after_kind"] == "value" &&
              [nil, "autoload"].include?(constant["before_kind"]) && path && origin(path, root)["kind"] == "gem"
            kind = "lazy_materialization"
          end
          parts << {"part" => "constant #{constant['name']}", "kind" => kind, "source" => path}
        end
        if (ancestors = changes["ancestors"])
          delta = (ancestors[0] - ancestors[1]) | (ancestors[1] - ancestors[0])
          kind = if environment == "test" && !delta.empty? && delta.all? { _1.match?(/::(?:Testing|TestHelper)(?:::|\z)|\A(?:Mocha|Minitest|RSpec::Mocks|WebMock)::/) }
            "test_only"
          else
            "needs_review"
          end
          parts << {"part" => "ancestors", "kind" => kind, "names" => delta}
        end
      else
        paths = [row["file"], *row.fetch("context", []).map { _1["file"] }]
        # Stop at the first app runtime frame or explicit test support frame;
        # an unrelated test runner frame further up is not causal evidence.
        path = paths.find { test_file.call(_1) || _1&.start_with?("#{root}/app/", "#{root}/lib/") }
        parts << {"part" => "candidate", "kind" => classify_source.call(path), "source" => path}
      end
      parts.each { |part| part["origin"] = origin(part["source"], root) if part["source"] }
      kinds = parts.map { _1.fetch("kind") }.uniq
      kind = kinds.size == 1 ? kinds.first : "mixed_or_needs_review"
      {"kind" => kind || "needs_review", "environment" => environment,
        "basis" => "source/changed-state classification, not a production coverage certificate", "parts" => parts}
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
