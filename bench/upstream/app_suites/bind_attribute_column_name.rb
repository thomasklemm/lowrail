# RAILS=path ruby bind_attribute_column_name.rb -> exit 1 if a call shape below raises
# Callers that pass a column name to the private PredicateBuilder#build_bind_attribute, as on 8-1:
#   Zammad's User.by_login_case_sensitive (a Symbol, inside LOWER()), authlogic 6.6.1's FindWithCase
#   (a String, through case_sensitive_comparison), Mastodon's Status::SafeReblogInsert (a String).
# 8-1 finds the row with each shape; main raises NoMethodError (undefined method 'type_caster');
# with the restore each shape finds the row and warns once.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :login } }
class User < ActiveRecord::Base; end
User.create!(login: "alice")
warnings = 0
ActiveRecord.deprecator.behavior = ->(*) { warnings += 1 } if ActiveRecord.respond_to?(:deprecator)

shapes = {
  "Zammad (Symbol, LOWER)" => -> {
    lower = Arel::Nodes::NamedFunction.new("LOWER", [User.predicate_builder.build_bind_attribute(:login, "ALICE")])
    User.where(login: "alice").where(User.arel_table[:login].lower.eq(lower)).to_a
  },
  "authlogic (String, case_sensitive_comparison)" => -> {
    bind = User.predicate_builder.build_bind_attribute("login", "alice")
    User.with_connection { |c| User.where(c.case_sensitive_comparison(User.arel_table["login"], bind)).to_a }
  },
  "Mastodon (String, eq)" => -> {
    User.where(User.arel_table[:login].eq(User.predicate_builder.build_bind_attribute("login", "alice"))).to_a
  },
}
results = shapes.map do |label, run|
  rows = run.call
  "#{label}: #{rows.size} row"
rescue => e
  "#{label}: #{e.class}: #{e.message[0, 60]}"
end
puts "#{ActiveRecord.version}: #{results.join("; ")}; deprecation warnings: #{warnings}"
exit(results.any? { _1.include?("Error") } ? 1 : 0)
