# frozen_string_literal: true

require "prism"
require_relative "seal_rules"

module Lowrail
  # Deliberately syntactic hints. No claim of reachability, purity, or a complete
  # call graph. Boot-only definitions must not be reported as proven violations.
  module SealStatic
    class Scan < Prism::Visitor
      attr_reader :findings

      def initialize(source, file:, root:)
        @source, @file, @root = source, file, root
        @methods, @classes, @findings = [], [], []
      end

      def boot?
        @methods.empty? && (@file.include?("/config/") || @file.end_with?("/config.ru") || !@classes.empty?)
      end

      def hint(rule, node, detail)
        @findings << SealRules.finding(rule, confidence: "hint", file: @file,
          line: node.location.start_line, root: @root, target: @classes.join("::"), detail: detail)
      end

      def visit_class_node(node)
        @classes << node.constant_path.location.slice
        super
      ensure
        @classes.pop
      end

      def visit_module_node(node)
        @classes << node.constant_path.location.slice
        super
      ensure
        @classes.pop
      end

      def visit_def_node(node)
        case node.name
        when :method_missing, :respond_to_missing?
          hint("SEAL006", node, "Dynamic dispatch hook; needs path/receiver certification, not a global ban.")
        when :to_param
          hint("SEAL003", node, "Custom conversion is not automatically impure; review its effects and inputs.")
        when :default_url_options
          if node.location.slice.match?(/\b(?:request|Current)\b/)
            hint("SEAL002", node, "URL defaults mention request/Current; no request-invariance certificate.")
          end
        end
        @methods << node.name
        super
      ensure
        @methods.pop
      end

      def visit_call_node(node)
        name = node.name
        receiver = node.receiver&.location&.slice.to_s
        write = name == :[]= || name.to_s.match?(/\A\w+[=!]\z/)
        if %i[class_eval module_eval instance_eval eval].include?(name) &&
            node.arguments&.arguments&.any? { Prism::StringNode === _1 || Prism::InterpolatedStringNode === _1 }
          hint("SEAL001", node, "String evaluation hides definitions; materialize before seal and review generated code.")
        elsif %i[define_method define_singleton_method alias_method prepend include extend remove_method undef_method const_set remove_const].include?(name) && !boot?
          hint("SEAL001", node, "Definition/lookup mutation outside a boot class/config body.")
        elsif %i[send public_send __send__].include?(name) && !boot?
          hint("SEAL006", node, "Dynamic dispatch needs a finite certified receiver/target set.")
        elsif %i[subscribe monotonic_subscribe subscribed].include?(name) && receiver.include?("Notifications") &&
            !(@file.include?("/config/initializers/") && @methods.empty?)
          hint("SEAL004", node, "Subscription outside an initializer; check whether it executes after seal.")
        elsif !boot? && receiver.match?(/(?:PRE_CONTENT_STRINGS|TAG_TYPES)/) &&
            (write || %i[clear delete replace store <<].include?(name))
          hint("SEAL008", node, "Framework table/default write; frozen stock TAG_TYPES is not a mutable replacement.")
        elsif receiver.match?(/(?:TracePoint|RubyVM::InstructionSequence)/) || %i[caller caller_locations set_trace_func].include?(name)
          hint("SEAL009", node, "Delivery internals are observable; opt out of sealed delivery unless this observation is excluded by contract.")
        elsif !boot? && ((write && receiver.match?(/(?:\bconfig\b|\broutes\b|default_url_options)/)) ||
            %i[draw reload_routes! clear_cache clear_cache!].include?(name))
          hint("SEAL005", node, "Potential runtime config/route/resolver write; receiver and timing need review.")
        end
        super
      end

      def visit_alias_method_node(node)
        hint("SEAL001", node, "Alias outside a boot class body.") unless boot?
        super
      end
    end

    def self.source(source, file:, root:)
      return [SealRules.finding("SEAL007", confidence: "hint", file: file, line: 1, root: root,
        target: file.delete_prefix("#{root}/"))] if file.end_with?(".erb") && !source.match?(/<%#\s*locals:\s*\(/)
      return [] if file.end_with?(".erb")
      parsed = Prism.parse(source)
      raise "#{file}: Prism parse failed: #{parsed.errors.first.message}" unless parsed.success?
      scan = Scan.new(source, file: file, root: root)
      parsed.value.accept(scan)
      scan.findings
    end

    def self.run(root)
      require "json"
      app_files = %w[app config lib].flat_map { Dir.glob(File.join(root, _1, "**/*.{rb,erb}")) }
      # Exact files named by dynamic evidence, not a broad scan of all gems.
      dynamic_path = File.join(root, ".lowrail/seal.json")
      dynamic = File.file?(dynamic_path) ? JSON.parse(File.read(dynamic_path)).fetch("ledger") : []
      proof_sources = ->(row) do
        changes = row["changes"]
        if changes
          [*changes.fetch("methods", []).filter_map { _1.dig("after", "source_location", 0) },
            *changes.fetch("constant_sources", []).filter_map { _1.dig("after_source", 0) }].uniq
        elsif row["location_kind"] == "checkpoint; mutation source unknown" || row["operation"] == "snapshot_difference"
          []
        else
          [row["file"]].compact
        end
      end
      gem_files = dynamic.flat_map { |row| [row["observed_at"]&.sub(/:\d+\z/, ""), *proof_sources.call(row)] }.compact
        .select { |file| File.file?(file) && file.end_with?(".rb") && SealRules.origin(file, root)["kind"] == "gem" }.uniq
      errors = []
      hints = (app_files + gem_files).uniq.sort.flat_map do |file|
        source(File.read(file), file: file, root: root)
      rescue StandardError => error
        errors << error.message
        []
      end
      # An unmatched hint is unobserved, not false. Dynamic runtime operations
      # and source hints have different coverage. Compare rule + source file.
      hinted = hints.map { [_1["rule"], _1["file"]] }.uniq
      proofs = dynamic.select { _1["confidence"] == "proven" }
      proven = proofs.flat_map { |row| proof_sources.call(row).map { [row["rule"], _1] } }.uniq
      matched = hinted & proven
      {"format" => 1, "rules" => SealRules::RULES, "hints" => hints, "errors" => errors,
        "scope" => "app/config/lib plus gem files named by dynamic evidence (not all dependencies)",
        "comparison" => {"basis" => "unique rule/changed-source-file pairs; candidate callbacks are not proof; absence of evidence is not refutation",
          "proofs_without_source" => proofs.count { proof_sources.call(_1).empty? },
          "hint_pairs" => hinted.size, "proven_pairs" => proven.size, "matched_pairs" => matched.size,
          "unobserved_hint_pairs" => hinted - proven, "dynamic_only_pairs" => proven - hinted,
          "unmatched_rate" => (hinted | proven).empty? ? nil : 1.0 - matched.size.fdiv((hinted | proven).size),
          "refuted_hints" => [], "semantic_disagreement_rate" => nil}}
    end
  end
end
