# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "lowrail-profile"
  # Read, not required: Bundler evaluates a path or git gem's gemspec in every
  # app process, and listing the gem must not load it into the app.
  spec.version = File.read(File.join(__dir__, "lib/lowrail/profile_version.rb"))[/VERSION = "([^"]+)"/, 1]
  spec.summary = "Exact object allocation counts per request, job, mail and Cable action of a Rails app, by source line"
  spec.description = "Runs your test suite (or a replayed request mix) with allocation counting on and reports the " \
    "objects each request, job, mail and Action Cable action allocates, by line in your app, Rails, Ruby and gems, " \
    "and compares two captures to list what grew. Counts objects, not time. Never changes or lowers your app."
  spec.authors = ["Thomas Klemm"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/thomasklemm/lowrail"
  spec.metadata = { "source_code_uri" => "https://github.com/thomasklemm/lowrail/tree/main/gem",
    "rubygems_mfa_required" => "true" }
  spec.required_ruby_version = ">= 3.3"
  # The counter is compiled on first run into ~/.cache, not at install
  # (spec.extensions): a compiler problem must not break bundle install.
  spec.files = %w[exe/lowrail-profile lib/lowrail/profile.rb lib/lowrail/profile_report.rb lib/lowrail/profile_compare.rb
    lib/lowrail/profile_workloads.rb lib/lowrail/profile_version.rb lib/lowrail/workloads.rb lib/lowrail/load_hooks.rb
    lib/lowrail/loaded_constant.rb ext/lowrail_profile/extconf.rb ext/lowrail_profile/lowrail_profile.c
    data/contributions-index.json README-profile.md LICENSE]
  spec.extra_rdoc_files = ["README-profile.md"]
  spec.bindir = "exe"
  spec.executables = ["lowrail-profile"]
end
