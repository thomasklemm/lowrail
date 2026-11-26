# frozen_string_literal: true

require "hashie"
require "json"
require "logger"

Hashie.logger = Logger.new(nil)
payload = JSON.parse(File.read(File.join(__dir__, "repository.json")))
mash = Hashie::Mash.new(payload)

UpstreamBench.report("Mash.new.name = value") { Hashie::Mash.new.name = "value" }
UpstreamBench.report("mash.description = value") { mash.description = "A first repository" }
UpstreamBench.report("mash.private? / owner! / homepage_") { mash.private?; mash.owner!.login; mash.homepage_ }
