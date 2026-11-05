# For ruby-bench lobsters and shipit, whose production DB is :memory:: copy the committed sqlite file in, then count.
# RAILS_ENV=production SECRET_KEY_BASE=x COUNT_DB=db/production.sqlite3 bin/rails runner op8_count_mem.rb
mem_db = ActiveRecord::Base.connection.raw_connection
b = SQLite3::Backup.new(mem_db, "main", SQLite3::Database.new(ENV.fetch("COUNT_DB")), "main"); b.step(-1); b.finish
load ENV.fetch("COUNT_SCRIPT", File.expand_path("../../op8_count_models.rb", __dir__))
