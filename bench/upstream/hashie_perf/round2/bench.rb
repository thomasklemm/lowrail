# frozen_string_literal: true

# One GitHub repository (83 keys, nested owner, license and permissions) from the organization-repositories fixture,
# and an OmniAuth-like auth hash, through plain Mash and a subclass with warnings disabled, as OmniAuth,
# elasticsearch-model, restforce, zendesk_api and chef-zero define theirs.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class QuietMash < Hashie::Mash
  disable_warnings
end

fixtures = File.expand_path('fixtures', __dir__)
REPO = JSON.parse(File.read("#{fixtures}/github-org-repos.json")).first
AUTH = {
  'provider' => 'github', 'uid' => '1234567',
  'info' => { 'nickname' => 'octocat', 'email' => 'octocat@github.com', 'name' => 'The Octocat',
              'image' => 'https://github.com/images/error/octocat_happy.gif',
              'urls' => { 'GitHub' => 'https://github.com/octocat', 'Blog' => 'https://github.blog' } },
  'credentials' => { 'token' => 'gho_16C7e42F292c6912E7710c838347Ae178B4a', 'expires' => false },
  'extra' => { 'raw_info' => REPO['owner'], 'scope' => 'user:email' }
}.freeze

plain = Hashie::Mash.new(REPO)
quiet = QuietMash.new(REPO)
auth = QuietMash.new(AUTH)
update = { 'stargazers_count' => 81, 'owner' => { 'site_admin' => true } }.freeze

UpstreamBench.report('read 5 keys as methods') do
  plain.name
  plain.owner.login
  plain.license.spdx_id
end
UpstreamBench.report('auth.info.email, auth.uid') do
  auth.info.email
  auth.uid
end
UpstreamBench.report('Mash.new(repository)') { Hashie::Mash.new(REPO) }
UpstreamBench.report('quiet.new(repository)') { QuietMash.new(REPO) }
UpstreamBench.report('quiet.new(auth)') { QuietMash.new(AUTH) }
UpstreamBench.report('quiet dup') { quiet.dup }
UpstreamBench.report('quiet merge') { quiet.merge(update) }
UpstreamBench.report('Mash#dup') { plain.dup }
UpstreamBench.report('Mash#to_hash') { plain.to_hash }
UpstreamBench.report('quiet key write') { quiet['description'] = 'x' }
