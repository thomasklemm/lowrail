# frozen_string_literal: true

# Rejected research diagnostic, never loaded by the Lowrail gem. Do not use
# this as an application preload: loader-policy counterexamples are known.
# ruby boot_image.rb run CONFIG_JSON NEW_OUTPUT_DIRECTORY
# CONFIG: app, path, env; optional before_boot (external credentials fixture).
require "json"
require "digest"
require "digest/sha2"
require "fileutils"
require "rbconfig"

module BootImage
  ROOT = File.expand_path("../..", __dir__)
  API = RubyVM::InstructionSequence
  module_function

  def memory(pid = "self")
    File.readlines("/proc/#{pid}/smaps_rollup").filter_map do |line|
      key, value = line.split
      [key.delete_suffix(":"), value.to_i] if %w[Rss: Pss: Private_Dirty: Shared_Dirty:].include?(key)
    end.to_h
  end

  def capture
    @files, @misses, @hits = {}, [], 0
    @entry_ruby = RUBY_DESCRIPTION
    @entry_load_path, @entry_gems = $LOAD_PATH.dup, gem_versions
    API.singleton_class.prepend(Capture)
  end

  module Capture
    def translate(iseq)
      iseq = super if defined?(super)
      BootImage.record(iseq)
      iseq
    end
  end

  def record(iseq)
    path = iseq.absolute_path
    return unless path && File.file?(path) && iseq.to_a[9] == :top
    @files[path] = {"sha256" => Digest::SHA256.file(path).hexdigest,
      "options" => API.compile_option, "binary" => iseq.to_binary}
  rescue RuntimeError, TypeError => error
    @misses << [path, error.message]
  end

  def save(path)
    File.binwrite(path, Marshal.dump({"ruby" => @entry_ruby,
      "load_path" => @entry_load_path, "gems" => @entry_gems,
      "files" => @files, "misses" => @misses}), perm: 0o600)
  end

  def install(path, release: false)
    @hits, @files, @refusal = 0, {}, nil
    @release = release
    # Trusted, local build output ONLY. This is not an untrusted artifact reader.
    image = Marshal.load(File.binread(path))
    @refusal = "ruby" unless image.fetch("ruby") == RUBY_DESCRIPTION
    @refusal ||= "load_path" unless image.fetch("load_path") == $LOAD_PATH
    @refusal ||= "gems" unless image.fetch("gems") == gem_versions
    @refusal ||= "source_digest" unless image.fetch("files").all? do |file, entry|
      File.file?(file) && Digest::SHA256.file(file).hexdigest == entry.fetch("sha256")
    end
    return if @refusal
    @files = image.fetch("files")
    API.singleton_class.prepend(Delivery)
  rescue StandardError => error
    @files = {}
    @refusal = error.class.name
  end

  module Delivery
    def load_iseq(path)
      BootImage.iseq(path) || (super if defined?(super))
    end
  end

  def iseq(path)
    entry = @files[path]
    return unless entry && entry.fetch("options") == API.compile_option
    # Deliberately retained: a boot-entry digest does not certify later loads.
    return unless Digest::SHA256.file(path).hexdigest == entry.fetch("sha256")
    sequence = API.load_from_binary(entry.fetch("binary"))
    @hits += 1
    @files.delete(path) if @release
    sequence
  rescue StandardError
    nil
  end

  def gem_versions
    Gem.loaded_specs.sort.to_h.transform_values { [_1.version.to_s, _1.full_gem_path] }
  end

  def restore_database(config)
    return unless config["lobsters_database"]
    # ruby-bench restores this fixture after boot. Forking/thread connection
    # replacement loses SQLite :memory:, so memory probes restore it there too.
    file = SQLite3::Database.new(config.fetch("lobsters_database"))
    backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
    backup.step(-1)
    backup.finish
    file.close
  end

  def request(path)
    require "rack/mock"
    response = Rails.application.call(Rack::MockRequest.env_for("https://localhost#{path}",
      "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_ACCEPT" => "text/html"))
    body = +""
    response[2].each { body << _1 }
    response[2].close if response[2].respond_to?(:close)
    {"status" => response[0], "headers" => response[1].to_h, "body_sha256" => Digest::SHA256.hexdigest(body),
      "bytes" => body.bytesize}
  end

  def census(app)
    # Observe already-loaded modules only; never resolve autoloads.
    constants, methods = [], {}
    modules = ObjectSpace.each_object(Module).filter_map do |mod|
      name = Module.instance_method(:name).bind_call(mod)
      [name, mod] if name && !name.start_with?("#<", "BootImage")
    end.to_h
    app_names = modules.filter_map do |name, mod|
      parent, _, key = name.rpartition("::")
      scope = parent.empty? ? Object : modules[parent]
      next unless scope && key.match?(/\A[[:upper:]][[:alnum:]_]*\z/)
      source = Module.instance_method(:const_source_location).bind_call(scope, key, false)
      name if source&.first&.start_with?(app + "/")
    end
    modules.each do |name, mod|
      Module.instance_method(:constants).bind_call(mod, false).each do |key|
        constants << "#{name}::#{key}" unless Module.instance_method(:autoload?).bind_call(mod, key, false)
      end
      app_owned = app_names.any? { name == _1 || name.start_with?(_1 + "::") }
      [mod, mod.singleton_class].each_with_index do |holder, side|
        entries = %i[public protected private].flat_map do |visibility|
          Module.instance_method("#{visibility}_instance_methods").bind_call(holder, false).filter_map do |key|
            method = Module.instance_method(:instance_method).bind_call(holder, key)
            location = method.source_location
            next unless app_owned || (location && location[0].start_with?(app + "/"))
            [key.to_s, visibility.to_s, location, method.parameters, method.arity]
          end
        end
        methods["#{name}#{side.zero? ? '#' : '.'}"] = entries.sort_by(&:first) unless entries.empty?
      end
    end
    chain = %i[load_iseq translate].to_h do |key|
      method = API.method(key) if API.respond_to?(key, true)
      entries = []
      while method
        entries << [method.owner.to_s, method.source_location, method.parameters]
        method = method.super_method
      end
      [key, entries]
    end
    {"loaded_features" => $LOADED_FEATURES.dup, "constants" => constants.sort,
      "app_methods" => methods.sort.to_h, "compiler_chain" => chain}
  end

  def fork_memory(path, treatment)
    GC.start
    before = memory
    GC.compact if treatment != "none"
    Process.warmup if treatment == "warmup"
    reader, writer = IO.pipe
    release_reader, release_writer = IO.pipe
    pid = fork do
      reader.close
      release_writer.close
      initial = memory
      10.times { request(path) }
      GC.start
      writer.write(JSON.generate({"initial" => initial, "warm" => memory}))
      writer.close
      release_reader.read(1)
      exit! 0
    end
    writer.close
    release_reader.close
    child = JSON.parse(reader.read)
    reader.close
    parent_after = memory
    release_writer.write("x")
    release_writer.close
    Process.wait(pid)
    {"treatment" => treatment, "parent_before" => before, "parent_after" => parent_after, "child" => child,
      "child_exit" => $?.exitstatus}
  end

  def worker(config, mode, output, image)
    app = config.fetch("app")
    Dir.chdir(app)
    require "bundler/setup"
    # Apps without Bootsnap use an external dependency-only Gemfile wrapper.
    # Plain/capture/image do not load a cache the app itself would not load.
    require "bootsnap/setup" unless ENV["DISABLE_BOOTSNAP"] == "1"
    if mode.start_with?("image_paths")
      require "bootsnap"
      Bootsnap.setup(cache_dir: ENV.fetch("BOOTSNAP_CACHE_DIR"), load_path_cache: true,
        compile_cache_iseq: false, compile_cache_yaml: true, compile_cache_json: true)
    end
    capture if mode == "capture"
    install(image, release: mode.end_with?("release")) if mode.start_with?("image")
    require File.join(ROOT, "gem/lib/lowrail/setup") if mode == "lowrail"
    load config["before_boot"] if config["before_boot"]
    require File.join(app, "config/environment")
    restore_database(config)
    boot_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    first = request(config.fetch("path"))
    first_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    10.times { request(config.fetch("path")) }
    GC.start
    warm_memory = memory
    result = {"mode" => mode, "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version,
      "yjit" => RubyVM::YJIT.enabled?, "boot_finished" => boot_finished, "first_finished" => first_finished,
      "first" => first, "warm_memory_kib" => warm_memory, "image_hits" => @hits || 0, "refusal" => @refusal}
    result["lowrail"] = Lowrail.jit_status.merge("units" => Lowrail.manifest&.units&.size) if mode == "lowrail"
    result["fork"] = fork_memory(config.fetch("path"), config.fetch("fork")) if config["fork"]
    result["census"] = census(app) if config["census"]
    if mode == "capture"
      save(image)
      result["image_files"] = @files.size
      result["image_bytes"] = File.size(image)
      result["capture_misses"] = @misses
    end
    File.write(output, JSON.pretty_generate(result))
  end

  def puma(config, output)
    FileUtils.mkdir_p(output)
    worker(config.merge("census" => false), "plain", File.join(output, "boot.json"), "unused")
    require "puma"
    require "puma/configuration"
    require "puma/launcher"
    treatment = config.fetch("treatment")
    app = lambda do |env|
      restore_database(config) unless @puma_fixture_restored
      @puma_fixture_restored = true
      response = Rails.application.call(env)
      # Memory-only instrumentation, not an exact-output test.
      response[1]["x-boot-probe-pid"] = Process.pid.to_s
      @puma_requests = (@puma_requests || 0) + 1
      GC.start if @puma_requests == 10
      response
    end
    options = Puma::Configuration.new do |server|
      server.app(app)
      server.workers(2)
      server.threads(1, 1)
      server.bind("unix://#{output}/puma.sock")
      server.pidfile(File.join(output, "puma.pid"))
      server.preload_app!
      server.before_fork do
        GC.start
        GC.compact if treatment != "none"
        Process.warmup if treatment == "warmup"
        File.write(File.join(output, "master.pid"), Process.pid)
      end
      server.on_worker_boot do |index|
        File.write(File.join(output, "worker-#{index}.pid"), Process.pid)
      end
    end
    Puma::Launcher.new(options).run
  end

  def puma_sample(output, path)
    require "socket"
    100.times do
      break if Dir[File.join(output, "worker-*.pid")].size == 2
      sleep 0.1
    end
    counts, statuses = Hash.new(0), Hash.new(0)
    200.times do
      socket = UNIXSocket.new(File.join(output, "puma.sock"))
      socket.write("GET #{path} HTTP/1.1\r\nHost: localhost\r\nX-Forwarded-Proto: https\r\nUser-Agent: Mozilla/5.0 Firefox/140.0\r\nAccept: text/html\r\nConnection: close\r\n\r\n")
      headers = socket.read.split("\r\n\r\n", 2).first
      socket.close
      statuses[headers.lines.first.split[1]] += 1
      pid = headers[/^x-boot-probe-pid: (\d+)/i, 1] or raise "worker header missing"
      counts[pid] += 1
      break if counts.size == 2 && counts.values.min >= 10
    end
    raise "both workers must warm" unless counts.size == 2 && counts.values.min >= 10
    master = File.read(File.join(output, "master.pid")).strip
    result = {"statuses" => statuses, "requests_by_worker" => counts,
      "master" => memory(master), "workers" => counts.keys.map { memory(_1) }}
    File.write(File.join(output, "memory.json"), JSON.pretty_generate(result))
    puts JSON.generate(result)
  end

  def run(config, output)
    output = File.expand_path(output)
    raise "new output directory required" if File.exist?(output)
    FileUtils.mkdir_p(output)
    config = JSON.parse(File.read(config))
    config_path = File.join(output, "config.json")
    File.write(config_path, JSON.generate(config), perm: 0o600)
    image = File.join(output, "image.marshal")
    modes = config.fetch("modes", %w[plain bootsnap lowrail capture image])
    plan = []
    plan << ["capture", 0] if modes.include?("capture")
    plan << ["bootsnap", "prime"] if modes.any? { %w[bootsnap lowrail].include?(_1) || _1.start_with?("image_paths") }
    config.fetch("samples", 3).times do |index|
      modes.reject { _1 == "capture" }.rotate(index).each { plan << [_1, index] }
    end
    records = plan.map do |mode, index|
        path = File.join(output, "#{mode}-#{index}.json")
        env = config.fetch("env", {}).merge("LOWRAIL" => mode == "lowrail" ? "1" : "0",
          "LOWRAIL_ROOT" => config.fetch("app"), "RAILS_ENV" => "production", "RACK_ENV" => "production",
          "DISABLE_BOOTSNAP" => %w[bootsnap lowrail].include?(mode) ? nil : "1",
          "BOOTSNAP_CACHE_DIR" => File.join(output, "bootsnap"))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        success = system(env, RbConfig.ruby, "-rbundler/setup", File.expand_path(__FILE__), "worker", config_path, mode, path, image,
          out: File.join(output, "#{mode}-#{index}.log"), err: [:child, :out])
        result = success ? JSON.parse(File.read(path)) : {"mode" => mode, "error" => "worker_exit", "exit" => $?.exitstatus}
        if success
          result["boot_ms"] = (result.delete("boot_finished") - started) * 1000
          result["first_ms"] = (result.delete("first_finished") - started) * 1000
          result["sample"] = index
          File.write(path, JSON.pretty_generate(result))
        end
        summary = result.reject { |key, _| %w[census fork first].include?(key) }
        summary["status"] = result.dig("first", "status")
        puts JSON.generate(summary)
        result
    end
    File.write(File.join(output, "results.json"), JSON.pretty_generate(records))
  end
end

if $PROGRAM_NAME == __FILE__
  mode, *arguments = ARGV
  case mode
  when "run" then BootImage.run(*arguments)
  when "worker" then BootImage.worker(JSON.parse(File.read(arguments.shift)), *arguments)
  when "puma" then BootImage.puma(JSON.parse(File.read(arguments.shift)), File.expand_path(arguments.fetch(0)))
  when "puma-sample" then BootImage.puma_sample(File.expand_path(arguments.fetch(0)), arguments.fetch(1))
  when "puma-start"
    config = JSON.parse(File.read(arguments.fetch(0)))
    env = config.fetch("env").merge("RAILS_ENV" => "production", "RACK_ENV" => "production",
      "LOWRAIL" => "0", "DISABLE_BOOTSNAP" => "1")
    exec(env, RbConfig.ruby, "-rbundler/setup", File.expand_path(__FILE__), "puma", *arguments.map { File.expand_path(_1) })
  else abort "usage: boot_image.rb run CONFIG_JSON NEW_OUTPUT_DIRECTORY"
  end
end
