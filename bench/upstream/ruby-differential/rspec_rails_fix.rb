# Rails main sets url_helpers' default_url_options to a frozen {}; rspec-rails 8.0.x writes into it in the
# Feature and Mailer example groups (FrozenError). Z11's workaround, loaded the same way in every mode.
RSpec::Rails::FeatureExampleGroup.instance_variable_set(:@_included_block, proc do
  include ::Rails.application.routes.url_helpers
  include ::Rails.application.routes.mounted_helpers
  self.default_url_options = default_url_options.merge(host: ::RSpec::Rails::FeatureExampleGroup::DEFAULT_HOST) unless default_url_options[:host]
end)
RSpec::Rails::MailerExampleGroup.instance_variable_set(:@_included_block, proc do
  include ::Rails.application.routes.url_helpers
  self.default_url_options = default_url_options.merge(::Rails.configuration.action_mailer.default_url_options || {})
end) if defined?(RSpec::Rails::MailerExampleGroup)
