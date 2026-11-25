# frozen_string_literal: true

# bin/rails runner workload for lowrail-profile --workloads FILE: the file's
# requests (lowrail/workloads.rb, gem/lib/lowrail/workloads.rb) through the
# app's full middleware stack, 10 warmup passes and 20 counted ones (counts
# reset after warmup), under the request policy script/census app uses
# (Workloads::Replayer: a browser's headers, sign-in, CSRF tokens, the
# cookies earlier responses set). A response outside the request's expect:
# stops the run, so a broken path is not profiled as an error page.
#
# Experimental. Without --allow-writes only GETs are sent (see below). The
# requests are real: they write to the app's database and go through its
# own queue adapter and mail delivery, so jobs they enqueue run inline or reach
# real workers and mail is delivered as configured. What is not run here is the
# file's own mail and job workloads (the census runs them). The receipt says
# which, and which adapters the requests used.
require "rack/mock"
require "json"
require "uri"
require_relative "workloads"
require_relative "loaded_constant"

file, receipt = ARGV.fetch(0), ARGV[1]

# Without --allow-writes: no production database on another machine, and a
# file that declares only GETs, refused as each declaration is evaluated (before
# a setup block runs). Code the file runs itself is the app's, as in a test.
unless ENV["LOWRAIL_PROFILE_ALLOW_WRITES"] == "1"
  if Rails.env.production?
    configs = if (base = Lowrail.loaded_constant("ActiveRecord::Base"))
      base.configurations.configs_for(env_name: Rails.env).map(&:configuration_hash)
    else
      config = (Rails.application.config.database_configuration[Rails.env] rescue nil) || {}
      config.key?("adapter") || config.key?("url") ? [config] : config.values.grep(Hash)
    end
    hosts = configs.map { |c| c[:host] || c["host"] || ((url = c[:url] || c["url"]) && (URI(url).host rescue url)) }
    hosts << URI(ENV["DATABASE_URL"]).host if ENV["DATABASE_URL"]
    remote = hosts.compact.map(&:to_s).reject { _1.empty? || _1.start_with?("/") || %w[localhost 127.0.0.1 ::1 [::1]].include?(_1) }
    abort "lowrail-profile: RAILS_ENV=production with a database on #{remote.uniq.join(", ")}; --workloads sends real requests, " \
      "so it needs --allow-writes there" if remote.any?
  end
  read_only = Module.new do
    refuse = ->(what) { raise Lowrail::Workloads::WriteRefused, "#{what}; --workloads sends real requests, so it needs --allow-writes" }
    define_method(:setup) { refuse.("setup runs code before the requests") }
    (Lowrail::Workloads::VERBS - [:get]).each do |verb|
      define_method(verb) { |path, **| refuse.("#{verb.upcase} #{path} is a write") }
    end
    define_method(:get) do |path, **opts, &block|
      refuse.("GET #{path} has jobs: (its jobs run or are enqueued for real)") if opts[:jobs]
      super(path, **opts, &block)
    end
    define_method(:sign_in) do |path = nil, method: :post, cookie: nil, **opts|
      refuse.("sign_in #{method.to_s.upcase} #{path} is a write") unless cookie || method.to_sym == :get
      super(path, method: method, cookie: cookie, **opts)
    end
  end
  Lowrail::Workloads::Definition.prepend(read_only)
end
begin
  definition = Lowrail::Workloads.load(file)
rescue Lowrail::Workloads::WriteRefused => e
  abort "lowrail-profile: #{file}: #{e.message}"
end
abort "lowrail-profile: #{file} has no requests" if definition.requests.empty?
host = ENV.fetch("LOWRAIL_PROFILE_HOST", "localhost")
client = -> { Lowrail::Workloads::MockClient.new(Rails.application, host) }
replay = Lowrail::Workloads::Replayer.new(definition, client.(), client.())

# The adapters in use, or before their framework is loaded (it is not loaded
# here for this) the configured ones; Rails' defaults are async and smtp.
loaded = ->(owner, name) { owner.const_defined?(name, false) && !owner.autoload?(name, false) }
config = Rails.application.config
side_effects = {
  "queue_adapter" => if defined?(ActiveJob) && loaded.(ActiveJob, :Base) then ActiveJob::Base.queue_adapter_name
    elsif config.respond_to?(:active_job) then config.active_job.queue_adapter || "async (default)"
    end,
  "delivery_method" => if defined?(ActionMailer) && loaded.(ActionMailer, :Base) then ActionMailer::Base.delivery_method
    elsif config.respond_to?(:action_mailer) then config.action_mailer.delivery_method || "smtp (default)"
    end
}.compact.transform_values(&:to_s)
warn "lowrail-profile: the requests are real#{" (#{side_effects.map { "#{_1} #{_2}" }.join(", ")})" unless side_effects.empty?}; " \
  "run them against a disposable database, queue and mail service"
measured = {}
# Every counted request as sent, in order: compare checks that two captures
# measured the same sequence, not only the same declarations.
require "digest"
sequence = Digest::SHA256.new
sequence << JSON.generate([host, Lowrail::Workloads::BROWSER])
counted = 0
# Written before the passes (a diagnostic if the run stops) and after them;
# only the final one is complete, and only it writes the run's measured.json.
write = lambda do |complete|
  measured_run = { "requests" => counted, "sha256" => sequence.hexdigest[0, 16], "complete" => complete }
  uncertified = definition.manifest["requests"].select { _1["headers_uncertified"] }.map { _1["name"] }
  measured_run["uncertified"] = uncertified unless uncertified.empty?
  if complete && (run = ENV["LOWRAIL_PROFILE"]) && File.directory?(run)
    File.write(File.join(run, "measured.json"), JSON.generate(measured_run) + "\n")
  end
  next unless receipt
  File.write(receipt, JSON.pretty_generate("manifest" => definition.manifest, "replayed" => definition.requests.map(&:name),
    "side_effects" => side_effects.merge("requests_enqueuing_jobs" => definition.requests.select(&:jobs).map(&:name),
      "note" => "requests enqueue through the app's own queue adapter and deliver through its mail delivery: an inline " \
        "adapter runs their jobs in the request, any other enqueues real work"),
    "not_replayed" => { "mails" => definition.mails.map(&:name), "jobs" => definition.jobs.map(&:name) },
    # A block's or alternate's requests as measured (the manifest has only the declaration).
    "measured_variants" => measured,
    "measured" => measured_run) + "\n")
end
write.(false)

current = nil
pass = lambda do |record|
  definition.requests.each do |r|
    current = r
    spec = replay.perform(r)
    next unless record
    counted += 1
    sequence << JSON.generate([r.name, r.verb, r.signed_in, spec.variant, spec.to_h["headers_sha256"]])
    next unless r.block || r.alternate
    list = measured[r.name] ||= []
    list << spec.variant unless list.size >= 20 || list.include?(spec.variant)
  end
end
begin
  replay.sign_in
  10.times { pass.(false) }
  Lowrail::Profile.reset if defined?(Lowrail::Profile::Window)
  20.times { pass.(true) }
rescue RuntimeError => e
  abort "lowrail-profile: #{current ? "#{current.name}: " : "sign_in: "}#{e.message}"
end
write.(true)
