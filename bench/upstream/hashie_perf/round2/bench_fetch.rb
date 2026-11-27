# frozen_string_literal: true

# Mash#fetch, whose `*args` allocates an Array per call (held idea: forward with `...`).
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)
REPO = JSON.parse(File.read(File.expand_path('fixtures/github-org-repos.json', __dir__))).first
mash = Hashie::Mash.new(REPO)

UpstreamBench.report('fetch(:name)') { mash.fetch(:name) }
UpstreamBench.report('fetch(:missing, nil)') { mash.fetch(:missing, nil) }
UpstreamBench.report('fetch(:missing) { 1 }') { mash.fetch(:missing) { 1 } }
