# frozen_string_literal: true

# The calls of mm_body.rb's third case one by one: a setter passes an argument, a predicate and a reader don't.
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)
REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
mash = Hashie::Mash.new(REPO)

UpstreamBench.report('mash.description = value') { mash.description = 'A first repository' }
UpstreamBench.report('mash.private?') { mash.private? }
UpstreamBench.report('mash.name') { mash.name }
UpstreamBench.report('mash.name(1)') { mash.name(1) }
