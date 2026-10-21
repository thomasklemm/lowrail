# frozen_string_literal: true

require_relative "../../fixtures/corpus/blog_entropy"

# External fixture control, not an application/framework specialization.
# The blog policy remains unchanged; Lobsters has its own source/lock/Rack pins.
module LobstersNativeValidation
  POLICY = File.expand_path("../../fixtures/corpus/lobsters-native-entropy.json", __dir__)
  module_function

  def install(app)
    @control = BlogProduction::Entropy.validate(app, policy: JSON.parse(File.read(POLICY)))
    raise @control.fetch("reason") unless @control.fetch("active")
    gemfile = ENV.fetch("BUNDLE_GEMFILE")
    raise "Lobsters dependency overlay mismatch" unless
      Digest::SHA256.file(gemfile).hexdigest == @control.fetch("policy").fetch("dependency_overlay_sha256") &&
      Digest::SHA256.file(gemfile + ".lock").hexdigest == @control.fetch("policy").fetch("dependency_lock_sha256")
    BlogProduction::Entropy.install(@control.fetch("policy"))
  end

  def validation_request(route:, seed:, request:)
    response, evidence = BlogProduction::Entropy.with(seed, route, requests: 1, wall_clock: true, &request)
    [response, {"passed" => evidence.fetch("errors").empty?, "control" => @control,
      "entropy" => evidence, "policy_sha256" => Digest::SHA256.file(POLICY).hexdigest}]
  end
end
