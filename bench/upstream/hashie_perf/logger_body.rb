# frozen_string_literal: true

require 'hashie'
require 'json'
require 'logger'

repository = JSON.parse(File.read(File.expand_path('repository.json', __dir__)))
null_logger = Logger.new(nil)
error_logger = Logger.new(File::NULL, level: :error)

UpstreamBench.report('Mash.new, Logger.new(nil)') do
  Hashie.logger = null_logger
  Hashie::Mash.new(repository)
end
UpstreamBench.report('Mash.new, logger at error level') do
  Hashie.logger = error_logger
  Hashie::Mash.new(repository)
end
