# frozen_string_literal: true

# Minitest plugin entry, for discovery through Minitest.load_plugins
# (Minitest 5 scans Gem.find_files, which includes -I paths) or an explicit
# `Minitest.load :lowrail`. lowrail/setup does not depend on this file: it
# hooks Minitest.init_plugins directly (Minitest 6 does not auto-discover).
# Both routes attach the same reporter once.
require_relative "../lowrail"
require_relative "../lowrail/stats"
require_relative "../lowrail/minitest"

module Minitest
  def self.plugin_lowrail_init(_options)
    path = ENV["LOWRAIL_OUTCOMES"]
    return if path.nil? || path.empty?
    Lowrail::Stats.enable!
    Lowrail::Minitest.instance_variable_set(:@path, path) unless Lowrail::Minitest.path
    Lowrail::Minitest.attach(reporter)
  end
end
