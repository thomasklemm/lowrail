# frozen_string_literal: true

require "hashie"
require "json"
require "logger"

Hashie.logger = Logger.new(nil)
payload = JSON.parse(File.read(File.join(__dir__, "repository.json")))
update = { "stargazers_count" => 81, "topics" => %w[ruby api hashie], "owner" => { "site_admin" => true } }
mash = Hashie::Mash.new(payload)

UpstreamBench.report("mash.deep_merge(update)") { mash.deep_merge(update) }
UpstreamBench.report("mash.description = value") { mash.description = "A first repository" }
UpstreamBench.report("Mash.new(api_response)") { Hashie::Mash.new(payload) }
