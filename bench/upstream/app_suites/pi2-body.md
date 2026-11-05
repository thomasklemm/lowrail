### Note in the upgrade guide that PostgreSQL 18.4+ fixture loading takes more locks

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2": on PostgreSQL 18.4+, parallel test workers loading fixtures can run out of shared lock memory, and raising `max_locks_per_transaction` fixes it.

#57378 made `disable_referential_integrity` switch every foreign key to `NOT ENFORCED` and back in one transaction ([`toggle_foreign_key_enforcement`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/postgresql/referential_integrity.rb#L92-L102)). Each switch drops and recreates the constraint's triggers and locks both tables and their indexes until commit. With 300 foreign keys on PostgreSQL 18.6, one call holds 2,558 locks; `DISABLE TRIGGER ALL` on 8-1-stable held 161. [`insert_fixtures_set`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb#L685-L695) runs inside it.

An app's parallel test suite with 8 workers failed in one of two runs on main with `PG::OutOfMemory: out of shared memory` at the default of 64, and passed with 256. In a [repro](https://github.com/thomasklemm/lowrail/blob/4944401376b5cc789016b69c8efbc54211f67b9c/bench/upstream/app_suites/fk_fixture_locks.rb) where 8 processes each empty their own database and load fixtures, 20 to 24 of 24 failed on main, none on 8-1-stable or with 256.

No code change: skipping the toggle in `truncate_tables` is safe but still fails, because fixture loading alone fills the table, and toggling only the fixture tables doesn't help `fixtures :all`.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
