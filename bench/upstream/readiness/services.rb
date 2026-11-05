# frozen_string_literal: true

# Database services for a readiness round, as Amp orb services named readiness-<name>. Suites list what they need
# (`services: [postgres, mysql, redis, memcached]`); the runner starts the union before a round and stops it after,
# also when the round fails. Data lives in WORK/services and is created on first use:
#   postgres  PostgreSQL 15 on 5432, trust auth, superusers postgres (password postgres) and user
#   postgres18 PostgreSQL 18 on 5418 (socket in /tmp), the same accounts; for suites whose findings need 18.4+
#   mysql     MariaDB on 3306 and /run/mysqld/mysqld.sock, root and user without password from anywhere
#   redis     Redis on 6379, memcached on 11211, no persistence
require "fileutils"
require "socket"

module Readiness
  module Services
    module_function

    NAMES = %w[postgres postgres18 mysql redis memcached].freeze
    PORTS = { "postgres" => 5432, "postgres18" => 5418, "mysql" => 3306, "redis" => 6379, "memcached" => 11211 }.freeze

    def sh(cmd) = system(cmd, out: File::NULL, err: File::NULL)
    def svc(name) = "readiness-#{name}"

    # Starts what isn't listening yet and returns those names, so the round stops only what it started.
    def up(names, work)
      names.filter_map do |n|
        next if listening?(PORTS.fetch(n))
        dir = File.join(work, "services", n)
        Readiness.log "service #{n}: starting"
        send("init_#{n}", dir) if respond_to?("init_#{n}", true)
        raise "service #{n}: amp orb service start failed" unless system("amp", "orb", "service", "start", svc(n), "--command", command(n, dir), out: File::NULL)
        60.times { break if listening?(PORTS[n]); sleep 1 }
        raise "service #{n}: port #{PORTS[n]} not listening" unless listening?(PORTS[n])
        send("ready_#{n}", dir) if respond_to?("ready_#{n}", true)
        n
      end
    end

    def down(names = NAMES)
      names.each { |n| sh("amp orb service stop #{svc(n)}") && Readiness.log("service #{n}: stopped") }
    end

    def listening?(port)
      Socket.tcp("127.0.0.1", port, connect_timeout: 1) { true }
    rescue SystemCallError
      false
    end

    def command(n, dir)
      case n
      when "postgres" then "exec /usr/lib/postgresql/15/bin/postgres -D #{dir} -p 5432 -k /var/run/postgresql -c listen_addresses=127.0.0.1 -c fsync=off -c max_connections=300"
      when "postgres18" then "exec /usr/lib/postgresql/18/bin/postgres -D #{dir} -p 5418 -k /tmp -c listen_addresses=127.0.0.1 -c fsync=off -c max_connections=300"
      when "mysql" then "exec /usr/sbin/mariadbd --no-defaults --datadir=#{dir} --port=3306 --bind-address=127.0.0.1 --socket=/run/mysqld/mysqld.sock --innodb-flush-log-at-trx-commit=2"
      when "redis" then "exec redis-server --port 6379 --save '' --appendonly no"
      when "memcached" then "exec memcached -p 11211 -l 127.0.0.1"
      end
    end

    def owned_run_dir(path) = sh("sudo mkdir -p #{path} && sudo chown #{Process.uid} #{path}")

    def init_postgres(dir)
      owned_run_dir("/var/run/postgresql")
      return if File.exist?(File.join(dir, "PG_VERSION"))
      FileUtils.mkdir_p(File.dirname(dir))
      sh("/usr/lib/postgresql/15/bin/initdb -D #{dir} -U postgres --auth=trust") or raise "initdb failed"
    end

    def ready_postgres(_dir, port = 5432)
      30.times { break if sh("psql -h 127.0.0.1 -p #{port} -U postgres -c 'select 1'"); sleep 1 }
      sh(%(psql -h 127.0.0.1 -p #{port} -U postgres -c 'create role "user" superuser login'))
      sh(%(psql -h 127.0.0.1 -p #{port} -U postgres -c "alter role postgres password 'postgres'"))
    end

    def init_postgres18(dir)
      return if File.exist?(File.join(dir, "PG_VERSION"))
      FileUtils.mkdir_p(File.dirname(dir))
      sh("/usr/lib/postgresql/18/bin/initdb -D #{dir} -U postgres --auth=trust") or raise "initdb failed"
    end

    def ready_postgres18(dir) = ready_postgres(dir, 5418)

    def init_mysql(dir)
      owned_run_dir("/run/mysqld")
      return if Dir.exist?(File.join(dir, "mysql"))
      FileUtils.mkdir_p(dir)
      sh("mariadb-install-db --no-defaults --datadir=#{dir} --auth-root-authentication-method=normal --skip-test-db") or raise "mariadb-install-db failed"
    end

    def ready_mysql(dir)
      return if File.exist?(File.join(dir, ".readiness-users"))
      sql = %w[root user].flat_map { |u| %w[localhost 127.0.0.1 %].map { |h| "CREATE USER IF NOT EXISTS '#{u}'@'#{h}' IDENTIFIED BY ''; GRANT ALL ON *.* TO '#{u}'@'#{h}' WITH GRANT OPTION;" } }.join
      sh("mariadb -uroot --socket=/run/mysqld/mysqld.sock -e #{sql.inspect}") or raise "mysql users failed"
      sh("mariadb-tzinfo-to-sql /usr/share/zoneinfo 2>/dev/null | mariadb -uroot --socket=/run/mysqld/mysqld.sock mysql")
      FileUtils.touch(File.join(dir, ".readiness-users"))
    end
  end
end
