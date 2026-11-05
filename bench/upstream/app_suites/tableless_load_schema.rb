# A model without a table that overrides `load_schema!` and `columns_hash`, as OpenProject's
# Tableless concern does (Day queries a generate_series subquery through `from`).
# RAILS=/path/to/rails ruby tableless_load_schema.rb   (PostgreSQL via PGHOST/PGPORT/PGUSER)
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |g| $LOAD_PATH.unshift File.join(rails, g, "lib") }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")

class Day < ActiveRecord::Base
  class << self
    def load_schema!
      # noop: there is no "days" table
    end

    def columns_hash
      @columns_hash ||= {}
    end
  end

  attribute :date, :date
  attribute :working, :boolean
end

sql = "(SELECT d::date AS date, extract(isodow FROM d) < 6 AS working " \
      "FROM generate_series('2026-11-02'::date, '2026-11-08'::date, '1 day') d) days"
begin
  puts "working days: #{Day.from(sql).where(working: true).count}"
rescue => e
  puts "#{e.class}: #{e.message.lines.first}"
end
