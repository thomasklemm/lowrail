# frozen_string_literal: true

# bin/rails runner workload for lowrail-profile --workloads FILE: the file's
# requests (lowrail/workloads.rb, gem/lib/lowrail/workloads.rb) through the
# app's full middleware stack, 10 warmup passes and 20 counted ones (counts
# reset after warmup), under the request policy script/census app uses
# (Workloads::Replayer: a browser's headers, sign-in, CSRF tokens, the
# cookies earlier responses set). A response outside the request's expect:
# stops the run, so a broken path is not profiled as an error page.
#
# The requests are real: they write to the app's database and go through its
# own queue adapter and mail delivery, so jobs they enqueue run inline or reach
# real workers and mail is delivered as configured. What is not run here is the
# file's own mail and job workloads (the census runs them). The receipt says
# which, and which adapters the requests used.
require "rack/mock"
require "json"
require_relative "workloads"

file, receipt = ARGV.fetch(0), ARGV[1]
definition = Lowrail::Workloads.load(file)
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
