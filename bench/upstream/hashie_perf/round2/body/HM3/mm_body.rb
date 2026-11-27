# frozen_string_literal: true

# Method-style calls on a Mash built from one GitHub repository and on an OmniAuth-like auth hash.
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
  'info' => { 'nickname' => 'octocat', 'email' => 'octocat@github.com', 'name' => 'The Octocat' },
  'credentials' => { 'token' => 'gho_16C7e42F292c6912E7710c838347Ae178B4a', 'expires' => false }
}.freeze

mash = Hashie::Mash.new(REPO)
auth = QuietMash.new(AUTH)

UpstreamBench.report('read 5 keys as methods') do
  mash.name
  mash.owner.login
  mash.license.spdx_id
end
UpstreamBench.report('auth.info.email, auth.uid') do
  auth.info.email
  auth.uid
end
UpstreamBench.report('description = and private?') do
  mash.description = 'A first repository'
  mash.private?
end
