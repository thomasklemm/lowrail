# RAILS=path ruby raw_execute_hook.rb -> prepends a raw_execute override on the adapter, as Gumroad's
# MysqlReadOnlyPrimaryRetry does, and counts its calls for one INSERT. 8-1: 1; main: 0 (no raw_execute any more).
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
require "active_record/connection_adapters/sqlite3_adapter"
CALLS = []
module RawExecuteHook
  private
    def raw_execute(sql, *args, **kwargs, &block)
      CALLS << sql
      super
    end
end
ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(RawExecuteHook)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.connection.execute("CREATE TABLE posts (id integer)")
CALLS.clear
ActiveRecord::Base.connection.execute("INSERT INTO posts (id) VALUES (1)")
puts "#{ActiveRecord.version}: raw_execute override called #{CALLS.size} time(s)"
exit(CALLS.size == 1 ? 0 : 1)
