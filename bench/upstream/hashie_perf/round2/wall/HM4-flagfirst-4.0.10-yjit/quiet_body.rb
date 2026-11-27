# frozen_string_literal: true

# Building, copying and writing a Mash subclass that disabled warnings, as OmniAuth's KeyStore, elasticsearch-model's
# HashWrapper, Restforce::Mash, zendesk_api's SilentMash and chef-zero's Mash do; plain Mash is the control.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class QuietMash < Hashie::Mash
  disable_warnings
end

REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
AUTH = {
  'provider' => 'github', 'uid' => '1234567',
  'info' => { 'nickname' => 'octocat', 'email' => 'octocat@github.com', 'name' => 'The Octocat',
              'image' => 'https://github.com/images/error/octocat_happy.gif',
              'urls' => { 'GitHub' => 'https://github.com/octocat', 'Blog' => 'https://github.blog' } },
  'credentials' => { 'token' => 'gho_16C7e42F292c6912E7710c838347Ae178B4a', 'expires' => false },
  'extra' => { 'raw_info' => REPO['owner'], 'scope' => 'user:email' }
}.freeze

quiet = QuietMash.new(REPO)
update = { 'stargazers_count' => 81, 'owner' => { 'site_admin' => true } }.freeze

UpstreamBench.report('quiet.new(repository)') { QuietMash.new(REPO) }
UpstreamBench.report('quiet.new(auth hash)') { QuietMash.new(AUTH) }
UpstreamBench.report('quiet merge') { quiet.merge(update) }
UpstreamBench.report('quiet []=') { quiet['description'] = 'A first repository' }
UpstreamBench.report('Mash.new(repository)') { Hashie::Mash.new(REPO) }
