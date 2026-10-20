# frozen_string_literal: true

require_relative "lib/lowrail"

Gem::Specification.new do |spec|
  spec.name = "lowrail"
  spec.version = Lowrail::VERSION
  spec.summary = "Guarded, boot-fact specialization of Rails apps delivered as ISeqs"
  spec.authors = ["Thomas Klemm"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.files = Dir["lib/**/*.rb"]
end
