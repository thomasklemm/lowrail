# frozen_string_literal: true

# Negative admission control, not a runtime certificate: retain a transitive
# scope mutation which must refuse before DirectSite can become an opt-in pass.
require_relative "ar_request_sites_check"

module ARSiteChecks
  class << self
    def change(bucket, locals)
      self.entered += 1
      unless undo
        original = ActiveRecord::Relation.instance_method(:_exec_scope)
        visibility = ActiveRecord::Relation.private_method_defined?(:_exec_scope) ? :private : :public
        ActiveRecord::Relation.send(:define_method, :_exec_scope) do |*args, &block|
          original.bind_call(self, *args, &block).where(id: -404)
        end
        ActiveRecord::Relation.send(visibility, :_exec_scope)
        self.undo = -> {
          ActiveRecord::Relation.send(:define_method, :_exec_scope, original)
          ActiveRecord::Relation.send(visibility, :_exec_scope)
        }
      end
      locals
    end

    def cases(config, state, arm)
      raise "actual YJIT required" unless RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
      ActionView::Template.prepend(MidRequest)
      source = BlogProduction::Entropy.source_pin(config.fetch("app"))
      # Match production: SQL shadow is an untimed diagnostic, not a guard.
      ARCallsite.shadow = false
      rows = [0, 1].to_h do |seed|
        self.current, self.entered, self.undo = "transitive_scope", 0, nil
        before = ARRequestSites.counts.dup
        response, evidence = NativeBench::Exploration.validation_request(route: "GET /buckets", seed: seed, request: -> { raise "unused" })
        raise "mutation did not run" unless entered.positive?
        raise "entropy control failed" unless evidence.fetch("passed")
        counts = ARRequestSites.counts.to_h { |key, value| [key, value - before.fetch(key, 0)] }
        [seed, {"response" => NativeBench.response_digest(response), "counts" => counts,
          "evidence" => evidence.except("trace", "clock_reads", "wall_clock_reads")}]
      ensure
        undo&.call
        self.undo = nil
      end
      raise "app source changed" unless BlogProduction::Entropy.source_pin(config.fetch("app")) == source
      {"arm" => arm, "yjit" => RubyVM::YJIT.enabled?, "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?),
        "source_sha256" => source, "cases" => rows}
    end
  end
end

if ARGV.first == "worker"
  _, config_path, state, arm, destination = ARGV
  File.write(destination, JSON.pretty_generate(ARSiteChecks.run(JSON.parse(File.read(config_path)), state, arm)))
  exit
end

config_path, output = ARGV
abort "usage: ar_request_sites_certificate.rb CONFIG NEW_OUTPUT" unless output
config = JSON.parse(File.read(config_path))
raise "new output required" if File.exist?(output)
FileUtils.mkdir_p(output)
results = NativeBench::ARMS.to_h do |arm|
  state = File.expand_path("#{output}/#{arm}-state")
  FileUtils.cp_r(config.fetch("seed"), state)
  FileUtils.rm_rf(File.join(config.fetch("app"), "tmp"))
  env = NativeBench.environment(config, state).merge("LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_STATS" => "",
    "BUNDLER_VERSION" => "4.0.20", "RUBYOPT" => "-rbundler/setup -I#{File.expand_path('../../gem/lib', __dir__)} -rlowrail/setup")
  destination = File.expand_path("#{output}/#{arm}.json")
  ok = system(env, RbConfig.ruby, "--yjit", File.expand_path(__FILE__), "worker", config_path, state, arm, destination,
    chdir: config.fetch("app"), out: "#{output}/#{arm}.log", err: [:child, :out])
  raise "worker failed #{arm}" unless ok
  [arm, JSON.parse(File.read(destination))]
end
checks = %w[0 1].to_h do |seed|
  a, on, b = %w[off_a on off_b].map { results.fetch(_1).fetch("cases").fetch(seed) }
  fields = %w[status body_sha256 headers_sha256]
  off_equal = fields.all? { a.fetch("response").fetch(_1) == b.fetch("response").fetch(_1) } &&
    a.fetch("evidence").fetch("sql_sha256") == b.fetch("evidence").fetch("sql_sha256")
  exact = fields.all? { on.fetch("response").fetch(_1) == a.fetch("response").fetch(_1) } &&
    on.fetch("evidence").fetch("sql_sha256") == a.fetch("evidence").fetch("sql_sha256")
  [seed, {"off_off_exact" => off_equal, "off_on_exact" => exact,
    "passed" => off_equal && exact && on.fetch("counts").fetch("bucket:hit", 0).zero?}]
end
sources = %w[ar_request_sites_certificate.rb ar_request_sites.rb ar_request_sites_check.rb ar_callsite.rb]
report = {"passed" => checks.values.all? { _1.fetch("passed") }, "checks" => checks, "workers" => results,
  "scope" => "transitive _exec_scope mutation after authentication; no app/config source patches; shadows off",
  "sources" => sources.to_h { [_1, Digest::SHA256.file(File.join(__dir__, _1)).hexdigest] }}
File.write("#{output}/result.json", JSON.pretty_generate(report) + "\n")
puts JSON.pretty_generate(report)
exit(report.fetch("passed") ? 0 : 2)
