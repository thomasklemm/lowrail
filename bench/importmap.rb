# frozen_string_literal: true

# From a prepared Campfire checkout, with production fixtures (see M0):
# RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ruby --yjit ../../bench/importmap.rb trace
# ... ruby --yjit ../../bench/importmap.rb micro [candidate concern.rb]
# ... ruby --yjit ../../bench/importmap.rb check candidate_concern.rb
# ... ruby --yjit ../../bench/importmap.rb boundary candidate_concern.rb
# No raw HTML, cookies or session headers are exported.
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "rack/mock"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil

module ImportmapBench
  module_function

  def candidate(path)
    # Load the actual fork's source, not a separately handwritten optimization.
    # Its included block is never installed: only the location method changes.
    source = File.read(path).sub("module InlineScriptHashes", "module ImportmapBenchCandidate")
    raise "not an InlineScriptHashes concern" unless source.include?("module ImportmapBenchCandidate")
    Object.class_eval(source, path)
    InlineScriptHashes.send(:define_method, :script_locations, ImportmapBenchCandidate.instance_method(:script_locations))
    InlineScriptHashes.send(:private, :script_locations)
  end

  def request(client, path, headers)
    response = client.get(path, headers)
    raise "expected HTTP 200, got #{response.status}" unless response.status == 200
    response
  end

  def measure(n, &block)
    400.times { block.call }
    Array.new(7) do
      GC.start
      allocations = GC.stat(:total_allocated_objects)
      start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      n.times { block.call }
      { cpu_us: (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start) * 1e6 / n,
        allocations: (GC.stat(:total_allocated_objects) - allocations).fdiv(n) }
    end
  end

  def run(mode, fork = nil)
    paths = JSON.parse(File.read("tmp/m0/paths.json")).slice("room", "messages", "sidebar", "search")
    headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(File.read("tmp/m0/headers.json")))
    client = Rack::MockRequest.new(Rails.application)
    paths.each_value { |path| 50.times { request(client, path, headers) } }
    controller = ApplicationController.new
    controller.set_request!(ActionDispatch::Request.new(Rack::MockRequest.env_for("https://localhost#{paths.fetch("room")}")))
    json = Rails.application.importmap.to_json(resolver: controller.helpers)
    urls = JSON.parse(json).fetch("imports").values
    result = { ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, regexp_timeout: Regexp.timeout,
      importmap_bytes: json.bytesize, imports: urls.size, distinct_urls: urls.uniq.size,
      locations: controller.send(:script_locations, json), nonce_generator: Rails.application.config.content_security_policy_nonce_generator.inspect }

    case mode
    when "trace"
      interesting = %i[script_locations script_hashes to_json build_import_map resolve asset_integrity join parse base64digest build]
      result[:requests] = paths.to_h do |name, path|
        counts = Hash.new(0)
        inside_locations = false
        trace = TracePoint.new(:call, :c_call, :return) do |event|
          if event.method_id == :script_locations && event.defined_class == InlineScriptHashes
            inside_locations = event.event == :call
          end
          next if event.event == :return
          next unless interesting.include?(event.method_id)
          owner = event.defined_class.to_s
          next unless owner.match?(/InlineScriptHashes|Importmap::Map|Propshaft|URI|JSON|Digest|ContentSecurityPolicy/)
          counts["#{owner}##{event.method_id}"] += 1
          counts["inside script_locations: #{owner}##{event.method_id}"] += 1 if inside_locations
        end
        trace.enable { 20.times { request(client, path, headers) } }
        [name, { requests: 20, calls_per_request: counts.transform_values { _1 / 20.0 } }]
      end
    when "micro"
      policy = Rails.application.config.content_security_policy.clone
      policy.directives["script-src"] = controller.send(:script_locations, json) |
        controller.send(:script_hashes, json, InlineScriptHashes::ENTRY_POINT_SCRIPT)
      policy.worker_src "localhost/service-worker.js"
      work = {
        request: -> { request(client, paths.fetch("room"), headers) },
        importmap_json: -> { Rails.application.importmap.to_json(resolver: controller.helpers) },
        json_parse: -> { JSON.parse(json) },
        uri_joins: -> { urls.each { URI.join("https://localhost", _1) } },
        script_locations: -> { controller.send(:script_locations, json) },
        script_hashes: -> { controller.send(:script_hashes, json, InlineScriptHashes::ENTRY_POINT_SCRIPT) },
        csp_build: -> { policy.build(controller) }
      }
      result[:baseline] = work.transform_values { measure(1000, &_1) }
      if fork
        candidate(fork)
        result[:candidate] = work.transform_values { measure(1000, &_1) }
      end
    when "check"
      raise "candidate concern required" unless fork
      # Compare actual body/header bytes, not digests or masked HTML. Keep the
      # same warmed response cache so randomized CSRF masks are held constant.
      before = paths.transform_values { request(client, _1, headers) }
      candidate(fork)
      result[:checks] = paths.to_h do |name, path|
        previous = before.fetch(name)
        3.times do
          current = request(client, path, headers)
          raise "#{name}: HTML differs" unless previous.body.b == current.body.b
          %w[content-security-policy content-security-policy-report-only].each do |header|
            raise "#{name}: #{header} differs" unless previous[header] == current[header]
          end
          expected = { "room" => "Champagne", "messages" => "Champagne", "sidebar" => "All Talk", "search" => "Pain is easy to write" }.fetch(name)
          raise "#{name}: wrong page" unless current.body.include?(expected)
        end
        [name, { bytes: previous.body.bytesize, comparisons: 3, html_identical: true, csp_identical: true }]
      end
    when "boundary"
      raise "candidate concern required" unless fork
      original = InlineScriptHashes.instance_method(:script_locations)
      probe = JSON.generate(imports: { "probe" => "/assets/" + "a" * 20_000 + ".js" })
      expected = controller.send(:script_locations, probe)
      candidate(fork)
      raise "candidate changed the location" unless controller.send(:script_locations, probe) == expected
      previous_timeout = Regexp.timeout
      begin
        Regexp.timeout = 1e-9 # Positive control only; never used as a guard.
        raise "cache did not reuse the location" unless controller.send(:script_locations, probe) == expected
        error = begin
          original.bind_call(controller, probe)
          nil
        rescue Regexp::TimeoutError => exception
          exception.class.name
        end
        raise "positive timeout control did not fire" unless error == "Regexp::TimeoutError"
        result[:boundary] = { original_error: error, app_cache_reused: true }
      ensure
        Regexp.timeout = previous_timeout
      end
    else
      raise "usage: importmap.rb trace|micro|check|boundary [candidate concern]"
    end
    puts JSON.pretty_generate(result)
  end
end

ImportmapBench.run(*ARGV) if $PROGRAM_NAME == __FILE__
