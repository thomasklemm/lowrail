# frozen_string_literal: true

# Connection-local plans cannot be inherited from Puma's master. Rebuild the
# same Site in each worker in EVERY arm, before serving or measuring requests.
module NativeRps::PumaSetup
  def self.configure(puma:, config:, arm:)
    puma.on_worker_boot { ARRequestSites.install(config, "on") }
  end
end
