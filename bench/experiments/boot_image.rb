# frozen_string_literal: true

# Research only: native boot/RSS screen, never loaded by the Lowrail gem.
# ruby boot_image.rb run CONFIG_JSON NEW_OUTPUT_DIRECTORY
# CONFIG: app, path, env; optional before_boot (external credentials fixture).
require "json"
require "digest"
require "fileutils"
require "rbconfig"

module BootImage
  ROOT = File.expand_path("../..", __dir__)
  API = RubyVM::InstructionSequence
  module_function

  def memory
    File.readlines("/proc/self/smaps_rollup").filter_map do |line|
      key, value = line.split
      [key.delete_suffix(":"), value.to_i] if %w[Rss: Pss: Private_Dirty: Shared_Dirty:].include?(key)
    end.to_h
  end

  def capture
    @files, @misses, @hits = {}, [], 0
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
    File.binwrite(path, Marshal.dump({"ruby" => RUBY_DESCRIPTION,
      "load_path" => @entry_load_path, "gems" => @entry_gems,
      "files" => @files, "misses" => @misses}), perm: 0o600)
  end

  def install(path)
    @hits, @files, @refusal = 0, {}, nil
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
    sequence
  rescue StandardError
    nil
  end

  def gem_versions
    Gem.loaded_specs.sort.to_h.transform_values { [_1.version.to_s, _1.full_gem_path] }
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
    ObjectSpace.each_object(Module) do |mod|
      name = Module.instance_method(:name).bind_call(mod)
      next unless name && !name.start_with?("#<", "BootImage")
      mod.constants(false).each do |key|
        constants << "#{name}::#{key}" unless mod.autoload?(key, false)
      end
      [mod, mod.singleton_class].each_with_index do |holder, side|
        entries = %i[public protected private].flat_map do |visibility|
          holder.public_send("#{visibility}_instance_methods", false).filter_map do |key|
            method = holder.instance_method(key)
            location = method.source_location
            next unless location && location[0].start_with?(app + "/")
            [key.to_s, visibility.to_s, location, method.parameters, method.arity]
          end
        end
        methods["#{name}#{side.zero? ? '#' : '.'}"] = entries.sort_by(&:first) unless entries.empty?
      end
    end
    {"loaded_features" => $LOADED_FEATURES.dup, "constants" => constants.sort, "app_methods" => methods.sort.to_h}
  end

  def fork_memory(path, treatment)
    ActiveRecord::Base.connection_handler.clear_all_connections! if defined?(ActiveRecord::Base)
    GC.start
    before = memory
    GC.compact if treatment != "none"
    Process.warmup if treatment == "warmup"
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      initial = memory
      10.times { request(path) }
      GC.start
      writer.write(JSON.generate({"initial" => initial, "warm" => memory}))
      writer.close
      exit! 0
    end
    writer.close
    child = JSON.parse(reader.read)
    reader.close
    Process.wait(pid)
    {"treatment" => treatment, "parent_before" => before, "parent_after" => memory, "child" => child,
      "child_exit" => $?.exitstatus}
  end

  def worker(config, mode, output, image)
    app = config.fetch("app")
    Dir.chdir(app)
    require "bundler/setup"
    # External Bootsnap injection also covers ruby-bench, which has no cache.
    # Paths are supplied by the launcher, not added to an application's bundle.
    $LOAD_PATH.unshift(*config.fetch("bootsnap_paths"))
    require "bootsnap/setup"
    @entry_load_path, @entry_gems = $LOAD_PATH.dup, gem_versions
    capture if mode == "capture"
    install(image) if mode == "image"
    require File.join(ROOT, "gem/lib/lowrail/setup") if mode == "lowrail"
    load config["before_boot"] if config["before_boot"]
    require File.join(app, "config/environment")
    # ruby-bench intentionally uses an in-memory DB; its benchmark restores
    # the shipped database after initialization, without changing app config.
    if config["lobsters_database"]
      file = SQLite3::Database.new(config.fetch("lobsters_database"))
      backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
      backup.step(-1)
      backup.finish
      file.close
    end
    boot_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    first = request(config.fetch("path"))
    first_finished = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    10.times { request(config.fetch("path")) }
    GC.start
    warm_memory = memory
    result = {"mode" => mode, "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version,
      "yjit" => RubyVM::YJIT.enabled?, "boot_finished" => boot_finished, "first_finished" => first_finished,
      "first" => first, "warm_memory_kib" => warm_memory, "image_hits" => @hits || 0, "refusal" => @refusal}
    result["census"] = census(app) if config["census"]
    result["fork"] = fork_memory(config.fetch("path"), config.fetch("fork")) if config["fork"]
    if mode == "capture"
      save(image)
      result["image_files"] = @files.size
      result["image_bytes"] = File.size(image)
      result["capture_misses"] = @misses
    end
    File.write(output, JSON.pretty_generate(result))
  end

  def run(config, output)
    raise "new output directory required" if File.exist?(output)
    FileUtils.mkdir_p(output)
    config = JSON.parse(File.read(config))
    config["bootsnap_paths"] = %w[bootsnap msgpack].flat_map { Gem::Specification.find_by_name(_1).full_require_paths }
    config_path = File.join(output, "config.json")
    File.write(config_path, JSON.generate(config), perm: 0o600)
    image = File.join(output, "image.marshal")
    modes = %w[plain bootsnap lowrail capture image]
    modes = config.fetch("modes", modes)
    records = modes.flat_map do |mode|
      Array.new(mode == "capture" ? 1 : config.fetch("samples", 3)) do |index|
        path = File.join(output, "#{mode}-#{index}.json")
        env = config.fetch("env", {}).merge("LOWRAIL" => mode == "lowrail" ? "1" : "0",
          "LOWRAIL_ROOT" => config.fetch("app"), "RAILS_ENV" => "production", "RACK_ENV" => "production",
          "DISABLE_BOOTSNAP" => %w[bootsnap lowrail].include?(mode) ? nil : "1",
          "BOOTSNAP_CACHE_DIR" => File.join(output, "bootsnap"))
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        success = system(env, RbConfig.ruby, __FILE__, "worker", config_path, mode, path, image,
          out: File.join(output, "#{mode}-#{index}.log"), err: [:child, :out])
        result = success ? JSON.parse(File.read(path)) : {"mode" => mode, "error" => "worker_exit", "exit" => $?.exitstatus}
        if success
          result["boot_ms"] = (result.delete("boot_finished") - started) * 1000
          result["first_ms"] = (result.delete("first_finished") - started) * 1000
          File.write(path, JSON.pretty_generate(result))
        end
        puts JSON.generate(result.reject { |key, _| %w[census fork].include?(key) })
        result
      end
    end
    File.write(File.join(output, "results.json"), JSON.pretty_generate(records))
  end
end

if $PROGRAM_NAME == __FILE__
  mode, *arguments = ARGV
  case mode
  when "run" then BootImage.run(*arguments)
  when "worker" then BootImage.worker(JSON.parse(File.read(arguments.shift)), *arguments)
  else abort "usage: boot_image.rb run CONFIG_JSON NEW_OUTPUT_DIRECTORY"
  end
end
