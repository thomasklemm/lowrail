# frozen_string_literal: true

# find_by_sql / count_by_sql / where with a placeholder right after a typed
# literal keyword (DATE :d). RAILS_PATH=/path/to/rails for a checkout,
# otherwise AR_VERSION (default 8.1.4) from RubyGems.
require "bundler/inline"

gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"])
    %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" }
  else
    gem "activerecord", ENV.fetch("AR_VERSION", "8.1.4")
  end
  gem "pg"
  gem "sqlite3"
  gem "mysql2"
end

require "active_record"

CONFIGS = {
  "postgresql prepared" => { adapter: "postgresql", host: "127.0.0.1", username: "postgres", database: "repro", prepared_statements: true },
  "postgresql unprepared" => { adapter: "postgresql", host: "127.0.0.1", username: "postgres", database: "repro", prepared_statements: false },
  "mysql2" => { adapter: "mysql2", host: "127.0.0.1", port: 3307, username: "root", database: "repro" },
  "sqlite3" => { adapter: "sqlite3", database: ":memory:" },
}

class Event < ActiveRecord::Base; end

CASES = {
  "find_by_sql DATE :d" => -> { Event.find_by_sql(["SELECT DATE :d AS v", { d: "2026-01-02" }]).first.v },
  "find_by_sql DATE ?" => -> { Event.find_by_sql(["SELECT DATE ? AS v", "2026-01-02"]).first.v },
  "find_by_sql TIMESTAMP :t" => -> { Event.find_by_sql(["SELECT TIMESTAMP :t AS v", { t: "2026-01-02 03:04:05" }]).first.v },
  "find_by_sql TIME :t" => -> { Event.find_by_sql(["SELECT TIME :t AS v", { t: "03:04:05" }]).first.v },
  "find_by_sql INTERVAL :i" => -> { Event.find_by_sql(["SELECT INTERVAL :i AS v", { i: "1 day" }]).first.v },
  "find_by_sql :d::date" => -> { Event.find_by_sql(["SELECT :d::date AS v", { d: "2026-01-02" }]).first.v },
  "find_by_sql CAST(:d AS date)" => -> { Event.find_by_sql(["SELECT CAST(:d AS date) AS v", { d: "2026-01-02" }]).first.v },
  "find_by_sql TIMESTAMPTZ :t" => -> { Event.find_by_sql(["SELECT TIMESTAMPTZ :t AS v", { t: "2026-01-02 03:04:05+00" }]).first.v },
  "find_by_sql TIMESTAMP WITH TIME ZONE :t" => -> { Event.find_by_sql(["SELECT TIMESTAMP WITH TIME ZONE :t AS v", { t: "2026-01-02 03:04:05+00" }]).first.v },
  "find_by_sql JSONB :j" => -> { Event.find_by_sql(["SELECT JSONB :j AS v", { j: '{"a":1}' }]).first.v },
  "find_by_sql :d::date + 1" => -> { Event.find_by_sql(["SELECT :d::date + 1 AS v", { d: "2026-01-02" }]).first.v },
  "find_by_sql DATE '...' + :n" => -> { Event.find_by_sql(["SELECT DATE '2026-01-02' + :n AS v", { n: 1 }]).first.v },
  "find_by_sql :x IS NULL" => -> { Event.find_by_sql(["SELECT (:x IS NULL) AS v", { x: 4 }]).first.v },
  "find_by_sql :a = :b" => -> { Event.find_by_sql(["SELECT (:a = :b) AS v", { a: "x", b: "x" }]).first.v },
  "find_by_sql DATE ? in subquery" => -> { Event.find_by_sql(["SELECT * FROM events WHERE day > DATE ?", "2026-01-01"]).size },
  "count_by_sql DATE :d" => -> { Event.count_by_sql(["SELECT COUNT(*) FROM events WHERE day = DATE :d", { d: "2026-01-02" }]) },
  "where DATE :d" => -> { Event.where("day = DATE :d", d: "2026-01-02").count },
  "where DATE ?" => -> { Event.where("day = DATE ?", "2026-01-02").count },
}

puts "Active Record #{ActiveRecord.version}"
CONFIGS.each do |name, config|
  next if ENV["ONLY"] && !name.include?(ENV["ONLY"])
  ActiveRecord::Base.establish_connection(config)
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define { create_table(:events, force: true) { |t| t.date :day } }
  Event.reset_column_information
  CASES.each do |label, block|
    warn label if ENV["TRACE"]
    result = begin
      block.call.inspect
    rescue ActiveRecord::StatementInvalid => e
      "#{e.class.name.demodulize}: #{e.cause&.message.to_s.lines.first&.strip}"
    end
    puts format("%-22s %-28s %s", name, label, result)
  end
  ActiveRecord::Base.remove_connection
end
