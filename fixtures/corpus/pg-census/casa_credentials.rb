# Throwaway production credentials (BASE_URL only) for the disposable census copy of CASA.
require "active_support"
require "active_support/encrypted_file"
FileUtils.mkdir_p("config/credentials")
File.write("config/credentials/production.key", ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
ActiveSupport::EncryptedFile.new(content_path: "config/credentials/production.yml.enc", key_path: "config/credentials/production.key",
  env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true).write("BASE_URL: https://localhost\n")
