# frozen_string_literal: true

# Plain Mash alone: the quiet subclass is defined but never instantiated, so no call site sees two classes.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class QuietMash < Hashie::Mash
  disable_warnings
end

REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
mash = Hashie::Mash.new(REPO)
update = { 'stargazers_count' => 81, 'owner' => { 'site_admin' => true } }.freeze

UpstreamBench.report('Mash.new(repository)') { Hashie::Mash.new(REPO) }
UpstreamBench.report('Mash#merge') { mash.merge(update) }
UpstreamBench.report("mash['description'] =") { mash['description'] = 'A first repository' }
