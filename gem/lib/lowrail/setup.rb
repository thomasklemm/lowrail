# frozen_string_literal: true

# Entry point for RUBYOPT="-I<gem>/lib -rlowrail/setup" or config/boot.rb.
# Normal mode never raises: on any problem the app runs as plain Ruby.
# The explicitly unsafe experiment below fails closed instead.
require_relative "../lowrail"

if ENV["LOWRAIL_SPECULATE"] && ENV["LOWRAIL"] == "0"
  # The off side of differential verification must be genuinely unmodified.
  ENV.delete("LOWRAIL_SPECULATE")
  ENV.delete("LOWRAIL_SPECULATE_KEEP")
elsif ENV["LOWRAIL_SPECULATE"]
  # Deliberately outside the gem: this experiment must never ship in a runtime
  # package. Its entrypoint checks an actual bench/verify ancestor, not an env
  # variable claiming that a production process is a benchmark.
  experiment = File.expand_path("../../../bench/speculation.rb", __dir__)
  abort "[lowrail] REFUSING unsafe speculation outside a source-checkout benchmark" unless File.file?(experiment)
  require experiment
end

# Artifact storage may be snapshotted independently; root remains the actual
# app directory against which relocation and source certificates are checked.
Lowrail.boot(root: ENV.fetch("LOWRAIL_ROOT") { File.expand_path(Dir.pwd) }, dir: ENV["LOWRAIL_DIR"])
