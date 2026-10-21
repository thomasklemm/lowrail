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

    # Explicit doctor diagnostic, never called by setup or a benchmark. A
    # disabled global return hook can affect future ISeqs too; disasm hides it.
    # Do not enable tracing (or YJIT) to diagnose an already booted process.
    def sticky_tracing(request: nil)
      report = {"status" => "unavailable", "leaf" => nil, "request" => nil,
        "scope" => "process-wide return counters; concurrent traced work may contribute; not a performance or clean-VM certificate"}
      return report.merge("reason" => "YJIT is not enabled; no interpreter inference") unless RubyVM::YJIT.enabled?
      unless RubyVM::YJIT.runtime_stats&.fetch(:exit_trace_leave, nil).is_a?(Integer)
        return report.merge("reason" => "exit_trace_leave unavailable; start a fresh diagnostic process with --yjit --yjit-stats=quiet")
      end
      report["enabled_tracepoints"] = ObjectSpace.each_object(TracePoint).count(&:enabled?)
      10.times { request.call } if request
      index = 0
      while index < 1000
        trace_leaf(19)
        index += 1
      end
      iseq = RubyVM::InstructionSequence.of(method(:trace_leaf))
      compiled = RubyVM::YJIT.insns_compiled(iseq)&.any? if RubyVM::YJIT.respond_to?(:insns_compiled)
      before = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave)
      index = 0
      while index < 1000
        trace_leaf(19)
        index += 1
      end
      exits = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave) - before
      report["leaf"] = {"calls" => index, "yjit_compiled" => compiled, "exit_trace_leave_delta" => exits}
      if request
        before = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave)
        response = request.call
        delta = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave) - before
        report["request"] = {"warmup_requests" => 10, "status" => response.status, "exit_trace_leave_delta" => delta}
      end
      if exits.negative? || report.dig("request", "exit_trace_leave_delta").to_i.negative?
        return report.merge("reason" => "counter reset during the diagnostic")
      end
      report["global_return_tracing_suspected"] = compiled ? exits.positive? : nil
      if exits.positive? || report.dig("request", "exit_trace_leave_delta").to_i.positive?
        report.merge("status" => "warning", "reason" => exits.positive? ?
          "Return-trace exits during the unrelated leaf control suggest a global hook, possibly disabled, or concurrent traced work. Restart without global boot tracing; no guilty gem is identified." :
          "Return tracing observed on the selected request; global stickiness is not established.")
      elsif compiled
        report.merge("status" => "not_observed", "reason" => "No return tracing observed; other events and unexercised paths are not covered")
      else
        report.merge("reason" => "unrelated leaf was not proven YJIT-compiled")
      end
    rescue StandardError => e
      report.merge("status" => "unavailable", "reason" => "#{e.class}: #{e.message.lines.first&.strip}")
    end

    def trace_leaf(value) = value * 7 + 13
    private_class_method :trace_leaf

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
