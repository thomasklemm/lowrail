# frozen_string_literal: true

# Bet D exploration only. Never loaded by lowrail/setup. This does not certify
# visibility, arbitrary incoming ancestry, native internals or instance eigenclasses.
require "json"
require_relative "../../gem/lib/lowrail"
require_relative "../../gem/lib/lowrail/manifest"
require_relative "../../gem/lib/lowrail/guard"

module SingletonSeal
  SINGLETON = Kernel.instance_method(:singleton_class)
  ANCESTORS = Module.instance_method(:ancestors)
  METHOD = Module.instance_method(:instance_method)
  NAME = Module.instance_method(:to_s)
  FREEZE = Kernel.instance_method(:freeze)
  CALLBACKS = %i[method_added method_removed method_undefined singleton_method_added
    singleton_method_removed singleton_method_undefined].freeze

  # Existing ModuleHooks/ObjectHooks remain the mutation seam. No live
  # TracePoint and no new work at ordinary application call sites.
  module Invalidation
    def reset_method(name)
      SingletonSeal.current&.changed!("method", name)
      super
    end

    def reset_module(mod)
      SingletonSeal.current&.changed!("ancestry", nil)
      super
    end

    def singleton_changed(object, name)
      SingletonSeal.current&.changed!("singleton", name)
      super
    end

    def note_extend(mod, object)
      SingletonSeal.current&.changed!("extend", nil)
      super
    end
  end

  class << self
    attr_accessor :current

    def install_hooks!
      unless Lowrail::Guard.installed?
        manifest = Lowrail::Manifest.new({"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
          "certification_jit" => Lowrail.jit_mode, "compile_option" => Lowrail::Manifest.compile_option_fingerprint,
          "files" => {}, "units" => []}, Dir.pwd, root: Dir.pwd)
        Lowrail::Guard.install(manifest)
      end
      Module.prepend(Lowrail::Guard::ModuleHooks) unless Module < Lowrail::Guard::ModuleHooks
      BasicObject.prepend(Lowrail::Guard::ObjectHooks) unless BasicObject < Lowrail::Guard::ObjectHooks
      Lowrail::Guard.singleton_class.prepend(Invalidation) unless Lowrail::Guard.singleton_class < Invalidation
    end
  end

  class Session
    attr_reader :active, :report

    def initialize(holders:)
      @active = [false]
      @holders = holders
      @report = {"mechanism" => "frozen_singletons", "frozen" => [], "refused" => [],
        "violations" => [], "complete_method_certificate" => false}
    end

    def start!
      SingletonSeal.install_hooks!
      raise "one-shot process" if SingletonSeal.current
      normal = {}.compare_by_identity
      @holders.each do |holder|
        raise ArgumentError, "expected Module" unless Module === holder
        [holder, SINGLETON.bind_call(holder)].each do |side|
          ANCESTORS.bind_call(side).each { normal[_1] = true unless _1.singleton_class? }
        end
        normal[holder] = true
      end
      # The callback method tables and their own lookup must not be replaceable.
      carriers = [Module, BasicObject, Lowrail::Guard::ModuleHooks, Lowrail::Guard::ObjectHooks, Invalidation]
      carriers.each { normal[_1] = true }
      normal.each_key do |holder|
        CALLBACKS.each do |name|
          expected = name.to_s.start_with?("singleton_") ? Lowrail::Guard::ObjectHooks : Lowrail::Guard::ModuleHooks
          actual = METHOD.bind_call(SINGLETON.bind_call(holder), name).owner
          next if actual.equal?(expected)
          @report["refused"] << {"holder" => NAME.bind_call(holder), "callback" => name.to_s, "owner" => NAME.bind_call(actual)}
        rescue NameError
          @report["refused"] << {"holder" => NAME.bind_call(holder), "callback" => name.to_s, "owner" => "missing"}
        end
      end
      unless @report["refused"].empty?
        warn "LOWRAIL SINGLETON SEAL REFUSED: unexpected mutation callback owner; original dispatch required"
        return self # all preflight, no freezes on refusal
      end
      @names = normal.keys.flat_map do |holder|
        holder.instance_methods + holder.private_instance_methods + holder.protected_instance_methods
      end.concat(CALLBACKS).to_h { [_1, true] }
      SingletonSeal.current = self
      # Freezing an eigenclass does NOT freeze its attached Class object.
      # Carrier tables themselves are the small explicit stronger freeze.
      normal.each_key do |holder|
        FREEZE.bind_call(SINGLETON.bind_call(holder))
        @report["frozen"] << NAME.bind_call(holder)
      end
      carriers.each { FREEZE.bind_call(_1) }
      @active[0] = true
      @report["applied"] = true
      self
    rescue Exception
      @active[0] = false
      @report["startup_failed"] = true
      raise # an irreversible partial freeze is never a pretend fallback
    end

    def changed!(operation, name)
      return unless @active[0] && (!name || @names.key?(name))
      @active[0] = false
      @report["violations"] << {"operation" => operation, "name" => name&.to_s, "backtrace" => caller}
      warn "LOWRAIL SINGLETON SEAL VIOLATION: #{operation} #{name}; authorization withdrawn, original dispatch required"
    end

    def finish!
      @report.merge("active" => @active[0], "status" => !@report["refused"].empty? ? "refused_before_freeze" :
        (@report["violations"].empty? ? "applied_no_violation_observed" : "deoptimized"))
    end
  end
end
