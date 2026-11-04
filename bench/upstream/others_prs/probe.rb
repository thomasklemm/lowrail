# frozen_string_literal: true

# Query-result differential for a census app (docs/upstream/others-prs-census.md), run by probe_run.rb in the
# app's copy with a variant bundle. After boot, runs every census workload once and records the digest of
# each response body (tokens, nonces and UUIDs masked). A second pass runs every workload again and records,
# per workload, the digest of every record loaded through _load_from_sql (class and attributes). The passes
# are separate because reading every attribute could change what the request later does. Compare two runs of
# the base (A/A) to find workloads that vary anyway, then the base with the PR head.
#   bundle exec ruby probe.rb APP OUT.json
require_relative "../census/harness"

module OthersPrsProbe
  MASKS = [
    [/(name="authenticity_token"[^>]*value=")[^"]+/, '\1T'],
    [/(<meta name="csrf-token" content=")[^"]+/, '\1T'],
    [/(nonce=")[^"]+/, '\1N'],
    [/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/, "UUID"],
    [/\b\h{32,}\b/, "HEX"],
  ].freeze

  @log = nil
  class << self
    attr_accessor :log, :prepared_at, :records_pass

    # Rows created or touched by workloads (after the copy was seeded) differ between runs by their ids,
    # timestamps and sequence numbers; mask those so the A/A pair agrees on the rest.
    def normalize(attributes)
      fresh = (t = attributes["created_at"]).respond_to?(:to_time) && t.to_time > prepared_at
      attributes.map do |k, v|
        v = "RECENT" if v.respond_to?(:to_time) && !v.is_a?(String) && v.to_time > prepared_at
        v = "NEW" if fresh && k == "id"
        v = v.gsub(/\d+/, "N") if fresh && v.is_a?(String)
        v = "TOKEN" if v.is_a?(String) && v.match?(/\A[\w-]{16,}\z/) && v.match?(/\d|N/) && v.match?(/[a-z]/i)
        [k, v]
      end
    end
  end

  module ClientCapture
    def request(verb, path, **kw)
      response = super
      if (log = OthersPrsProbe.log) && !OthersPrsProbe.records_pass
        body = response.body.to_s.dup.force_encoding(Encoding::BINARY)
        MASKS.each { |re, sub| body.gsub!(re.source.b.then { Regexp.new(_1) }, sub) }
        log << [verb, path.gsub(/\d+/, "N"), response.status, Digest::SHA256.hexdigest(body)[0, 16]]
      end
      response
    end
  end

  module LoadCapture
    def _load_from_sql(*args, &block)
      records = super
      if (log = OthersPrsProbe.log)
        records.each { |r| log << [r.class.name, OthersPrsProbe.normalize(r.attributes).inspect] }
      end
      records
    end
  end
end

app, output = ARGV
RailsCensus.boot(app)
OthersPrsProbe.prepared_at = File.mtime("tmp/census-fixtures.json")
RailsMainCensus4::Client.prepend(OthersPrsProbe::ClientCapture)
ops = RailsCensus.workloads(app)
results = {}
ops.each do |op|
  OthersPrsProbe.log = []
  error = begin
    op.call.call
    nil
  rescue => e
    "#{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
  ensure
    RailsCensus.reset_side_effects
  end
  results[op.name] = { "bodies" => OthersPrsProbe.log, "error" => error }
end
ActiveRecord::Base.singleton_class.prepend(OthersPrsProbe::LoadCapture)
OthersPrsProbe.records_pass = true
ops.each do |op|
  OthersPrsProbe.log = []
  error = begin
    op.call.call
    nil
  rescue => e
    "#{e.class}: #{e.message.lines.first.to_s.strip[0, 200]}"
  ensure
    RailsCensus.reset_side_effects
  end
  log = OthersPrsProbe.log
  results[op.name]["records"] = { "count" => log.size, "digest" => Digest::SHA256.hexdigest(log.inspect)[0, 16],
    "classes" => log.map(&:first).tally, "error" => error }
  results[op.name]["record_rows"] = log
end
OthersPrsProbe.log = nil
File.write(output, JSON.pretty_generate(app: app, rails: RailsCensus.rails_sha, ruby: RUBY_DESCRIPTION, workloads: results) + "\n")
puts "#{app}: #{results.size} workloads, #{results.sum { _2["bodies"].size }} responses, " \
  "#{results.sum { _2["records"]["count"] }} records"
