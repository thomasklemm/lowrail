# frozen_string_literal: true

# Lowrail runtime: serves lowered instruction sequences for files the build
# step specialized, and keeps every specialized method behind a guard that
# falls back to the original body whenever a recorded boot fact stops holding.
#
# Load it from config/boot.rb *after* bootsnap:
#
#   require "bootsnap/setup"
#   require "lowrail/setup"
#
# LOWRAIL=0 disables it entirely; with no manifest it is a no-op.
module Lowrail
  VERSION = "0.0.1"
  FORMAT = 1

  # Guard states, indexed by unit id. nil = not yet validated, true = facts
  # hold, false = facts failed. Lowered code reads this array directly; the
  # array object never changes, so constant caches stay warm.
  G = []

  class << self
    attr_reader :manifest, :root

    def enabled?
      ENV["LOWRAIL"] != "0"
    end

    def setup(root: Dir.pwd, dir: File.join(root, ".lowrail"))
      return false unless enabled?
      path = File.join(dir, "manifest.json")
      return false unless File.exist?(path)

      require "json"
      require_relative "lowrail/manifest"
      require_relative "lowrail/guard"
      require_relative "lowrail/loader"
      require_relative "lowrail/stats" if ENV["LOWRAIL_STATS"]

      @root = root
      @manifest = Manifest.load(path, dir)
      unless @manifest.compatible?
        warn "[lowrail] manifest built for #{@manifest.ruby_description}; running #{RUBY_DESCRIPTION}. Falling back to plain Ruby." if ENV["LOWRAIL_DEBUG"]
        return false
      end
      Guard.install(@manifest)
      Loader.install(@manifest)
      true
    end

    # Called from lowered code when G[id] is not true.
    def check(id)
      state = G[id]
      return state unless state.nil?
      G[id] = Guard.validate(id)
    end
  end
end
