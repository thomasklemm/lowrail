# frozen_string_literal: true

require "active_record"
require "blind_index"
require "json"

load ENV.fetch("BASE_EXTENSIONS") if ENV["BASE_EXTENSIONS"]

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :gem_side_users do |t|
    t.string :email_bidx
    t.string :name
  end
end

BlindIndex.master_key = "11" * 32

class GemSideUser < ActiveRecord::Base
  attribute :email, :string
  blind_index :email, algorithm: :pbkdf2_sha256
end

GemSideUser.create!(id: 7, name: "first", email: "alpha@example.test")
GemSideUser.create!(id: 19, name: "second", email: "beta@example.test")
GemSideUser.create!(id: 31, name: "blank", email: nil)

conditions = {email: ["beta@example.test", "absent@example.test"].freeze}.freeze
actual = {
  ordinary: GemSideUser.find_by(id: 7)&.name,
  missing: GemSideUser.find_by(id: 8)&.name,
  indexed: GemSideUser.find_by(email: "beta@example.test")&.id,
  array: GemSideUser.where(conditions).order(:id).pluck(:id),
  negated: GemSideUser.where.not(email: "alpha@example.test").order(:id).pluck(:id),
  null: GemSideUser.where(email: nil).pluck(:id),
  string_key: GemSideUser.where("email" => "alpha@example.test").pluck(:id)
}
expected = {ordinary: "first", missing: nil, indexed: 19, array: [19], negated: [19], null: [31], string_key: [7]}
raise "Query mismatch: #{actual.inspect}" unless actual == expected
raise "Input changed" unless conditions == {email: ["beta@example.test", "absent@example.test"]}
puts JSON.generate(actual) if $PROGRAM_NAME == __FILE__
