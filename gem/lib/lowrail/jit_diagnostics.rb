# frozen_string_literal: true

module Lowrail
  # Opt-in, untimed diagnostics. Neither JIT exposes per-ISeq exit,
  # invalidation or execution-ratio counters through its public Ruby API.
  module JitDiagnostics
    module_function

    def record(iseq, path, units)
      ids = units.select { _1["file"] == path && _1["method"].to_s.split(/[.#]/).last == iseq.label }.map { _1.fetch("id") }
      (@iseqs ||= []) << [iseq, ids] unless ids.empty?
      iseq.each_child { |child| record(child, path, units) }
    end

    def snapshot
      jits = %i[YJIT ZJIT].to_h do |name|
        jit = RubyVM.const_defined?(name, false) ? RubyVM.const_get(name, false) : nil
        enabled = jit && jit.enabled?
        raw = if enabled
          name == :ZJIT ? jit.stats : jit.runtime_stats
        end
        counters = (raw || {}).each_with_object({}) do |(key, value), result|
          result[key.to_s] = value.is_a?(Float) && !value.finite? ? nil : value if value.is_a?(Numeric)
        end
        [name.to_s.downcase, { "enabled" => !!enabled, "scope" => "process lifetime, including boot and diagnostics",
          "counters" => counters, "side_exit_count" => counters["side_exit_count"],
          "invalidation_count" => counters["invalidation_count"], "ratio_in_jit" => counters["ratio_in_#{name.to_s.downcase}"] }]
      end
      annotations = (@iseqs || []).map do |iseq, ids|
        compiled = RubyVM::YJIT.insns_compiled(iseq) if jits.fetch("yjit").fetch("enabled") && RubyVM::YJIT.respond_to?(:insns_compiled)
        { "path" => iseq.path, "label" => iseq.label, "line" => iseq.first_lineno,
          "candidate_unit_ids" => ids, "yjit_compiled_instruction_versions" => compiled && compiled.size / 2,
          "zjit_compiled_instruction_versions" => nil }
      end
      { "pid" => Process.pid, "ruby" => RUBY_DESCRIPTION, "jits" => jits,
        "delivered_method_iseqs" => annotations,
        "per_iseq_counters" => nil,
        "limitations" => "Per-ISeq exits/invalidations/ratios and ZJIT compilation attribution unavailable; file-delivered named methods only, not runtime/template variants. Missing counters are null, not zero. Retains diagnostic ISeq wrappers." }
    rescue StandardError => e
      { "pid" => Process.pid, "ruby" => RUBY_DESCRIPTION, "error" => "#{e.class}: #{e.message}" }
    end
  end
end
