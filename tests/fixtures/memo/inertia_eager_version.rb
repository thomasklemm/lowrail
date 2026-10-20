# Actual public-app shape: PingCRM and Redprints CFP compute a String at boot.
# https://github.com/ledermann/pingcrm/blob/22464f822dcf59c4425993dd623780ad44497fda/config/initializers/inertia_rails.rb
InertiaRails.configure do |config|
  config.version = ViteRuby.digest
end
