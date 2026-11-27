# frozen_string_literal: true

# Callers of Mash#convert_key with String keys, as a JSON response has them.
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
UpstreamBench.report('quiet.new(repository)') { QuietMash.new(REPO) }
UpstreamBench.report("mash['name'] x3") { mash['name']; mash['full_name']; mash['owner']['login'] }
UpstreamBench.report('mash.name x3') { mash.name; mash.full_name; mash.owner.login }
UpstreamBench.report("key?('name'), fetch('name')") { mash.key?('name'); mash.fetch('name') }
UpstreamBench.report("mash['description'] = ") { mash['description'] = 'x' }
UpstreamBench.report('merge') { mash.merge(update) }
