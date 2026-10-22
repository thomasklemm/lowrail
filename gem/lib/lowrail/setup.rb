# frozen_string_literal: true

# Entry point for RUBYOPT="-I<gem>/lib -rlowrail/setup" or config/boot.rb.
# Normal mode never raises: on any problem the app runs as plain Ruby.
# The explicitly unsafe experiment below fails closed instead.
require_relative "../lowrail"

if ENV["LOWRAIL_VERIFY_TEST"] == "1"
  require_relative "test_certificate"
  Lowrail::TestCertificate.observe_boot
end

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

# Explicit sealed delivery has an identical natural-form observation seam in
# both arms, including LOWRAIL=0. It observes AS's existing load boundary;
# guarded/default startup and applications that never render a form stay put.
if ENV["LOWRAIL_SEALED"] == "1"
  # Define the delivery helpers symmetrically, without installing a compiler,
  # eval or route hook. Merely enabling an artifact must not add loaded files.
  require_relative "guard"
  Lowrail::Guard.observe_mutations
  require_relative "loader"
  require_relative "routes"
  require_relative "form_scaffold"
  Lowrail::FormScaffold.observe_forms
  require_relative "render_units"
  Lowrail::RenderUnits.observe
end

# Artifact storage may be snapshotted independently; root remains the actual
# app directory against which relocation and source certificates are checked.
Lowrail.boot(root: ENV.fetch("LOWRAIL_ROOT") { File.expand_path(Dir.pwd) }, dir: ENV["LOWRAIL_DIR"])
