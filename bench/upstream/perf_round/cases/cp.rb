MICRO = {
  "with_connection" => -> { pool = ActiveRecord::Base.connection_pool; pool.release_connection; -> { pool.with_connection { } } },
  "with_connection_leased" => -> { pool = ActiveRecord::Base.connection_pool; pool.lease_connection; -> { pool.with_connection { } } },
  "connection_pool" => -> { -> { ActiveRecord::Base.connection_pool } },
  "connection_handler" => -> { -> { ActiveRecord::Base.connection_handler } },
  "find" => -> { ActiveRecord::Base.connection_pool.release_connection; m = Shipit::User; id = m.first.id; ActiveRecord::Base.connection_pool.release_connection; -> { m.find(id) } },
}
