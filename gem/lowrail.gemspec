# frozen_string_literal: true

require_relative "lib/lowrail"

Gem::Specification.new do |spec|
  spec.name = "lowrail"
  spec.version = Lowrail::VERSION
  spec.summary = "Guarded, boot-fact specialization of Rails apps delivered as ISeqs"
  spec.authors = ["Thomas Klemm"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0"
  # The native prototype is opt-in via rake compile, not an installation-time
  # dependency: a missing compiler must not prevent the Ruby gem from loading.
  spec.files = Dir["lib/**/*.rb", "ext/**/*.{c,rb}", "Rakefile"]
  spec.add_development_dependency "minitest-mock", "~> 5.27"
  spec.add_development_dependency "sorbet-runtime", "0.5.12435"
end
