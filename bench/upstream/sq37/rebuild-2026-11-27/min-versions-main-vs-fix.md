Base 088fc0cf61 vs head 3e348f32bd; floors from base: sqlite 3.35.0, postgresql 10.0, mysql 5.7.9, ruby 3.3.5

| Version | Build (s) | Base | Head | New failures in head |
| --- | --- | --- | --- | --- |
| SQLite 3.35.5 (floor, Ruby 4.0.9) | 90 | fail: crashed; 15 runs, 4 assertions, 0 failures, 12 errors, 0 skips | fail: crashed; 15 runs, 0 assertions, 0 failures, 15 errors, 0 skips | SQLiteDataSourcesTest#test_control_raw_sql, SQLiteDataSourcesTest#test_control_columns, SQLiteDataSourcesTest#test_create_table_force |
| SQLite 3.44.2 (middle, Ruby 4.0.9) | 125 | pass: 115 runs, 283 assertions, 0 failures, 0 errors, 0 skips; 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips | pass: 116 runs, 286 assertions, 0 failures, 0 errors, 0 skips; 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips |  |
| SQLite 3.36.0 (extra, Ruby 4.0.9) | 111 | fail: crashed; 15 runs, 4 assertions, 0 failures, 12 errors, 0 skips | fail: crashed; 15 runs, 0 assertions, 0 failures, 15 errors, 0 skips | SQLiteDataSourcesTest#test_control_raw_sql, SQLiteDataSourcesTest#test_control_columns, SQLiteDataSourcesTest#test_create_table_force |
| SQLite 3.37.0 (extra, Ruby 4.0.9) | 122 | pass: 115 runs, 280 assertions, 0 failures, 0 errors, 1 skips; 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips | pass: 116 runs, 283 assertions, 0 failures, 0 errors, 1 skips; 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips |  |

SQLite 3.35.5 (floor, Ruby 4.0.9), base:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_column_names: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  crashed before minitest reported:
    /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.35.5/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/statement.rb:36:in 'SQLite3::Statement#prepare': SQLite3::SQLException: no such table: pragma_table_list: (ActiveRecord::StatementInvalid)
    SELECT name FROM pragma_table_list WHERE schema <> 'temp' AND name NOT IN ('sqlite_sequence', 'sqlite_schema') AND name = 'schema_migrations' AND type IN ('table')
    	from /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.35.5/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/statement.rb:36:in 'SQLite3::Statement#initialize'
    	from /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.35.5/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/database.rb:215:in 'SQLite3::Database#prepare'
    	from /home/user/.cache/lowrail-min-versions/trees/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:124:in 'ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements#perform_query'
    	from /home/user/.cache/lowrail-min-versions/trees/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb:765:in 'Act

SQLite 3.35.5 (floor, Ruby 4.0.9), head:
  SQLiteDataSourcesTest#test_schema_dump: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_data_source_exists: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_column_names: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_table_exists: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_tables: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_control_raw_sql: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_control_columns: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_create_and_find: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_table_exists: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_data_sources: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_create_table_force: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_views: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_view_exists: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: RuntimeError: Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0.
  crashed before minitest reported:
    /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb:520:in 'ActiveRecord::ConnectionAdapters::SQLite3Adapter#check_version': Your version of SQLite (3.35.5) is too old. Active Record supports SQLite >= 3.37.0. (RuntimeError)
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1463:in 'ActiveRecord::ConnectionAdapters::AbstractAdapter#configure_connection'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb:989:in 'ActiveRecord::ConnectionAdapters::SQLite3Adapter#configure_connection'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:858:in 'block (3 levels) in ActiveRecord::ConnectionAdapters::AbstractAdapter#reconnect!'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection

SQLite 3.36.0 (extra, Ruby 4.0.9), base:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_column_names: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  crashed before minitest reported:
    /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.36.0/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/statement.rb:36:in 'SQLite3::Statement#prepare': SQLite3::SQLException: no such table: pragma_table_list: (ActiveRecord::StatementInvalid)
    SELECT name FROM pragma_table_list WHERE schema <> 'temp' AND name NOT IN ('sqlite_sequence', 'sqlite_schema') AND name = 'schema_migrations' AND type IN ('table')
    	from /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.36.0/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/statement.rb:36:in 'SQLite3::Statement#initialize'
    	from /home/user/.cache/lowrail-min-versions/bundle/ruby-4.0.9/sqlite-3.36.0/ruby/4.0.0/gems/sqlite3-2.10.2/lib/sqlite3/database.rb:215:in 'SQLite3::Database#prepare'
    	from /home/user/.cache/lowrail-min-versions/trees/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:124:in 'ActiveRecord::ConnectionAdapters::SQLite3::DatabaseStatements#perform_query'
    	from /home/user/.cache/lowrail-min-versions/trees/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb:765:in 'Act

SQLite 3.36.0 (extra, Ruby 4.0.9), head:
  SQLiteDataSourcesTest#test_schema_dump: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_data_source_exists: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_column_names: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_table_exists: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_tables: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_control_raw_sql: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_control_columns: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_create_and_find: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_model_table_exists: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_data_sources: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_create_table_force: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_views: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_view_exists: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: RuntimeError: Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0.
  crashed before minitest reported:
    /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb:520:in 'ActiveRecord::ConnectionAdapters::SQLite3Adapter#check_version': Your version of SQLite (3.36.0) is too old. Active Record supports SQLite >= 3.37.0. (RuntimeError)
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1463:in 'ActiveRecord::ConnectionAdapters::AbstractAdapter#configure_connection'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb:989:in 'ActiveRecord::ConnectionAdapters::SQLite3Adapter#configure_connection'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:858:in 'block (3 levels) in ActiveRecord::ConnectionAdapters::AbstractAdapter#reconnect!'
    	from /home/user/.cache/lowrail-min-versions/trees/3e348f32bdc2b5b405d31f226e6de04aa3278dc9/activerecord/lib/active_record/connection
