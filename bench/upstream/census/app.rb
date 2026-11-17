# frozen_string_literal: true

# script/census app: the census on an app outside the registered corpus.
#   script/census app DIR [--name N] [--workloads FILE] [--prepare FILE] [--rails SPEC] [--ruby R]
#     [--modes interp] [--env K=V] [--build CMD] [--db TASKS] [--no-assets] [--no-cpu] [--assume-service S] [--fresh]
# DIR is only read: the census works on a copy in .corpus/census-app-NAME and
# writes under .lowrail/private/census-app/NAME. See docs/upstream/census.md.
require_relative "app_report"

module CensusApp
  LOCAL_HOSTS = [nil, "", "localhost", "127.0.0.1", "::1"].freeze
  ADAPTERS = %w[sqlite3 postgresql postgis mysql2 trilogy].freeze
  # Gems whose presence in Gemfile.lock means the app talks to a server at runtime.
  SERVICE_GEMS = { "redis" => %w[redis redis-client sidekiq], "memcached" => %w[dalli] }.freeze
  SERVICE_PORTS = { "redis" => 6379, "memcached" => 11211 }.freeze

  class Refusal < StandardError; end

  module_function

  def root = Census::ROOT

  def refuse(message) = raise(Refusal, message)

  def main(argv)
    opts = { modes: %w[interpreter], env: {}, build: [], assume: [], cpu: true, assets: true }
    parser = OptionParser.new do |o|
      o.banner = "usage: script/census app DIR [options]  (docs/upstream/census.md#run-it-on-your-own-app)"
      o.on("--name N", "copy and output name (default: DIR's basename)") { opts[:name] = _1 }
      o.on("--workloads FILE", "YAML (or .rb) workloads; default: GET pages discovered from the routes") { opts[:workloads] = File.expand_path(_1) }
      o.on("--prepare FILE", "Ruby run inside the booted app to seed the copy's database (default: db/seeds.rb)") { opts[:prepare] = File.expand_path(_1) }
      o.on("--rails SPEC", "also measure on this Rails (main, a commit, OWNER/REPO@REF) next to the app's own") { opts[:rails] = _1 }
      o.on("--ruby R", "Ruby to measure on (default: the app's .ruby-version or Gemfile.lock)") { opts[:ruby] = _1 }
      o.on("--modes LIST", "interp,yjit (default interp)") { |v| opts[:modes] = v.split(",").map { Census::MODES.fetch(_1) } }
      o.on("--env K=V", "extra environment for every step (repeatable), e.g. throwaway secrets") { k, v = _1.split("=", 2); opts[:env][k] = v.to_s }
      o.on("--build CMD", "shell command run in the copy before assets:precompile (repeatable)") { opts[:build] << _1 }
      o.on("--db TASKS", "database tasks (default: db:create db:schema:load, or db:migrate without a schema)") { opts[:db] = _1.split }
      o.on("--no-assets", "skip assets:precompile") { opts[:assets] = false }
      o.on("--no-cpu", "objects only; skip the Callgrind instruction run") { opts[:cpu] = false }
      o.on("--assume-service S", "do not require S (redis, memcached) to be running") { opts[:assume] << _1 }
      o.on("--fresh", "delete this app's copy and results first") { opts[:fresh] = true }
      o.on("--top N", Integer, "report: lines per ranking (default 15)") { opts[:top] = _1 }
      o.on("--refresh", "report: refetch the open rails/rails PRs") { opts[:refresh] = true }
    end
    dir = parser.parse(argv).first or abort(parser.help)
    run(File.expand_path(dir), opts)
  rescue Refusal => e
    abort "census app: #{e.message}"
  end

  def run(source, opts)
    if (var = ENV.keys.find { _1.end_with?("DATABASE_URL") })
      refuse "#{var} is set. The census creates and seeds its own databases; unset every *DATABASE_URL first, " \
        "so it can never write to a database you use."
    end
    refuse "#{source} is not a directory" unless File.directory?(source)
    refuse "#{source} has no config/application.rb; point at a Rails app's root" unless File.exist?(File.join(source, "config/application.rb"))
    refuse "#{source} has no Gemfile.lock; the census measures the locked bundle" unless File.exist?(File.join(source, "Gemfile.lock"))
    name = opts[:name] || File.basename(source).downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    refuse "#{name} is a registered census app; pick another --name" if opts[:name] && Census::APPS.key?(name)
    name += "-own" if Census::APPS.key?(name) # a checkout of a registered app, measured as an outside one
    copy = File.join(root, ".corpus", "census-app-#{name}")
    out = File.join(root, ".lowrail/private/census-app", name)
    refuse "#{source} is inside the census copy" if source.start_with?(copy)
    FileUtils.rm_rf([copy, out]) if opts[:fresh]
    state = setup(source, name, copy, opts)
    services(copy, state, opts)
    bin = Census.ruby_bin(state.fetch("ruby"))
    variants = [["own", state.fetch("base")]]
    variants << ["main", Census.resolve_rails(opts[:rails] == "main" ? "rails/rails@main" : opts[:rails])] if opts[:rails]
    variants.each { |label, rails| measure(name, copy, out, label, rails, bin, opts) }
    report = CensusAppReport.write(out, name, variants.map(&:first), state, top: opts[:top] || 15, refresh: opts[:refresh])
    puts "report: #{report.delete_prefix(root + "/")}"
  end

  # The copy: the app's tracked and untracked-but-not-ignored files (so
  # uncommitted edits count), plus config/database.yml. Nothing is written to DIR.
  def copy_app(source, copy)
    files = if system("git", "-C", source, "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL)
      Census.capture("git", "-C", source, "ls-files", "-z", "-co", "--exclude-standard").split("\0")
    else
      Dir.glob("**/*", File::FNM_DOTMATCH, base: source).reject do |f|
        f.match?(%r{\A(\.git|log|tmp|storage|node_modules|vendor/bundle|public/assets)(/|\z)}) || File.directory?(File.join(source, f))
      end
    end
    files << "config/database.yml" if File.exist?(File.join(source, "config/database.yml"))
    files.uniq.each do |f|
      src = File.join(source, f)
      next unless File.exist?(src) || File.symlink?(src)
      dst = File.join(copy, f)
      FileUtils.mkdir_p(File.dirname(dst))
      File.symlink?(src) ? File.symlink(File.readlink(src), dst) : FileUtils.cp(src, dst, preserve: true)
    end
    unless File.exist?(File.join(copy, "config/database.yml"))
      sample = %w[config/database.yml.sample config/database.yml.example config/database.example.yml].find { File.exist?(File.join(copy, _1)) }
      refuse "no config/database.yml (and no sample to copy) in #{source}" unless sample
      FileUtils.cp(File.join(copy, sample), File.join(copy, "config/database.yml"))
    end
    FileUtils.mkdir_p(%w[log tmp storage .census-app].map { File.join(copy, _1) })
    files.size
  end

  def app_ruby(source, opts)
    return opts[:ruby] if opts[:ruby]
    version = File.read(File.join(source, ".ruby-version")).strip.delete_prefix("ruby-") if File.exist?(File.join(source, ".ruby-version"))
    version ||= File.read(File.join(source, "Gemfile.lock"))[/^RUBY VERSION\n\s+ruby (\d+\.\d+\.\d+)/, 1]
    version || "4.0.9"
  end

  def setup(source, name, copy, opts)
    path = File.join(copy, ".census.json")
    if File.exist?(path)
      state = JSON.parse(File.read(path))
      refuse "#{copy} is a copy of #{state["source"]}, not #{source}; pass --name or --fresh" unless state["source"] == source
      return state if state["ready"]
      puts "removing the unfinished copy #{copy.delete_prefix(root + "/")} and starting again"
      FileUtils.rm_rf(copy)
    end
    version = File.read(File.join(source, "Gemfile.lock"))[/^    railties \(([^)]+)\)/, 1]
    refuse "#{source}/Gemfile.lock has no railties; is this a Rails app?" unless version
    puts "copying #{source} to #{copy.delete_prefix(root + "/")} (#{copy_app(source, copy)} files)"
    env = { "CENSUS_APP" => "1" }
    { workloads: "workloads", prepare: "prepare" }.each do |key, base|
      next unless opts[key]
      refuse "#{key} file not found: #{opts[key]}" unless File.exist?(opts[key])
      dest = File.join(copy, ".census-app", base + File.extname(opts[key]))
      FileUtils.cp(opts[key], dest)
      env["CENSUS_APP_#{key.upcase}"] = dest
    end
    rails = { "own" => true, "spec" => "own", "sha" => "own-#{version}", "version" => version }
    state = { "app" => name, "source" => source, "base" => rails, "ruby" => app_ruby(source, opts), "created" => Time.now.utc.iso8601,
      "workloads" => opts[:workloads], "prepare" => opts[:prepare],
      "conf" => { "env" => env.merge(opts[:env]), "services" => [], "assume" => opts[:assume] } }
    File.write(path, JSON.pretty_generate(state) + "\n")
    bin = Census.ruby_bin(state["ruby"])
    gemfile = begin
      Census.variant("census-app", name, rails, bin)
    rescue RuntimeError => e
      refuse "bundle install failed on Ruby #{state["ruby"]} (#{e.message}). The app's own Gemfile.lock must install; " \
        "pass --ruby if the app needs another Ruby."
    end
    env = Census.env_for(name, bin, rails, gemfile)
    state["databases"] = probe(name, copy, env)
    services(copy, state, opts)
    database(name, copy, env, state, opts)
    opts[:build].each { step(env, copy, "build step failed: #{_1}", "sh", "-c", _1) }
    if opts[:assets] && File.exist?(File.join(copy, "app/assets")) || opts[:assets] && File.exist?(File.join(copy, "app/javascript"))
      step(env, copy, "assets:precompile failed. Pass --build for the app's JS build (e.g. --build 'npm ci') or --no-assets " \
        "if the measured pages do not need compiled assets", "bundle", "exec", "rails", "assets:precompile")
    end
    harness = env.merge("CENSUS_MODE" => "interpreter")
    step(harness, copy, "preparing data failed (#{opts[:prepare] || "db/seeds.rb"}); pass --prepare FILE",
      "bundle", "exec", "ruby", Census::HARNESS, "prepare", name)
    step(harness, copy, "a workload failed; CENSUS_DEBUG=1 prints the exception behind a bare 500",
      "bundle", "exec", "ruby", Census::HARNESS, "list", name)
    state["ready"] = Time.now.utc.iso8601
    File.write(path, JSON.pretty_generate(state) + "\n")
    state
  end

  def step(env, dir, message, *cmd)
    Census.sh(env, *cmd, chdir: dir)
  rescue RuntimeError
    refuse message
  end

  PROBE = <<~RUBY
    require "json"
    require File.expand_path("config/environment")
    dbs = ActiveRecord::Base.configurations.configs_for(env_name: "production", include_hidden: true).map do |c|
      h = c.configuration_hash
      { name: c.name, adapter: c.adapter, database: c.database, host: h[:host], port: h[:port], socket: h[:socket] }
    end
    puts "CENSUS_PROBE " + JSON.generate(rails: Rails.version, databases: dbs)
  RUBY

  # One production boot before anything is written: the census measures
  # production, and refuses databases that are not local and disposable.
  def probe(name, copy, env)
    out, status = Open3.capture2e(env.merge("CENSUS_MODE" => "interpreter"), "bundle", "exec", "ruby", "-e", PROBE, chdir: copy)
    line = out[/^CENSUS_PROBE (.*)$/, 1]
    unless status.success? && line
      refuse "#{name} does not boot in production mode, which is what the census measures:\n" \
        "#{out.lines.reject { _1.match?(/^\s+from /) }.last(12).join}" \
        "Pass the throwaway settings it needs with --env K=V (secrets, hosts), or fix the app's production config."
    end
    probe = JSON.parse(line)
    probe["databases"].each do |db|
      refuse "#{db["name"]}: adapter #{db["adapter"]} is not supported (#{ADAPTERS.join(", ")})" unless ADAPTERS.include?(db["adapter"])
      unless db["adapter"] == "sqlite3" || LOCAL_HOSTS.include?(db["host"]) || db["host"].to_s.start_with?("/")
        refuse "#{db["name"]}: database host #{db["host"]} is not local. The census only creates databases on a local, disposable server."
      end
      if db["adapter"] == "sqlite3" && db["database"].to_s.start_with?("/") && !db["database"].start_with?(copy + "/")
        refuse "#{db["name"]}: SQLite file #{db["database"]} is outside the copy; use a relative path in production"
      end
    end
    probe["databases"]
  end

  # Servers the app needs: its database server and Redis or memcached when
  # their gems are bundled. Refused unless reachable.
  def services(copy, state, opts)
    lock = File.read(File.join(copy, "Gemfile.lock"))
    needed = state.fetch("databases").filter_map do |db|
      next if db["adapter"] == "sqlite3"
      port = db["port"] || (db["adapter"].start_with?("postg") ? 5432 : 3306)
      [db["adapter"].start_with?("postg") ? "postgresql" : "mysql", db["host"], port, db["socket"]]
    end
    SERVICE_GEMS.each do |service, gems|
      next if (state.dig("conf", "assume") + opts[:assume]).include?(service)
      gem = gems.find { lock.match?(/^    #{Regexp.escape(_1)} \(/) }
      needed << [service, "127.0.0.1", SERVICE_PORTS.fetch(service), nil, gem] if gem
    end
    needed.uniq.each do |service, host, port, socket, gem|
      ok = if service == "postgresql" && (host.to_s.empty? || host.start_with?("/"))
        system("pg_isready", "-q", *(["-h", host || socket] if host || socket))
      else
        begin
          Socket.tcp(host.to_s.empty? ? "127.0.0.1" : host, port, connect_timeout: 1).close
          true
        rescue SystemCallError, IOError, SocketError
          false
        end
      end
      next if ok
      why = gem ? " (the bundle has #{gem}; pass --assume-service #{service} if the measured requests never use it)" : ""
      refuse "#{service} is not reachable at #{host.to_s.empty? ? "localhost" : host}:#{port}#{why}. " \
        "Start a disposable local #{service}; the census writes to it."
    end
  end

  def database(name, copy, env, state, opts)
    tasks = opts[:db] || (%w[db/schema.rb db/structure.sql].any? { File.exist?(File.join(copy, _1)) } ? %w[db:create db:schema:load] : %w[db:create db:migrate])
    out, status = Open3.capture2e(env, "bundle", "exec", "rails", *tasks.take(1), chdir: copy)
    print out
    refuse "#{tasks.first} failed" unless status.success?
    # A server database that already exists may hold someone's data.
    existing = out.scan(/^Database '([^']+)' already exists/).flatten - out.scan(/^Created database '([^']+)'/).flatten
    if existing.any? && state["databases"].any? { _1["adapter"] != "sqlite3" }
      refuse "#{existing.join(", ")} already exist on the database server. The census loads its own schema and data and " \
        "would overwrite them; drop them first if they are disposable, or point production at other names with --env."
    end
    step(env, copy, "#{tasks.drop(1).join(" ")} failed", "bundle", "exec", "rails", *tasks.drop(1)) if tasks.size > 1
  end

  def measure(name, copy, out, label, rails, bin, opts)
    labels = [label, "#{label}2"]
    files = labels.product(opts[:modes]).map { |l, m| File.join(out, l, "#{name}-#{m}.json") }
    unless files.all? { File.exist?(_1) }
      FileUtils.rm_rf(labels.map { File.join(out, _1) })
      begin
        Census.run(corpus: "census-app", out: out, label: label, aa: true, apps: [name], modes: opts[:modes], jobs: 1, gems: {},
          ruby: bin, rails: (rails["spec"] unless rails["own"]))
      rescue RuntimeError => e
        log = Dir[File.join(out, label + "*", "*.log")].max_by { File.mtime(_1) }
        tail = log ? File.readlines(log).reject { _1.match?(/^\s+from /) }.last(8).join : ""
        refuse "measuring on Rails #{rails["spec"]} failed: #{e.message}\n#{tail}" \
          "#{"The app may not install or boot on this Rails; the report for its own Rails is unaffected." unless rails["own"]}"
      end
    end
    return unless opts[:cpu]
    valgrind = File.join(ENV.fetch("VALGRIND_PREFIX", "/opt/c8-valgrind"), "bin/valgrind")
    return warn("instructions skipped: no patched Valgrind at #{valgrind} (script/cpu-census build)") unless File.executable?(valgrind)
    cpu = File.join(out, "cpu")
    return if labels.product(opts[:modes]).all? { |l, m| File.exist?(File.join(cpu, l, "#{name}-#{m}.json")) }
    FileUtils.rm_rf(labels.map { File.join(cpu, _1) })
    Census.sh({}, File.join(root, "script/cpu-census"), "run", "--label", label, "--aa", "--apps", name, "--corpus", "census-app",
      "--out", cpu, "--ruby", bin, "--modes", opts[:modes].join(","), *(["--rails", rails["spec"]] unless rails["own"]))
  end
end
