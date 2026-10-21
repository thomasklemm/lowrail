# frozen_string_literal: true

require_relative "manifest"
require_relative "test_certificate"

module Lowrail
  module TestCertificateBuild
    module_function

    def run(request, output)
      raise ArgumentError, "test environment only" unless ENV["RAILS_ENV"] == "test"
      TestCertificate.observe_boot
      # Register before Rails installs Minitest autorun. Discovery happens
      # AFTER the app's complete, unchanged original suite, never by requiring
      # its helper early or by invoking materialization/eager loading ourselves.
      at_exit do
        BuildJit.check(request.fetch("certification_jit"))
        certificate = TestCertificate.certificate(Dir.pwd)
        require_relative "test_certificate_render_build"
        natural_render = TestCertificateRenderBuild.capture
        results = [{units: [], ledger: [], verification_test: certificate}]
        request.fetch("builders").each do |builder|
          name = builder.fetch("module")
          if %w[TokenTagBuild CollectionRenderBuild].include?(name)
            pass = name == "TokenTagBuild" ? TokenTag::PASS : CollectionRender::PASS
            results << TestCertificateRenderBuild.build(pass, context: natural_render.fetch(pass), denied: request.fetch("denied"))
            next
          end
          unless %w[ARInstantiateBuild SealedBuild FormScaffoldBuild].include?(name)
            results << {units: [], ledger: [{"pass" => name, "outcome" => "refused",
              "reason" => "verification-only passive certificate not implemented for this pass"}]}
            next
          end
          # Builder-only synthetic form inventory remains builder-only. The
          # certificate above describes natural state BEFORE those operations;
          # none of them can supply an activation witness.
          require_relative builder.fetch("file")
          results << Lowrail.const_get(name, false).build(denied: request.fetch("denied"), verification_test: true)
        end
        BuildJit.check(request.fetch("certification_jit"))
        output.puts(JSON.generate(results))
      end
      ARGV.replace(TestCertificate.suite_arguments)
      load File.expand_path("bin/rails")
    end
  end
end
