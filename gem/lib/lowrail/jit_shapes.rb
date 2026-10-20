# frozen_string_literal: true

module Lowrail
  # Performance hints, never a correctness certificate or a reason to remove
  # a fallback. Inspect bytecode without evaluating it or enabling tracing.
  module JitShapes
    module_function

    def warning(target, site, line, reason, detail)
      { "pass" => "jit/shape", "target" => target, "site" => site, "line" => line,
        "outcome" => "warning", "reason" => reason, "detail" => detail, "copies" => 1 }
    end

    def check(iseq, target)
      data = iseq.to_a
      unless data[0] == "YARVInstructionSequence/SimpleDataFormat" && data[1] == 4
        return [warning(target, iseq.label, iseq.first_lineno, "uninspected", "unknown ISeq serialization")]
      end
      warnings = []
      body = data.last.grep(Array)
      words = body.sum(&:length)
      if data[9] == :method && words > 30
        warnings << warning(target, iseq.label, iseq.first_lineno, "inline_size",
          "#{words} encoded words; above Ruby 4.1 preview ZJIT's default 30-word callee threshold (not a compilation limit)")
      end
      line = iseq.first_lineno
      data.last.each do |entry|
        if entry.is_a?(Integer)
          line = entry
          next
        end
        next unless entry.is_a?(Array)
        op = entry.first
        call = entry.find { _1.is_a?(Hash) && _1.key?(:mid) }
        mid = call && call[:mid]
        reasons = []
        reasons << ["dynamic_send", "dynamic dispatch needs receiver/name profiling"] if %i[send __send__ public_send].include?(mid)
        reasons << ["block_method", "prefer a separate def ISeq over block-backed define_method"] if %i[define_method define_singleton_method].include?(mid)
        if op == :definesmethod || (op == :defineclass && (entry[3] & 1) != 0) || mid == :singleton_class
          reasons << ["singleton_class", "singleton method/class; distinguish module/class setup from per-instance hot-path creation"]
        end
        if %i[splatarray splatkw invokeblock invokeblock_forward sendforward invokesuperforward].include?(op) ||
            (call && (call.fetch(:flag, 0) & (1 | 2 | 128)) != 0) || (op == :send && entry[2])
          reasons << ["call_shape", "splat, keyword splat, block or forwarding; inspect the JIT's actual exit/fallback counters"]
        end
        if %i[binding eval set_trace_func].include?(mid) || (op == :opt_getconstant_path && entry[1].include?(:TracePoint))
          reasons << ["tracing_binding", "tracing/binding/eval may escape environments or invalidate compiled code"]
        end
        reasons << ["constant_write", "constant table mutation, unlike G/K/V container writes, can invalidate compiled assumptions"] if op == :setconstant || %i[const_set remove_const].include?(mid)
        reasons.each { |reason, detail| warnings << warning(target, iseq.label, line, reason, detail) }
      end
      iseq.each_child { |child| warnings.concat(check(child, target)) }
      warnings
    end
  end
end
