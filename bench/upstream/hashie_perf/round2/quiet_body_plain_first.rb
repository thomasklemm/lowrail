# frozen_string_literal: true

# The cases of quiet_body.rb with plain Mash first, so its methods are profiled and compiled before a quiet subclass runs them.
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

UpstreamBench.report('Mash.new(repository)') { Hashie::Mash.new(REPO) }
UpstreamBench.report('quiet.new(repository)') { QuietMash.new(REPO) }
UpstreamBench.report('quiet.new(auth hash)') { QuietMash.new(AUTH) }
UpstreamBench.report('quiet merge') { quiet.merge(update) }
UpstreamBench.report('quiet []=') { quiet['description'] = 'A first repository' }
