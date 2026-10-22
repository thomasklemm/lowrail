# frozen_string_literal: true

# Bet G: external artifacts and disposable request screens. No app source or
# config edits. This driver never starts Callgrind or claims an Ir price.
require "json"
require "fileutils"
require "open3"
require "rbconfig"
require "digest"

module GenericSealed
  ROOT = File.expand_path("../..", __dir__)
  LIB = File.join(ROOT, "gem/lib")
  BUILDERS = {
    "form" => ["form_scaffold_build", "FormScaffoldBuild"],
    "token" => ["render_units_build", "TokenTagBuild"],
    "collection" => ["render_units_build", "CollectionRenderBuild"]
  }.freeze
  module_function

  # Same schema-only, external-credential fixture as casa_production_boot.rb.
  # No jobs, seeds, app source/config patches or remote service credentials.
  def casa_credentials(state)
    require "pathname"
    require File.expand_path("config/application")
    Rails.application.config.yjit = false
    Rails.application.config.credentials.content_path = Pathname.new(File.join(state, "production.yml.enc"))
    Rails.application.config.credentials.key_path = Pathname.new(File.join(state, "master.key"))
  end

  def prepare_casa(app, state)
    raise "new external state required" if File.exist?(state) || state.start_with?(app + "/")
    FileUtils.mkdir_p(state, mode: 0o700)
    require "active_support/encrypted_file"
    require "pathname"
    File.write(File.join(state, "master.key"), ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
    ActiveSupport::EncryptedFile.new(content_path: Pathname.new(File.join(state, "production.yml.enc")),
      key_path: Pathname.new(File.join(state, "master.key")), env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true)
      .write("BASE_URL: https://casa.example.invalid\n")
    require "active_record"
    url = environment("casa", app, state).fetch("DATABASE_URL")
    ActiveRecord::Base.establish_connection(url)
    raise "empty disposable CASA database required" unless ActiveRecord::Base.connection.tables.empty?
    ActiveRecord::Schema.verbose = false
    load File.join(app, "db/schema.rb")
    ActiveRecord::Base.connection_pool.disconnect!
  end

  def build(app, out, selection)
    raise "new external artifact directory required" if File.exist?(out) || out.start_with?(app + "/")
    FileUtils.mkdir_p(out)
    request = {"certification_jit" => "interpreter", "denied" => [], "builders" => selection.split(",").map do |name|
      file, mod = BUILDERS.fetch(name)
      {"file" => file, "module" => mod, "pass" => name}
    end}
    preload = ENV["G_CASA_STATE"] ? ["-r", File.expand_path(__FILE__)] : []
    stdout, stderr, status = Open3.capture3({"LOWRAIL" => "0", "RUBYOPT" => nil},
      "bundle", "exec", RbConfig.ruby, *preload, File.join(ROOT, "gem/exe/lowrail-runtime-build"),
      stdin_data: JSON.generate(request), chdir: app)
    File.write(File.join(out, "builder.log"), stderr)
    raise "builder failed: #{stderr.lines.last}" unless status.success?
    rows = JSON.parse(stdout)
    units, files = [], []
    rows.each do |row|
      row.fetch("units").each { |unit| unit["id"] = units.size; units << unit }
      row.fetch("files", []).each do |entry|
        raise "unexpected numeric source parts" unless entry.fetch("parts").all? { String === _1 }
        lowered = File.join(out, "#{Digest::SHA256.hexdigest(entry.fetch('path'))}.rb")
        File.write(lowered, entry.fetch("parts").join)
        files << {"path" => entry.fetch("path"), "lowered" => lowered,
          "source_sha256" => Digest::SHA256.hexdigest(entry.fetch("original"))}
      end
    end
    input = {"out" => out, "app_root" => app, "rails_env" => "production", "tier" => "sealed-v1",
      "certification_jit" => "interpreter", "files" => files, "units" => units}
    path = File.join(out, "input.json")
    File.write(path, JSON.generate(input))
    File.write(File.join(out, "ledger.json"), JSON.pretty_generate(rows.flat_map { _1.fetch("ledger") }))
    stdout, stderr, status = Open3.capture3({"LOWRAIL" => "0", "RUBYOPT" => nil}, "bundle", "exec", RbConfig.ruby,
      File.join(ROOT, "gem/exe/lowrail-compile"), path, chdir: app)
    File.write(File.join(out, "compiler.log"), stdout + stderr)
    raise "compiler failed" unless status.success?
    puts JSON.generate(units: units.map { _1.slice("pass", "sites") }, artifact: out)
  end

  def holders
    labels = {}.compare_by_identity
    ObjectSpace.each_object(Module) do |holder|
      name = Module.instance_method(:name).bind_call(holder)
      labels[holder] = name if name
    end
    ObjectSpace.each_object(Class) do |holder|
      next unless holder.singleton_class?
      attached = holder.attached_object
      next unless Module === attached
      name = Module.instance_method(:name).bind_call(attached)
      labels[holder] = "#{name}.singleton" if name
    end
    entries = labels.to_a
    labels.each do |holder, name|
      view = holder.instance_variable_get(:@view_context_class)
      entries << [view, "#{name}.@view_context_class"] if Module === view
    end
    entries.map do |holder, name|
      [name.gsub(/0x[0-9a-f]+/, "<address>"), {"ancestors" => holder.ancestors.map { Module.instance_method(:name).bind_call(_1)&.gsub(/0x[0-9a-f]+/, "<address>") },
        "methods" => (holder.instance_methods(false) + holder.private_instance_methods(false) + holder.protected_instance_methods(false)).uniq.sort.map do |name|
          method = holder.instance_method(name)
          generated = method.source_location&.first&.include?("/app/views/")
          label = ->(value) { generated ? value.to_s.sub(/_+-?\d+_\d+\z/, "__generated_id") : value.to_s }
          [label.call(name), {"owner" => Module.instance_method(:name).bind_call(method.owner)&.gsub(/0x[0-9a-f]+/, "<address>"), "original_name" => label.call(method.original_name), "parameters" => method.parameters,
            "visibility" => holder.private_method_defined?(name) ? "private" : holder.protected_method_defined?(name) ? "protected" : "public"}]
        end.sort_by { JSON.generate(_1) }}]
    end.sort.to_h
  end

  def screen(kind, app, seed_state, artifact, out)
    raise "new output required" if File.exist?(out)
    FileUtils.mkdir_p(out)
    state = File.join(out, "state")
    require_relative "fizzy_link_fixture"
    require_relative "campfire_scenario"
    seed_state = File.expand_path(seed_state)
    state_env = environment(kind, app, seed_state)
    # Record audited pins before workers; never discover/widen them at runtime.
    # A source-audited companion change starts a separately labeled screen.
    policy_code = <<~'RUBY'
      require ARGV.fetch(0)
      require File.join(ARGV.fetch(1), "config/boot")
      policy = JSON.parse(File.read(ARGV.fetch(2)))
      policy["app_source_sha256"] = BlogProduction::Entropy.source_pin(ARGV.fetch(1))
      policy["lock_sha256"] = Digest::SHA256.file(File.join(ARGV.fetch(1), "Gemfile.lock")).hexdigest
      # Rack 3.2.7 retains exactly the audited 3.2.0 clock_time body; the
      # surrounding utilities changed. No random boundary is added.
      rack = Digest::SHA256.file(BlogProduction::Entropy.source_path("rack:lib/rack/utils.rb")).hexdigest
      policy["runtime_sources"]["rack:lib/rack/utils.rb"] = rack if rack == "82ab7360295a67ebfe3a9dd0502eba3377dc453bf2b9bf778f5dd2a6bd4db18e"
      if ARGV.fetch(3) == "casa"
        # Audited Bugsnag 6.30.0 start_session creates an internal UUID on
        # every GET. Keep that operation live, with its own disposable stream.
        policy["runtime_sources"]["bugsnag:lib/bugsnag/session_tracker.rb"] = "e5ab0ed74a7dcfcd6242d6116166da0b7a7fa75efb0786f2421c6443c9713164"
        %w[SecureRandom SecureRandom::gen_random].each do |provider|
          policy["random_sites"] << {"name" => "bugsnag_session_uuid", "provider" => provider,
            "source" => "bugsnag:lib/bugsnag/session_tracker.rb", "method" => "start_session", "bytes" => 16}
        end
      end
      puts JSON.generate(policy)
    RUBY
    stdout, stderr, status = Open3.capture3(state_env, "bundle", "exec", RbConfig.ruby, "-e", policy_code,
      File.join(ROOT, "fixtures/corpus/blog_entropy.rb"), app,
      File.join(ROOT, "fixtures/corpus/#{kind == 'lobsters' ? 'lobsters-rps-entropy' : 'campfire-entropy-controls'}.json"), kind, chdir: app)
    raise "policy failed: #{stderr}" unless status.success?
    File.write(File.join(out, "policy.json"), stdout)
    [0, 1].each do |seed|
      %w[off_a off_b on].each do |arm|
        FileUtils.rm_rf(state)
        FileUtils.cp_r(seed_state, state)
        if kind == "campfire"
          stdout, stderr, status = Open3.capture3("redis-cli", "FLUSHDB")
          raise "dedicated Redis reset failed: #{stderr}" unless status.success? && stdout.strip == "OK"
        elsif kind == "blog"
          FileUtils.rm_rf(File.join(app, "storage"))
          FileUtils.cp_r(seed_state, File.join(app, "storage"))
        end
        env = environment(kind, app, state)
        env.merge!("LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "1",
          "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => artifact, "RUBYOPT" => nil)
        dest = File.join(out, "#{seed}-#{arm}.json")
        stdout, stderr, status = Open3.capture3(env, "bundle", "exec", RbConfig.ruby, "-I", LIB, "-r", "lowrail/setup",
          File.expand_path(__FILE__), "worker", kind, app, state, dest, seed.to_s, chdir: app)
        File.write(dest.sub(/json\z/, "log"), stdout + stderr)
        raise "#{seed}/#{arm} failed: #{stderr.lines.last(8).join}" unless status.success?
        puts "#{seed}/#{arm}: #{stdout.lines.last}"
      end
    end
  end

  def environment(kind, app, state)
    return FizzyLinkFixture.environment(app, state) if kind == "fizzy"
    return CampfireScenario.environment(app, state) if kind == "campfire"
    if kind == "blog"
      require_relative "../../fixtures/corpus/blog_entropy"
      return {"RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "fatal", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0",
        "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET, "SECRET_KEY_BASE_DUMMY" => nil, "DATABASE_URL" => nil,
        "BUNDLE_GEMFILE" => File.join(app, "Gemfile")}
    end
    if kind == "casa"
      require_relative "../../fixtures/corpus/blog_entropy"
      require "base64"
      return {"RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "fatal", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0",
        "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET, "RAILS_MASTER_KEY" => nil,
        "DATABASE_URL" => "postgresql://postgres@127.0.0.1:55432/lowrail_corpus_casa_g", "APP_ENVIRONMENT" => "lowrail_corpus",
        "SCOUT_MONITOR" => "false", "STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid", "STORAGE_CONTAINER" => "disposable",
        "STORAGE_ACCESS_KEY" => Base64.strict_encode64("disposable-not-a-real-azure-key".ljust(64, "x"))}
    end
    {"RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "fatal", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0",
      "BUNDLE_GEMFILE" => File.join(ROOT, "fixtures/corpus/lobsters-rps.Gemfile"), "BUNDLE_FROZEN" => "true", "DATABASE_URL" => nil}
  end

  def worker(kind, app, state, out, seed)
    require File.join(ROOT, "fixtures/corpus/blog_entropy")
    policy_path = File.join(File.dirname(out), "policy.json")
    policy = JSON.parse(File.read(policy_path))
    require File.join(app, "config/boot")
    control = BlogProduction::Entropy.validate(app, policy: policy)
    raise control.fetch("reason") unless control.fetch("active")
    BlogProduction::Entropy.install(policy)
    # Ruby's default-gem file and the installed OpenSSL gem have identical
    # pinned bytes here, but require can select the former. Record the actual
    # audited file for the same random_iv boundary, never an extra callsite.
    actual = OpenSSL::Cipher.instance_method(:random_iv).source_location.first
    site = BlogProduction::Entropy.instance_variable_get(:@sites).find { _1.fetch("name") == "cookie_iv" }
    raise "OpenSSL source differs" unless Digest::SHA256.file(actual).hexdigest == policy.fetch("runtime_sources").fetch(site.fetch("source"))
    site["path"] = actual
    require_relative "campfire_room_companion"
    SecureRandom.singleton_class.prepend(CampfireRoomCompanion::SessionRandom)
    require File.join(app, "config/application")
    casa_credentials(state) if kind == "casa"
    Rails.application.config.yjit = false
    require File.join(app, "config/environment")
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    raise "interpreter only" unless Lowrail.jit_mode == "interpreter"
    if kind == "fizzy"
      require_relative "fizzy_link_vector"
      driver = FizzyLinkVector::Driver.new(state)
      paths = JSON.parse(File.read(File.join(state, "vector.json")))
      login = -> { driver.login }
      request = ->(path) { driver.request("GET", path) }
    elsif kind == "lobsters"
      file = SQLite3::Database.new(File.join(state, "primary.sqlite3"), readonly: true)
      backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
      backup.step(-1)
      backup.finish
      file.close
      require "rack/mock"
      rack = Rack::MockRequest.new(Rails.application)
      paths = ["/", "/s/enr7ye"]
      login = -> {}
      request = ->(path) { rack.get(path, "HTTPS" => "on", "HTTP_HOST" => "lobste.rs", "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_X_REQUEST_ID" => "generic-sealed") }
    elsif kind == "campfire"
      require_relative "campfire_scenario"
      driver = CampfireScenario::Driver.new(state, validate: false)
      paths = [JSON.parse(File.read(File.join(state, "scenario.json"))).fetch("vector").first.fetch("path")]
      login = -> { driver.login }
      request = ->(path) { driver.request("GET", path) }
    else
      require "rack/mock"
      rack = Rack::MockRequest.new(Rails.application)
      paths = kind == "casa" ? ["/users/sign_in"] : ["/articles/1"]
      login = -> {}
      request = ->(path) { rack.get(path, "HTTPS" => "on", "HTTP_HOST" => "localhost", "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_X_REQUEST_ID" => "generic-sealed") }
    end
    before = holders
    responses = []
    _, entropy = BlogProduction::Entropy.with(Integer(seed), "generic-sealed", requests: (%w[blog lobsters casa].include?(kind) ? 0 : 2) + 3 * paths.size, wall_clock: true) do
      login.call
      3.times do
        paths.each do |path|
          response = request.call(path)
          responses << {"path" => path, "status" => response.status, "headers" => response.headers.to_h,
            "body_sha256" => Digest::SHA256.hexdigest(response.body), "bytes" => response.body.bytesize}
        end
      end
    end
    after = holders
    # Allocation windows have real entropy/clocks. No controlled input escapes
    # the companion thread context. Counter differences, not attribution sums.
    warmup = Integer(ENV.fetch("G_WARMUP", "100"))
    samples = Integer(ENV.fetch("G_SAMPLES", "100"))
    warmup.times { paths.each { request.call(_1) } }
    measures = paths.to_h do |path|
      allocations, walls = [], []
      samples.times do
        start = GC.stat(:total_allocated_objects)
        time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = request.call(path)
        finish = GC.stat(:total_allocated_objects)
        walls << Process.clock_gettime(Process::CLOCK_MONOTONIC) - time
        raise "unexpected HTTP #{response.status}" unless response.status == 200
        allocations << finish - start
      end
      [path, {"allocations" => allocations, "wall_seconds" => walls}]
    end
    runtimes = %w[FormScaffold TokenTag CollectionRender].to_h do |name|
      runtime = Lowrail.const_get(name)
      [name, {"refusal" => runtime.refusal, "admission" => runtime.respond_to?(:admission) ? runtime.admission : nil}]
    end
    File.write(out, JSON.pretty_generate(responses: responses, entropy: entropy, before: before, after: after,
      measures: measures, runtimes: runtimes, stats: Lowrail::Stats.snapshot, refusal: Lowrail.refusal_reason))
    puts JSON.generate(statuses: responses.map { _1.fetch("status") }, runtimes: runtimes,
      hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks,
      objects: measures.transform_values { _1.fetch("allocations").sort[samples / 2] })
  end

  # Export evidence, not cookies, credential files, response bodies or DBs.
  def report(root, out)
    raise "new report required" if File.exist?(out)
    names = %w[blog-isolated-screen fizzy-isolated-screen campfire-isolated-screen casa-isolated-screen2
      blog-screen fizzy-screen2 campfire-screen3 lobsters-screen casa-isolated-screen]
    screens = names.to_h do |name|
      workers = [0, 1].product(%w[off_a off_b on]).to_h do |seed, arm|
        path = File.join(root, name, "#{seed}-#{arm}.json")
        data = JSON.parse(File.read(path))
        row = data.slice("measures", "runtimes", "stats", "refusal")
        row["raw_sha256"] = Digest::SHA256.file(path).hexdigest
        row["response_sha256"] = Digest::SHA256.hexdigest(JSON.generate(data.fetch("responses")))
        row["statuses"] = data.fetch("responses").map { _1.fetch("status") }
        row["entropy_errors"] = data.fetch("entropy").fetch("errors")
        row["holders"] = %w[before after].to_h do |stage|
          holders = data.fetch(stage)
          # The first capture normalized only app templates. Retain raw hashes
          # and compare the ActionText engine's same compiled-template suffix
          # too, preserving method multiplicity and all ownership metadata.
          normalized = Marshal.load(Marshal.dump(holders))
          normalized.each_value do |entry|
            entry["methods"] = entry.fetch("methods").to_a
            entry.fetch("methods").each do |method|
              next unless method.first.include?("_app_views_")
              method[0] = method.first.sub(/_+-?\d+_\d+\z/, "__generated_id")
              meta = method.last
              meta["original_name"] = meta.fetch("original_name").sub(/_+-?\d+_\d+\z/, "__generated_id")
            end
            entry.fetch("methods").sort_by! { JSON.generate(_1) }
          end
          [stage, {"count" => holders.size, "raw_sha256" => Digest::SHA256.hexdigest(JSON.generate(holders)),
            "template_ids_normalized_sha256" => Digest::SHA256.hexdigest(JSON.generate(normalized)),
            "ancestry_sha256" => Digest::SHA256.hexdigest(JSON.generate(holders.transform_values { _1.fetch("ancestors") }))}]
        end
        ["#{seed}-#{arm}", row]
      end
      [name, workers]
    end
    builds = %w[blog-isolated-build2 fizzy-isolated-build campfire-isolated-build casa-isolated-build lobsters-build].to_h do |name|
      path = File.join(root, name, "manifest.json")
      manifest = JSON.parse(File.read(path))
      [name, {"manifest_sha256" => Digest::SHA256.file(path).hexdigest,
        "ledger" => JSON.parse(File.read(File.join(root, name, "ledger.json"))),
        "units" => manifest.fetch("units").map do |unit|
          data = unit.fetch("data")
          {"id" => unit.fetch("id"), "pass" => unit.fetch("pass"), "version" => data["version"],
            "controllers" => data.fetch("controllers", {}).keys,
            "sources_sha256" => Digest::SHA256.hexdigest(JSON.generate(data.fetch("sources")))}
        end}]
    end
    File.write(out, JSON.pretty_generate({"scope" => "Bet G allocation screens, not Ir prices or whole-app verification",
      "warmup" => 100, "samples" => 100, "screens" => screens, "builds" => builds}))
  end
end

if $PROGRAM_NAME == __FILE__
  mode, *args = ARGV
  if mode == "build"
    GenericSealed.build(File.expand_path(args.fetch(0)), File.expand_path(args.fetch(1)), args.fetch(2, "token,collection"))
  elsif mode == "prepare-casa"
    GenericSealed.prepare_casa(*args.map { File.expand_path(_1) })
  elsif mode == "screen"
    GenericSealed.screen(args.fetch(0), *args.drop(1).map { File.expand_path(_1) })
  elsif mode == "worker"
    GenericSealed.worker(*args)
  elsif mode == "report"
    GenericSealed.report(*args.map { File.expand_path(_1) })
  else
    abort "usage: generic_sealed.rb build APP NEW_EXTERNAL_ARTIFACT [token,collection] | screen KIND APP STATE ARTIFACT NEW_OUTPUT"
  end
elsif ENV["G_CASA_STATE"]
  GenericSealed.casa_credentials(ENV.fetch("G_CASA_STATE"))
end
