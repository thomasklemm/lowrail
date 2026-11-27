# frozen_string_literal: true

require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)
mash = Hashie::Mash.new(JSON.parse(File.read(File.expand_path('repository.json', __dir__))))

UpstreamBench.report('read keys with suffixes') do
  mash.private?
  mash.owner!.login
  mash.homepage_
end
UpstreamBench.report('write a new key as a method') { Hashie::Mash.new.name = 'Hello-World' }
