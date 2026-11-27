# frozen_string_literal: true

# Converting a Mash built from one GitHub repository (83 keys, nested owner, license and permissions) back to a Hash.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class InfoHash < Hashie::Mash
  disable_warnings

  def to_hash
    hash = super
    hash['name'] ||= 'derived'
    hash
  end
end

REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
mash = Hashie::Mash.new(REPO)
info = InfoHash.new('nickname' => 'octocat', 'email' => 'octocat@github.com', 'image' => 'https://github.com/images/error/octocat_happy.gif',
                    'urls' => { 'GitHub' => 'https://github.com/octocat', 'Blog' => 'https://github.blog' })

UpstreamBench.report('Mash#to_hash') { mash.to_hash }
UpstreamBench.report('Mash#to_json') { mash.to_json }
UpstreamBench.report('to_hash(symbolize_keys: true)') { mash.to_hash(symbolize_keys: true) }
UpstreamBench.report('auth info to_hash') { info.to_hash }
