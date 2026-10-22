# frozen_string_literal: true

# Bet W: Bet U's allocation-generation census, without a Rails-only filter.
# Run from a disposable .corpus/gem-census-* app with its frozen bundle.
require "json"
require "digest"
require "objspace"
require "fileutils"

module GemCensus
  ROOT = File.expand_path("../..", __dir__)
  module_function

  def boot(name)
    raise "disposable census copy required" unless Dir.pwd.start_with?(ROOT + "/.corpus/gem-census-")
    raise "no Lowrail preload" if defined?(Lowrail)
    ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
      "SECRET_KEY_BASE_DUMMY" => ENV["SECRET_KEY_BASE"] ? nil : "1", "SKIP_TELEMETRY" => "1", "RAILS_LOG_LEVEL" => "fatal",
      "APP_VERSION" => "gem-census", "GIT_REVISION" => "gem-census", "SCOUT_MONITOR" => "false")
    if name == "casa"
      # Same external throwaway credential fixture as casa_production_boot.rb.
      require "tmpdir"
      require "pathname"
      require "base64"
      require "securerandom"
      require "active_support/encrypted_file"
      ENV.update("APP_ENVIRONMENT" => "lowrail_corpus", "STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid",
        "STORAGE_CONTAINER" => "disposable", "STORAGE_ACCESS_KEY" => Base64.strict_encode64(SecureRandom.random_bytes(64)))
      directory = Dir.mktmpdir("lowrail-gem-census-casa-")
      at_exit { FileUtils.remove_entry(directory) }
      key = Pathname.new(File.join(directory, "master.key"))
      content = Pathname.new(File.join(directory, "production.yml.enc"))
      File.write(key, ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
      ActiveSupport::EncryptedFile.new(content_path: content, key_path: key, env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true).write("BASE_URL: https://casa.example.invalid\n")
    end
    require File.expand_path("config/application")
    if name == "casa"
      Rails.application.config.credentials.content_path = content
      Rails.application.config.credentials.key_path = key
    end
    mode = ENV.fetch("CENSUS_MODE", "interpreter")
    Rails.application.config.yjit = mode == "yjit"
    require File.expand_path("config/environment")
    raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (mode == "yjit")
    raise "unexpected ZJIT" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    if ENV["CENSUS_CANDIDATE"]
      load ENV.fetch("CENSUS_CANDIDATE")
    end
  end

  def prepare(name)
    raise "fixtures already prepared" if File.exist?("tmp/gem-census-prepared")
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
    File.write("tmp/gem-census-prepared", name)
  end

  def cookie(token)
    require "action_dispatch/testing/test_request"
    request = ActionDispatch::TestRequest.create
    request.env.merge!(Rails.application.env_config)
    request.cookie_jar.signed[:session_token] = token
    request.cookie_jar.to_header
  end

  def workload(name)
    require "rack/mock"
    headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ACCEPT" => "text/html",
      "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"}
    rack = Rack::MockRequest.new(Rails.application)
    routes = case name
    when "blog"
      article = Article.order(:id).first!
      ["/articles", "/articles/#{article.id}", "/articles/#{article.id}/edit"]
    when "campfire", "fizzy"
      user = User.find_by!(email_address: name == "campfire" ? "david@37signals.com" : "kevin@37signals.com")
      if name == "campfire"
        login = user.sessions.start!(user_agent: headers["HTTP_USER_AGENT"], ip_address: "127.0.0.1")
        headers["HTTP_COOKIE"] = cookie(login.token)
      else
        login = user.sessions.create!(user_agent: headers["HTTP_USER_AGENT"], ip_address: "127.0.0.1")
        headers["HTTP_COOKIE"] = cookie(login.signed_id)
      end
      if name == "campfire"
        ["/rooms/#{Room.find_by!(name: "All Talk").id}", "/users/me/sidebar", "/searches?q=coffee"]
      else
        ["/buckets", "/bubbles", "/notifications"]
      end
    when "codetriage"
      ["/", "/?language=Ruby", "/privacy"]
    when "casa"
      # Genuine Devise login, outside allocation/Ir endpoints. No test-mode Warden injection.
      require "cgi"
      page = rack.get("/users/sign_in", headers)
      token = page.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "missing login CSRF"
      headers["HTTP_COOKIE"] = Array(page.headers["set-cookie"]).map { _1.split(";", 2).first }.join("; ")
      logged_in = rack.post("/users/sign_in", headers.merge(params: {"authenticity_token" => CGI.unescapeHTML(token),
        "user" => {"email" => "census@example.com", "password" => "12345678"}}))
      raise "Devise login failed: #{logged_in.status}" unless logged_in.status == 302
      headers["HTTP_COOKIE"] = Array(logged_in.headers["set-cookie"]).map { _1.split(";", 2).first }.join("; ")
      ["/", "/volunteers", "/casa_cases"]
    else raise "unknown app"
    end
    Current.reset if defined?(Current)
    [rack, headers, routes]
  end

  def source(file)
    return "<no Ruby source>" unless file
    return file.sub(Rails.root.to_s + "/", "APP/") if file.start_with?(Rails.root.to_s + "/")
    # Resolve ownership using loaded gem specifications, including git/path gems.
    spec = Gem.loaded_specs.values.select { file.start_with?(_1.full_gem_path + "/") }.max_by { _1.full_gem_path.size }
    return "GEM/#{spec.name}-#{spec.version}/#{file.delete_prefix(spec.full_gem_path + "/")}" if spec
    file.sub(ROOT + "/", "LOWRAIL/").sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/")
  end

  def profile(name, output)
    raise "fresh output required" if File.exist?(output)
    rack, headers, routes = workload(name)
    results = routes.map do |route|
      request = -> {
        response = rack.get(route, headers)
        raise "#{route}: HTTP #{response.status}, #{response.body.bytesize} bytes" unless response.status == 200 && !response.body.empty?
        nil
      }
      warmup = Integer(ENV.fetch("CENSUS_WARMUP", "100"))
      warmup.times { request.call }
      totals = 3.times.map do
        GC.start
        before = GC.stat(:total_allocated_objects)
        20.times { request.call }
        (GC.stat(:total_allocated_objects) - before) / 20.0
      end
      count = Integer(ENV.fetch("CENSUS_REQUESTS", "10"))
      GC.start
      ObjectSpace.trace_object_allocations_clear
      raise "GC already disabled" if GC.disable
      generation = GC.count
      before = GC.stat(:total_allocated_objects)
      ObjectSpace.trace_object_allocations_start
      count.times { request.call }
      ObjectSpace.trace_object_allocations_stop
      allocated = GC.stat(:total_allocated_objects) - before
      rows = Hash.new(0)
      ObjectSpace.each_object do |object|
        next unless ObjectSpace.allocation_generation(object) == generation
        rows[[source(ObjectSpace.allocation_sourcefile(object)), ObjectSpace.allocation_sourceline(object), object.class&.name || "<classless>"]] += 1
      end
      GC.enable
      ObjectSpace.trace_object_allocations_clear
      {route: route, requests: count, warmup: warmup, gc_enabled_objects_per_request: totals,
        traced_gc_objects: allocated, enumerated: rows.values.sum, unenumerated: allocated - rows.values.sum,
        sites: rows.sort_by { |key, n| [-n, key.to_s] }.map { |(file, line, klass), n|
          {file: file, line: line, class: klass, objects_per_request: n.fdiv(count)} }}
    end
    result = {app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, rails: Rails.version,
      source: File.read(".lowrail-corpus-source").strip, gems: Gem.loaded_specs.transform_values { _1.version.to_s },
      lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest, routes: results}
    File.write(output, JSON.pretty_generate(result) + "\n")
    puts JSON.generate(result.except(:routes, :gems).merge(routes: results.map { _1.except(:sites) }))
  ensure
    ObjectSpace.trace_object_allocations_stop
    GC.enable
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  GemCensus.boot(name)
  case command
  when "prepare" then GemCensus.prepare(name)
  when "profile" then GemCensus.profile(name, output)
  when "assets"
    Rails.application.load_tasks
    Rake::Task["assets:precompile"].invoke
  else abort "usage: gem_census.rb prepare|profile|assets APP NEW_JSON"
  end
end
