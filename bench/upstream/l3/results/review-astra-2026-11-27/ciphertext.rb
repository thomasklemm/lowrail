require "bundler/setup"
require "active_record"
require "json"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Encryption.configure(primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32)
ActiveRecord::Schema.define do
  create_table(:messages) { |t| t.string :secret; t.string :empty }
end
class Message < ActiveRecord::Base
  encrypts :secret
end
Message.create!(secret: "secret")
r = Message.first
one, two = r.attributes_for_database, r.attributes_for_database
puts JSON.generate(hash_stable: one == two, ciphertext_same_object: one["secret"].equal?(two["secret"]), accessed: r.accessed_fields)
r = Message.first
puts JSON.generate(marshal_stable: Marshal.dump(r) == Marshal.dump(r))
