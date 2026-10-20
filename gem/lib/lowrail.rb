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

  class << self
    attr_reader :manifest, :root

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
      if ENV["LOWRAIL_STATS"] || ENV["LOWRAIL_OUTCOMES"]
        require_relative "lowrail/stats"
        Stats.enable!
      end
      if ENV["LOWRAIL_OUTCOMES"]
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
      require_relative "lowrail/routes"
      unless manifest.templates.empty?
        require_relative "lowrail/templates"
        Templates.install(manifest.templates)
      end
      if manifest.units.any? { _1["pass"] == "active_record/preload_plans" }
        require_relative "lowrail/preload_plans"
        PreloadPlans.install(manifest)
      end
      if manifest.units.any? { _1["pass"].to_s.start_with?("memo/") }
        require_relative "lowrail/memo"
        Memo.install(manifest)
      end
      if manifest.units.any? { _1["pass"] == "digest/file_memo" }
        require_relative "lowrail/digest_memo"
        DigestMemo.install(manifest)
      end
      if manifest.units.any? { _1["pass"] == "active_record/instantiate" }
        require_relative "lowrail/ar_instantiate"
        ARInstantiate.install(manifest)
      end
      if manifest.units.any? { _1["pass"] == "active_record/ar_plans" }
        require_relative "lowrail/ar_guard"
        require_relative "lowrail/ar_plans"
        ARPlans.install(manifest)
      end
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
