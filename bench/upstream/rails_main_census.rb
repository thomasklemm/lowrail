# frozen_string_literal: true

# Stock Rails request census. Dependency overlays only; no Lowrail preload.
# From the app's frozen bundle: ruby SCRIPT prepare|profile APP_NAME OUTPUT
# State lives under the caller's app copy, never in a shared database.
require "json"
require "digest"
require "objspace"
require "fileutils"

module RailsMainCensus
  RAILS_PIN = "33748f4f60e68eeeed0d48ac566d345415dc78f4"
  ROOT = File.expand_path("../..", __dir__)

  module_function
  def boot(name)
    raise "disposable census copy required" unless Dir.pwd.start_with?(ROOT + "/.corpus/census-")
    raise "no Lowrail preload" if defined?(Lowrail)
    ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
      "SECRET_KEY_BASE_DUMMY" => "1", "SKIP_TELEMETRY" => "1", "DATABASE_ADAPTER" => "sqlite",
      "RAILS_LOG_LEVEL" => "fatal", "APP_VERSION" => "census", "GIT_REVISION" => RAILS_PIN)
    require File.expand_path("config/application")
    mode = ENV.fetch("CENSUS_MODE", "interpreter")
    Rails.application.config.yjit = mode == "yjit"
    # Writebook manually enables YJIT independently of config.yjit. Temporarily
    # hide only this VM entry point during interpreter boot, then restore it.
    # This external execution-policy control does not edit the app initializer.
    manual_enable = RubyVM::YJIT.method(:enable) if name == "writebook" && mode == "interpreter"
    RubyVM::YJIT.singleton_class.undef_method(:enable) if manual_enable
    begin
      require File.expand_path("config/environment")
    ensure
      RubyVM::YJIT.define_singleton_method(:enable, manual_enable) if manual_enable
    end
    raise "wrong Rails revision" unless Gem.loaded_specs.fetch("railties").full_gem_path.include?(RAILS_PIN[0, 12])
    raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (mode == "yjit")
    raise "unexpected ZJIT" if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
  end

  def prepare(name)
    marker = "tmp/census-fixtures.json"
    raise "fixtures already prepared" if File.exist?(marker)
    require "active_record/fixtures"
    if name == "blog"
      load "db/seeds.rb"
    else
      if name == "fizzy"
        # Reuse the pinned app's actual UUID fixture policy, only in preparation.
        helper = File.read("test/test_helper.rb").split("module FixturesTestHelper\n", 2).fetch(1)
        eval("module FixturesTestHelper\n" + helper, TOPLEVEL_BINDING, "test/test_helper.rb")
      end
      path = File.expand_path("test/fixtures")
      names = Dir["#{path}/**/*.yml"].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
      ActiveRecord::FixtureSet.create_fixtures(path, names)
    end
    FileUtils.mkdir_p("tmp")
    File.write(marker, JSON.generate(name: name, rails: RAILS_PIN, lock: Digest::SHA256.file("Gemfile.lock").hexdigest))
  end

  def workload(name)
    require "rack/mock"
    require "action_dispatch/testing/test_request" unless name == "blog"
    headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ACCEPT" => "text/html",
      "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0" }
    routes = case name
    when "blog"
      article = Article.order(:id).first!
      ["/articles", "/articles/#{article.id}", "/articles/#{article.id}/edit"]
    when "campfire", "writebook"
      user = User.find_by!(email_address: name == "campfire" ? "david@37signals.com" : "david@example.com")
      login = user.sessions.start!(user_agent: headers["HTTP_USER_AGENT"], ip_address: "127.0.0.1")
      headers.merge!(cookie(login.token))
      if name == "campfire"
        room = Room.find_by!(name: "All Talk")
        ["/rooms/#{room.id}", "/users/me/sidebar", "/searches?q=coffee"]
      else
        book = Book.find_by!(slug: "handbook")
        leaf = book.leaves.find_by!(title: "Welcome to The Handbook!")
        ["/", "/#{book.id}/#{book.slug}", "/#{book.id}/#{book.slug}/#{leaf.id}/#{leaf.slug}"]
      end
    when "fizzy"
      identity = Identity.find_by!(email_address: "kevin@37signals.com")
      login = identity.sessions.create!
      headers.merge!(cookie(login.signed_id))
      account = identity.users.find_by!(name: "Kevin").account
      prefix = "/#{account.external_account_id}"
      board = account.boards.find_by!(name: "Writebook")
      ["#{prefix}/boards/#{board.id}", "#{prefix}/cards", "#{prefix}/notifications"]
    else
      raise "unknown app"
    end
    Current.reset if defined?(Current)
    [Rack::MockRequest.new(Rails.application), headers, routes]
  end

  def cookie(token)
    request = ActionDispatch::TestRequest.create
    request.env.merge!(Rails.application.env_config)
    request.cookie_jar.signed[:session_token] = token
    { "HTTP_COOKIE" => request.cookie_jar.to_header }
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
        file = ObjectSpace.allocation_sourcefile(object)
        file = if file.nil?
          "<no Ruby source>"
        elsif file.start_with?(Rails.root.to_s + "/")
          file.sub(Rails.root.to_s + "/", "APP/")
        elsif file.include?("/rails-#{RAILS_PIN[0, 12]}/")
          "RAILS/" + file.split("/rails-#{RAILS_PIN[0, 12]}/", 2).last
        elsif file.include?("/gems/")
          "GEM/" + file.split("/gems/", 2).last
        elsif file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/")
          file.sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/")
        else
          file.sub(ROOT + "/", "LOWRAIL/")
        end
        rows[[file, ObjectSpace.allocation_sourceline(object), object.class&.name || "<classless>"]] += 1
      end
      GC.enable
      ObjectSpace.trace_object_allocations_clear
      { route: route, requests: count, warmup: warmup, gc_enabled_objects_per_request: totals,
        traced_gc_objects: allocated, enumerated: rows.values.sum, unenumerated: allocated - rows.values.sum,
        sites: rows.sort_by { |key, n| [-n, key.to_s] }.map { |(file, line, klass), n|
          { file: file, line: line, class: klass, objects_per_request: n.fdiv(count) } } }
    end
    result = { app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, rails: RAILS_PIN,
      lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest, routes: results }
    File.write(output, JSON.pretty_generate(result) + "\n")
    puts JSON.generate(result.except(:routes).merge(routes: results.map { _1.except(:sites) }))
  ensure
    ObjectSpace.trace_object_allocations_stop
    GC.enable
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsMainCensus.boot(name)
  case command
  when "prepare" then RailsMainCensus.prepare(name)
  when "profile" then RailsMainCensus.profile(name, output)
  else abort "usage: rails_main_census.rb prepare|profile APP_NAME [NEW_JSON]"
  end
end
