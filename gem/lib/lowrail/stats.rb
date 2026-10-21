# frozen_string_literal: true

module Lowrail
  # Fast-path hit counting for `lowrail verify` (LOWRAIL_STATS=path, and
  # implicitly with LOWRAIL_OUTCOMES).
  #
  # Design decision: count in Lowrail.check, not in the lowered code.
  # Lowered code always has the shape
  #
  #   if ::Lowrail::G[id] || ::Lowrail.check(id) then <fast> else <original> end
  #
  # With stats on, the validated states live in STATE instead of G, so G stays
  # all-nil and every call reaches the counting check below. This costs one
  # Ruby method call per lowered call, only in stats runs, and nothing at all
  # otherwise. The alternative (emitting `::Lowrail::H[id] += 1` in a separate
  # stats build) would make verify measure a different binary than the one
  # deployed and double the build matrix; the identical-ISeq property is worth
  # more than the few nanoseconds per call in a test run.
  #
  # Output: at exit each process writes `<LOWRAIL_STATS>.<pid>` (forked test
  # workers each write their own file; nothing is merged here):
  #   {"pid":1,"ppid":0,"unit_hits":{"17":3},"unit_fallbacks":{"4":1},
  #    "loaded_files":["/abs/app/models/article.rb"]}
  module Stats
    STATE = []  # validated guard state per unit (G's role in stats mode)
    HITS = []   # fast path taken
    MISSES = [] # original body taken (guard false)

    module ForkHook
      def _fork
        pid = super
        ::Lowrail::Stats.reset_counts! if pid.zero?
        pid
      end
    end

    # Ordinary requests never check whether counters are enabled. Install
    # counting only on opt-in, including when enabled after guard validation.
    module ReceiverGuardCounts
      def ok?(id, klass)
        decision = super
        ::Lowrail::Stats.count(id, decision)
        decision
      end
      alias view_ok? ok?
    end

    class << self
      def enabled? = !!@enabled

      def enable!
        return if @enabled
        @enabled = true
        @loaded = []
        # A class published before late activation must not bypass counting.
        Lowrail::K.fill(NO_RECEIVER)
        Lowrail.singleton_class.prepend(ReceiverGuardCounts)
        Lowrail.singleton_class.class_eval do
          remove_method :check # replaced, not wrapped: no extra frame per call
          def check(id)
            s = ::Lowrail::Stats::STATE[id]
            s = ::Lowrail::Stats::STATE[id] = ::Lowrail::Guard.validate(id) if s.nil?
            if s
              ::Lowrail::Stats::HITS[id] = (::Lowrail::Stats::HITS[id] || 0) + 1
            else
              ::Lowrail::Stats::MISSES[id] = (::Lowrail::Stats::MISSES[id] || 0) + 1
            end
            s
          end
        end
        Process.singleton_class.prepend(ForkHook)
        if (path = ENV["LOWRAIL_STATS"]) && !path.empty?
          at_exit { write("#{path}.#{Process.pid}") }
        end
      end

      # A forked child starts counting from zero, so hits made before the
      # fork (e.g. while a test parent boots) are not counted once per worker.
      # Guard states are kept: they are still valid in the child.
      # Counts a guard decision made outside #check (template view guards).
      def count(id, ok)
        array = ok ? HITS : MISSES
        array[id] = (array[id] || 0) + 1
      end

      def reset_counts!
        HITS.clear
        MISSES.clear
      end

      def loaded(path) = (@loaded << path if @enabled)

      def loaded_files = @loaded.dup

      def unit_hits = counts(HITS)

      def unit_fallbacks = counts(MISSES)

      def snapshot
        data = { "pid" => Process.pid, "ppid" => Process.ppid, "unit_hits" => unit_hits,
          "unit_fallbacks" => unit_fallbacks, "loaded_files" => loaded_files,
          "jit_mode" => Lowrail.jit_status }
        data["refusal_reason"] = Lowrail.refusal_reason if Lowrail.refusal_reason
        data
      end

      def write(path)
        Lowrail.write_json(path, snapshot)
      rescue StandardError, ScriptError => e
        warn "[lowrail] could not write stats to #{path}: #{e.message}"
      end

      private

      def counts(array)
        h = {}
        array.each_with_index { |n, id| h[id.to_s] = n if n && n > 0 }
        h
      end
    end
  end
end
