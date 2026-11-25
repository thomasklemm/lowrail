# frozen_string_literal: true

# One boot check in the app's bundle (script/rails-main-boot):
#   bundle exec ruby probe.rb boot OUT.json   production boot with eager loading held off, then eager loading as
#                                             Rails' finisher does it (Rails.application.eager_load! included)
# Writes {"boot": {...}, "eager_load": {...}, "rails": {...}}; each phase is {"ok": true} or the error.
require "json"

out = ARGV.fetch(1)
app = Dir.pwd
result = {}

describe = lambda do |error|
  frames = error.backtrace || []
  gems = Gem.path.map { File.join(_1, "") } + [File.join(Gem.dir, "bundler/gems/")]
  in_app = ->(f) { f.start_with?(app + "/") && !f.start_with?(File.join(app, "vendor/")) }
  rails = ->(f) { f.match?(%r{/(?:rails-\h{12}|(?:actioncable|actionmailbox|actionmailer|actionpack|actiontext|actionview|activejob|activemodel|activerecord|activestorage|activesupport|railties)-\d[^/]*)/}) }
  {
    "ok" => false, "class" => error.class.name, "message" => error.message.to_s[0, 2000],
    "first_app_frame" => frames.find(&in_app), "first_rails_frame" => frames.find(&rails),
    "first_gem_frame" => frames.find { |f| !in_app.(f) && !rails.(f) && gems.any? { f.start_with?(_1) } },
    "backtrace" => frames.first(25),
    "cause" => error.cause && { "class" => error.cause.class.name, "message" => error.cause.message.to_s[0, 500] }
  }
end

phase = "boot"
begin
  require File.join(app, "config/application")
  config = Rails.application.config
  # production.rb sets eager_load = true; keep it off so a failure in the eager load shows as its own phase.
  config.eager_load = false
  config.define_singleton_method(:eager_load=) { |_| }
  require File.join(app, "config/environment")
  result["boot"] = { "ok" => true }
  phase = "eager_load"
  ActiveSupport.run_load_hooks(:before_eager_load, Rails.application)
  Zeitwerk::Loader.eager_load_all
  Rails.eager_load!
  config.eager_load_namespaces.each(&:eager_load!)
  Rails.application.eager_load!
  result["eager_load"] = { "ok" => true }
rescue Exception => e # rubocop:disable Lint/RescueException
  result[phase] = describe.(e)
ensure
  if defined?(Rails) && Rails.respond_to?(:version)
    railties = Gem.loaded_specs["railties"]
    result["rails"] = { "version" => Rails.version, "railties" => railties&.full_gem_path }
  end
  File.write(out, JSON.pretty_generate(result) + "\n")
end
exit!(0)
