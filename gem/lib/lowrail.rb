# frozen_string_literal: true

# Lowrail runtime: serves lowered instruction sequences for files the build
# step specialized, and keeps every specialized method behind a guard that
# falls back to the original body whenever a recorded boot fact stops holding.
#
# Load it without touching the app, through RUBYOPT:
#
#   RUBYOPT="-I<gem>/lib -rlowrail/setup" bin/rails test
#
# or from config/boot.rb (before or after bootsnap, both orders work):
#
#   require "lowrail/setup"
#
# LOWRAIL=0 disables lowering entirely; with no (or an incompatible) manifest
# it is a no-op. In RAILS_ENV/RACK_ENV=development it is off unless LOWRAIL=1.
#
# Boot-time constraint: this file and everything loaded at setup must not
# require default gems (json, digest, strscan, ...). Under RUBYOPT we run
# before bundler/setup, and activating e.g. the default json 2.9.1 would make
# Bundler refuse a lockfile that pins json 3.1.0. The manifest is therefore
# parsed by Lowrail::MiniJSON, and digest is required lazily on the first
# lookup of a lowered file (which happens after Bundler has set up).
module Lowrail
  VERSION = "0.0.1"
  FORMAT = 1

  # Guard states, indexed by unit id. nil = not yet validated, true = facts
  # hold, false = facts failed. Lowered code reads this array directly:
  #
  #   if ::Lowrail::G[17] || ::Lowrail.check(17) then <fast> else <original> end
  #
  # The array object never changes, so constant caches stay warm. With stats
  # on (LOWRAIL_STATS / LOWRAIL_OUTCOMES), G stays all-nil and the real states
  # live in Stats::STATE, so every call goes through the counting check (see
  # lowrail/stats.rb for why that is the chosen design).
  G = []

  # Units whose code runs with different classes of `self` (templates run in
  # one view class per controller, helpers and concerns are mixed into many
  # classes) have facts with receiver "@self"; they are checked per class:
  # V[id] = {klass => true/false}.
  V = []

  # Last receiver class validated true for each unit. Generated code compares
  # class identity here before entering the polymorphic V cache. A private,
  # non-class sentinel keeps an overridden #class returning nil from matching
  # an unchecked slot. Statistics mode never publishes a class here.
  K = []
  NO_RECEIVER = Object.new.freeze
  private_constant :NO_RECEIVER

  CONST_DEFINED = Module.instance_method(:const_defined?)
  AUTOLOAD = Module.instance_method(:autoload?)
  CONST_GET = Module.instance_method(:const_get)
  private_constant :CONST_DEFINED, :AUTOLOAD, :CONST_GET

  class << self
    attr_reader :manifest, :root, :refusal_reason

    # Runtime facts observe constants; they never resolve an autoload or
    # invoke const_missing. A missing dependency means wait or fall back.
    def loaded_constant(name)
      name.delete_prefix("::").split("::").inject(Object) do |owner, part|
        return unless Module === owner && CONST_DEFINED.bind_call(owner, part, false) &&
          !AUTOLOAD.bind_call(owner, part, false)
        CONST_GET.bind_call(owner, part, false)
      end
    end

    def enabled?
      flag = ENV["LOWRAIL"]
      return false if flag == "0"
      return true if flag == "1"
      env = ENV["RAILS_ENV"] || ENV["RACK_ENV"]
      env != "development"
    end

    # Entry point used by lowrail/setup: stats and the outcome reporters are
    # independent of whether lowering is active (verify needs outcomes for
    # LOWRAIL=0 runs too).
    def boot(root: Dir.pwd)
      require_relative "lowrail/jit_diagnostics" if ENV["LOWRAIL_JIT_DIAGNOSTICS"] == "1"
      if ENV["LOWRAIL_STATS"] || ENV["LOWRAIL_OUTCOMES"]
        require_relative "lowrail/stats"
        Stats.enable!
      end
      if ENV["LOWRAIL_OUTCOMES"]
        if ENV["LOWRAIL_VERIFY_LOADS"] == "1"
          require_relative "lowrail/verify_loads"
          VerifyLoads.install
        end
        require_relative "lowrail/sql_trace"
        require_relative "lowrail/minitest"
        Lowrail::Minitest.install(ENV["LOWRAIL_OUTCOMES"])
        require_relative "lowrail/rspec"
        Lowrail::RSpec.install(ENV["LOWRAIL_OUTCOMES"])
      end
      setup(root: root)
    rescue StandardError, ScriptError => e
      # Never break an app: any failure here leaves plain Ruby running.
      warn "[lowrail] setup failed (#{e.class}: #{e.message}); running without Lowrail" if ENV["LOWRAIL_DEBUG"]
      false
    end

    def setup(root: Dir.pwd, dir: File.join(root, ".lowrail"))
      return false unless enabled?
      # With no selected units, serve original source rather than installing
      # lowered code whose guards can only fall back. Reporters boot above.
      return false if ENV["LOWRAIL_UNITS"] == ""
      path = File.join(dir, "manifest.json")
      return false unless File.file?(path)

      require_relative "lowrail/manifest"

      manifest = Manifest.load(path, dir)
      if (@refusal_reason = manifest.refusal_reason)
        warn "[lowrail] #{@refusal_reason}; running without Lowrail"
        return false
      end
      unless manifest.compatible?
        debug "manifest built for #{manifest.ruby_description} (format #{manifest.format}); running #{RUBY_DESCRIPTION}. Falling back to plain Ruby."
        return false
      end
      @root = root
      @manifest = manifest
      return true if manifest.units.empty?

      require_relative "lowrail/guard"
      require_relative "lowrail/loader"
      Guard.install(manifest, defined?(Stats) && Stats.enabled? ? Stats::STATE : G)
      Loader.install(manifest)
      require_relative "lowrail/passes"
      Passes.install(manifest)
      true
    end

    # Called from lowered code when G[id] is not true. Replaced by a counting
    # version when stats are enabled.
    def check(id)
      state = G[id]
      return state unless state.nil?
      G[id] = Guard.validate(id)
    end

    # Called from lowered code as `::Lowrail.ok?(id, self.class)`. Facts whose
    # receiver is "@self" (or "@view", the name used by earlier builds) are
    # checked against that class, once per class until a hook resets the unit.
    def ok?(id, klass)
      cache = (V[id] ||= {}.compare_by_identity)
      s = cache[klass]
      s = cache[klass] = Guard.validate(id, klass: klass) if s.nil?
      K[id] = klass if s && !(defined?(Stats) && Stats.enabled?)
      s
    end
    alias view_ok? ok?

    # Atomic JSON write (tmp + rename). Only used at exit and in build tools,
    # when requiring the json gem is safe (Bundler, if any, set up long ago).
    def write_json(path, data)
      require "json"
      tmp = "#{path}.tmp.#{Process.pid}"
      File.write(tmp, JSON.pretty_generate(data) + "\n")
      File.rename(tmp, path)
    end

    def debug(msg)
      warn "[lowrail] #{msg}" if ENV["LOWRAIL_DEBUG"]
    end
  end
end
