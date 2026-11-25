Base 3f290b759c vs head 3f290b759c; floors from base: sqlite 3.23.0, postgresql 9.5, mysql 5.6.4, ruby 3.2.0

| Version | Build (s) | Base | Head | New failures in head |
| --- | --- | --- | --- | --- |
| SQLite 3.23.1 (floor, Ruby 4.0.9) | 28 | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips |  |
| SQLite 3.38.5 (middle, Ruby 4.0.9) | 39 | pass: 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips | pass: 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips |  |
| SQLite 3.35.5 (extra, Ruby 4.0.9) | 39 | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips |  |
| SQLite 3.36.0 (extra, Ruby 4.0.9) | 35 | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips | fail: 15 runs, 5 assertions, 0 failures, 11 errors, 0 skips |  |
| SQLite 3.37.0 (extra, Ruby 4.0.9) | 35 | pass: 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips | pass: 15 runs, 17 assertions, 0 failures, 0 errors, 0 skips |  |

SQLite 3.23.1 (floor, Ruby 4.0.9), base:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:

SQLite 3.23.1 (floor, Ruby 4.0.9), head:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:

SQLite 3.35.5 (extra, Ruby 4.0.9), base:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:

SQLite 3.35.5 (extra, Ruby 4.0.9), head:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:

SQLite 3.36.0 (extra, Ruby 4.0.9), base:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:

SQLite 3.36.0 (extra, Ruby 4.0.9), head:
  SQLiteDataSourcesTest#test_schema_dump: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_tables: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_create_and_find: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_model_table_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_data_sources: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_schema_cache_data_source_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_views: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_view_exists: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
  SQLiteDataSourcesTest#test_migrate_creates_schema_migrations: ActiveRecord::StatementInvalid: SQLite3::SQLException: no such table: pragma_table_list:
