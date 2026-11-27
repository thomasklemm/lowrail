# frozen_string_literal: true

# A Mash subclass that disables the warning for some keys only, next to plain Mash as the control.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class KeyedMash < Hashie::Mash
  disable_warnings :size, :key, :default
end

REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
keyed = KeyedMash.new(REPO)

UpstreamBench.report('keyed.new(repository)') { KeyedMash.new(REPO) }
UpstreamBench.report("keyed['description'] =") { keyed['description'] = 'A first repository' }
