# frozen_string_literal: true

# U3: untimed non-GET census, extending U/W's allocation-generation method.
# Run from a disposable .corpus/workload-* copy, with its frozen bundle.
require "json"
require "digest"
require "objspace"
require "fileutils"

module WorkloadCensus
  ROOT = File.expand_path("../..", __dir__)
  module_function

  def boot(name)
    raise "disposable workload copy required" unless Dir.pwd.start_with?(ROOT + "/.corpus/workload-")
    raise "no Lowrail preload" if defined?(Lowrail)
    ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
      "SECRET_KEY_BASE_DUMMY" => "1", "SKIP_TELEMETRY" => "1", "RAILS_LOG_LEVEL" => "fatal",
      "APP_VERSION" => "workload-census", "GIT_REVISION" => "workload-census", "SCOUT_MONITOR" => "false")
    if name == "casa"
      # Reuse W's external throwaway-credential fixture; app config is unchanged.
      require "tmpdir"
      require "pathname"
      require "base64"
      require "securerandom"
      require "active_support/encrypted_file"
      ENV.update("APP_ENVIRONMENT" => "lowrail_corpus", "STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid",
        "STORAGE_CONTAINER" => "disposable", "STORAGE_ACCESS_KEY" => Base64.strict_encode64(SecureRandom.random_bytes(64)))
      directory = Dir.mktmpdir("lowrail-u3-casa-")
      at_exit { FileUtils.remove_entry(directory) }
      key = Pathname.new(File.join(directory, "master.key"))
      content = Pathname.new(File.join(directory, "production.yml.enc"))
      File.write(key, ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
      ActiveSupport::EncryptedFile.new(content_path: content, key_path: key, env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true).write("BASE_URL: https://casa.example.invalid\n")
    end
    before = GC.stat(:total_allocated_objects)
    require File.expand_path("config/application")
    if name == "casa"
      Rails.application.config.credentials.content_path = content
      Rails.application.config.credentials.key_path = key
    end
    Rails.application.config.yjit = ENV.fetch("CENSUS_MODE", "interpreter") == "yjit"
    require File.expand_path("config/environment")
    boot_objects = GC.stat(:total_allocated_objects) - before
    raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (ENV.fetch("CENSUS_MODE", "interpreter") == "yjit")
    raise "unexpected ZJIT" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    raise "production eager loading required" unless Rails.application.config.eager_load
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    boot_objects
  end

  def prepare(name)
    raise "fixtures already prepared" if File.exist?("tmp/workload-census-prepared")
    if name == "blog"
      load "db/seeds.rb"
    elsif name == "casa"
      require "factory_bot"
      FactoryBot.create(:casa_admin, email: "census@example.com", confirmed_at: Time.current)
    else
      require "active_record/fixtures"
      path = File.expand_path("test/fixtures")
      names = Dir["#{path}/**/*.yml"].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
      ActiveRecord::FixtureSet.create_fixtures(path, names)
    end
    FileUtils.mkdir_p("tmp")
    File.write("tmp/workload-census-prepared", name)
  end

  def session_cookie(token)
    require "action_dispatch/testing/test_request"
    request = ActionDispatch::TestRequest.create
    request.env.merge!(Rails.application.env_config)
    request.cookie_jar.signed[:session_token] = token
    request.cookie_jar.to_header
  end

  def cookie_from(response)
    Array(response.headers["set-cookie"]).map { _1.split(";", 2).first }.join("; ")
  end

  def csrf(rack, headers, path)
    require "cgi"
    response = rack.get(path, headers)
    raise "setup GET #{path}: #{response.status}" unless response.status == 200
    token = response.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "no CSRF token"
    headers["HTTP_COOKIE"] = cookie_from(response) unless cookie_from(response).empty?
    headers["HTTP_X_CSRF_TOKEN"] = CGI.unescapeHTML(token)
  end

  def request(rack, headers, verb, path, params, status)
    body = params.is_a?(String) ? { input: params } : { params: params }
    response = rack.request(verb, path, headers.merge(body))
    raise "#{verb} #{path}: #{response.status}, expected #{status}" unless response.status == status
    response
  end

  def workloads(name)
    require "rack/mock"
    rack = Rack::MockRequest.new(Rails.application)
    headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ACCEPT" => "text/html",
      "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0" }
    operations = {}
    case name
    when "blog"
      record = Article.order(:id).first!
      csrf(rack, headers, "/articles/#{record.id}/edit")
      operations["POST/form+validations+INSERT+enqueue"] = -> {
        request(rack, headers, "POST", "/articles", { article: { title: "Tallinn Ω", body: "A sufficiently long body." } }, 302)
      }
      n = 0
      operations["PATCH/form+UPDATE+enqueue"] = -> {
        n += 1
        request(rack, headers, "PATCH", "/articles/#{record.id}", { article: { title: "Tallinn #{n}" } }, 303)
      }
      json_headers = headers.merge("HTTP_ACCEPT" => "application/json", "CONTENT_TYPE" => "application/json")
      valid = JSON.generate(article: { title: "Tallinn Ω", body: "A sufficiently long body." })
      invalid = JSON.generate(article: { title: "", body: "short" })
      operations["POST/JSON+INSERT+jbuilder"] = -> { request(rack, json_headers, "POST", "/articles.json", valid, 201) }
      operations["POST/JSON+validation-errors"] = -> { request(rack, json_headers, "POST", "/articles.json", invalid, 422) }
      operations["JSON/jbuilder-show"] = -> { request(rack, json_headers, "GET", "/articles/#{record.id}.json", nil, 200) }
      operations["solid_queue/enqueue"] = -> {
        job = Turbo::Streams::ActionBroadcastJob.perform_later("u3", action: :remove, target: "entry")
        raise "enqueue failed" unless job.successfully_enqueued?
      }
      operations["solid_queue/empty-poll"] = -> {
        raise "nonempty control queue" unless SolidQueue::ReadyExecution.claim(["u3-empty"], 1, 0).empty?
      }
      # 4.1's default Action Cable writer is asynchronous. Charge synchronous
      # persistence separately, rather than calling queued work complete.
      operations["solid_cable/synchronous-persist"] = -> { SolidCable::Message.broadcast("u3", '{"body":"Ω"}') }
      operations["solid_cable/poll-rows"] = -> { SolidCable::Message.broadcastable([SolidCable::Message.channel_hash_for("u3")], 0).limit(10).to_a }
    when "campfire", "fizzy"
      user = User.find_by!(email_address: name == "campfire" ? "david@37signals.com" : "kevin@37signals.com")
      login = name == "campfire" ? user.sessions.start!(user_agent: headers["HTTP_USER_AGENT"], ip_address: "127.0.0.1") : user.sessions.create!
      headers["HTTP_COOKIE"] = session_cookie(name == "campfire" ? login.token : login.signed_id)
      if name == "campfire"
        room = Room.find_by!(name: "All Talk")
        record = room.messages.first!
        csrf(rack, headers, "/rooms/#{room.id}")
        stream_headers = headers.merge("HTTP_ACCEPT" => "text/vnd.turbo-stream.html")
        operations["POST/message+callbacks+Turbo+Redis"] = -> {
          request(rack, stream_headers, "POST", "/rooms/#{room.id}/messages", { message: { body: "U3 Tallinn Ω" } }, 200)
        }
        operations["Turbo/render+broadcast"] = -> { record.broadcast_create }
      else
        record = Bubble.find_by!(creator: user, color: "#3B4B59")
        path = "/buckets/#{record.bucket_id}/bubbles/#{record.id}"
        csrf(rack, headers, path)
        n = 0
        operations["PATCH/bubble+callbacks+UPDATE+enqueue"] = -> {
          n += 1
          request(rack, headers, "PATCH", path, { bubble: { title: "U3 Tallinn #{n}" } }, 302)
        }
        operations["solid_queue/perform"] = -> { AutoPopAllDueJob.perform_now }
        operations["Turbo/perform+broadcast"] = -> {
          Turbo::Streams::ActionBroadcastJob.perform_now("u3", action: :replace, target: "entry", html: "<p>Ω</p>")
        }
        operations["Cable/JSON+broadcast+solid_cable"] = -> { ActionCable.server.broadcast("u3", { body: "Ω", id: 19 }) }
      end
    when "casa"
      user = User.find_by!(email: "census@example.com")
      csrf(rack, headers, "/users/sign_in")
      response = request(rack, headers, "POST", "/users/sign_in", { user: { email: user.email, password: "12345678" } }, 302)
      headers["HTTP_COOKIE"] = cookie_from(response)
      csrf(rack, headers, "/")
      n = 0
      operations["POST/JSON-preference+UPDATE"] = -> {
        n += 1
        request(rack, headers, "POST", "/preference_sets/table_state_update/volunteers", { table_state: { page: n } }, 200)
      }
      operations["mailer/render+MIME-encode"] = -> {
        message = UserMailer.password_changed_reminder(user).message
        raise "incorrect recipient" unless message.to == [user.email]
        message.encoded
      }
      record = user
    when "codetriage"
      record = User.find_by!(github: "mockstar")
      n = 0
      operations["model/validation+callback+UPDATE"] = -> {
        n += 1
        record.update!(name: "U3 Tallinn #{n}")
      }
      operations["model/validation-error"] = -> {
        invalid = User.new(github: "", email: "invalid")
        raise "expected validation error" if invalid.save
        invalid.errors.as_json
      }
    else raise "unknown app #{name}"
    end
    operations["JSON/model-as_json+encode"] = -> { ActiveSupport::JSON.encode(record.as_json) }
    operations
  end

  def source(file)
    return ["unattributed", "<no Ruby source>"] unless file
    return ["app", "APP/" + file.delete_prefix(Rails.root.to_s + "/")] if file.start_with?(Rails.root.to_s + "/")
    spec = Gem.loaded_specs.values.select { file.start_with?(_1.full_gem_path + "/") }.max_by { _1.full_gem_path.size }
    if spec
      owner = if %w[actioncable actionmailer actionpack actionview activejob activemodel activerecord activesupport activestorage actiontext actionmailbox railties].include?(spec.name)
        "rails"
      elsif %w[json uri logger erb base64 date time net-http net-smtp net-imap net-pop bigdecimal securerandom ipaddr].include?(spec.name) || spec.default_gem?
        "ruby"
      else
        "gem"
      end
      return [owner, "GEM/#{spec.name}-#{spec.version}/" + file.delete_prefix(spec.full_gem_path + "/")]
    end
    return ["ruby", "RUBY/" + file.delete_prefix(RbConfig::CONFIG.fetch("rubylibdir") + "/")] if file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/")
    ["unattributed", file.sub(ROOT + "/", "LOWRAIL/")]
  end

  def measure(label, operation)
    warmup = Integer(ENV.fetch("CENSUS_WARMUP", "100"))
    count = Integer(ENV.fetch("CENSUS_OPERATIONS", "10"))
    warmup.times { operation.call }
    totals = 3.times.map do
      GC.start
      before = GC.stat(:total_allocated_objects)
      20.times { operation.call }
      (GC.stat(:total_allocated_objects) - before) / 20.0
    end
    GC.start
    ObjectSpace.trace_object_allocations_clear
    raise "GC already disabled" if GC.disable
    generation = GC.count
    before = GC.stat(:total_allocated_objects)
    ObjectSpace.trace_object_allocations_start
    count.times { operation.call }
    ObjectSpace.trace_object_allocations_stop
    allocated = GC.stat(:total_allocated_objects) - before
    rows = Hash.new(0)
    ObjectSpace.each_object do |object|
      next unless ObjectSpace.allocation_generation(object) == generation
      owner, file = source(ObjectSpace.allocation_sourcefile(object))
      rows[[owner, file, ObjectSpace.allocation_sourceline(object), object.class&.name || "<classless>"]] += 1
    end
    { operation: label, operations: count, warmup: warmup, gc_enabled_objects_per_operation: totals,
      traced_objects: allocated, enumerated: rows.values.sum, unenumerated: allocated - rows.values.sum,
      sites: rows.sort_by { |key, n| [-n, key.to_s] }.map { |(owner, file, line, klass), n|
        { owner: owner, file: file, line: line, class: klass, objects_per_operation: n.fdiv(count) } } }
  ensure
    ObjectSpace.trace_object_allocations_stop
    GC.enable
    ObjectSpace.trace_object_allocations_clear
  end

  def profile(name, output, boot_objects)
    raise "fresh output required" if File.exist?(output)
    operations = workloads(name)
    witnesses = operations.map do |label, operation|
      sql = Hash.new(0)
      callback = ->(*args) { sql[args.last.fetch(:sql).split.first] += 1 }
      value = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { operation.call }
      if label.match?(/INSERT|UPDATE|persist|enqueue/) && sql.values_at("INSERT", "UPDATE").compact.sum.zero?
        raise "#{label}: no database write observed"
      end
      if value.is_a?(Rack::MockResponse) && value.headers["content-type"].to_s.include?("application/json")
        parsed = JSON.parse(value.body)
        raise "swallowed error: #{label}" if parsed.is_a?(Hash) && parsed.key?("error")
      end
      { operation: label, sql: sql, result_class: value.class.name }
    end
    results = operations.map do |label, operation|
      warn "#{name}: #{label}"
      measure(label, operation)
    end
    result = { app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, rails: Rails.version,
      boot_objects: boot_objects, boot_scope: "config/application + config/environment; warm Bootsnap cache; GC enabled; one boot, not timed",
      source: File.read(".lowrail-corpus-source").strip, gems: Gem.loaded_specs.transform_values { _1.version.to_s },
      lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest, witnesses: witnesses, operations: results }
    File.write(output, JSON.pretty_generate(result) + "\n")
    puts JSON.generate(result.except(:operations, :gems).merge(operations: results.map { _1.except(:sites) }))
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  raise "fresh output required" if command == "profile" && File.exist?(output)
  boot_objects = WorkloadCensus.boot(name)
  case command
  when "prepare" then WorkloadCensus.prepare(name)
  when "profile" then WorkloadCensus.profile(name, output, boot_objects)
  when "assets"
    Rails.application.load_tasks
    Rake::Task["assets:precompile"].invoke
  else abort "usage: workload_census.rb prepare|profile|assets APP [NEW_JSON]"
  end
end
