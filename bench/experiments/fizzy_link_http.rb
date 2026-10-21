# frozen_string_literal: true

# Untimed real-HTTP reachability only. b_call diagnostics never inspect a
# TracePoint Binding and are NOT block/binding/admission certificates.
require_relative "fizzy_link_fixture"
require "digest"

module FizzyLinkHTTP
  module_function

  def serve(app, state, port)
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    FizzyLinkFixture.boot(app)
    require "puma"
    report = JSON.parse(File.read(File.expand_path("../../docs/helper-census.json", __dir__)))
    sites = report.fetch("apps").fetch("fizzy").fetch("sites").select do |site|
      site["helper"] == "link_to" && site["receiver"] == "bare" && site["block"] &&
        site["file"].start_with?("app/views/") && site["file"].end_with?(".html.erb") &&
        site.dig("options", "keys") == ["class"] && site.dig("options", "values") == "literal"
    end
    positions = sites.to_h { |site| [[File.join(app, site.fetch("file")), site.fetch("line")], "#{site.fetch("file")}:#{site.fetch("line")}"] }
    raise "ambiguous diagnostic position" unless positions.size == 23
    trace = TracePoint.new(:b_call, :call) do |event|
      current = Thread.current[:fizzy_link_http]
      next unless current
      if event.event == :b_call && (site = positions[[event.path, event.lineno]])
        current[:sites][site] += 1
      elsif event.method_id == :link_to && event.defined_class.equal?(ActionView::Helpers::UrlHelper)
        current[:all_link_to] += 1
      end
    end
    trace.enable
    ActiveSupport::Notifications.subscribe(/(?:render_(?:partial|collection|template)\.action_view|read_fragment\.action_controller|cache_read\.active_support)/) do |name, *, payload|
      current = Thread.current[:fizzy_link_http]
      next unless current
      current[:cache_and_render] << {name: name, identifier: payload[:identifier], key: payload[:key],
        hit: payload[:hit], cache_hits: payload[:cache_hits], count: payload[:count]}
    end
    wrapped = lambda do |env|
      current = {request_id: nil, route: env.fetch("PATH_INFO") + (env["QUERY_STRING"].empty? ? "" : "?#{env["QUERY_STRING"]}"),
        all_link_to: 0, sites: Hash.new(0), cache_and_render: []}
      Thread.current[:fizzy_link_http] = current
      begin
        status, headers, body = Rails.application.call(env)
        current.merge!(status: status, request_id: headers["x-request-id"])
        [status, headers, body]
      ensure
        Thread.current[:fizzy_link_http] = nil
        File.open(File.join(state, "http-observations.jsonl"), "a", 0o600) { _1.puts(JSON.generate(current)) }
      end
    end
    puts JSON.generate(ready: true, rails: Rails.version, ruby: RUBY_VERSION, yjit: RubyVM::YJIT.enabled?,
      source: app, harness_sha256: Digest::SHA256.file(__FILE__).hexdigest, catalog_sites: sites.size)
    server = Puma::Server.new(wrapped, nil, min_threads: 0, max_threads: 1)
    server.add_tcp_listener("127.0.0.1", port)
    server.run.join
  end

  def probe(state, port)
    require "net/http"
    require "cgi"
    cookies = {}
    http = Net::HTTP.new("127.0.0.1", port, nil)
    request = lambda do |method, path, params = nil|
      req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(path)
      req["Host"] = "fizzy.example.invalid"
      req["X-Forwarded-Proto"] = "https"
      req["Origin"] = "https://fizzy.example.invalid"
      req["User-Agent"] = "Mozilla/5.0 Firefox/140.0"
      req["Cookie"] = cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
      req.set_form_data(params) if params
      response = http.request(req)
      response.get_fields("set-cookie")&.each do |cookie|
        name, value = cookie.split(";", 2).first.split("=", 2)
        cookies[name] = value
      end
      response
    end
    login = request.call(:get, "/session/new")
    raise "sign-in page HTTP #{login.code}" unless login.code == "200"
    token = login.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "natural CSRF token absent"
    credentials = JSON.parse(File.read(File.join(state, "login.json")))
    signed_in = request.call(:post, "/session", credentials.merge("authenticity_token" => CGI.unescapeHTML(token)))
    raise "natural sign-in failed HTTP #{signed_in.code}" unless signed_in.code == "302" && cookies.key?("session_token")
    results = []
    vector = JSON.parse(File.read(File.join(state, "vector.json")))
    %w[cold warm warm_repeat].each do |phase|
      vector.each do |path|
        response = request.call(:get, path)
        row = {phase: phase, route: path, status: response.code.to_i, request_id: response["x-request-id"], body_bytes: response.body.bytesize}
        results << row
        File.write(File.join(state, "probe-results.json"), JSON.pretty_generate(results), perm: 0o600)
        raise "production HTTP failed #{path}: #{response.code}" unless response.code == "200"
      end
    end
    puts JSON.pretty_generate(results)
  end

  def report(app, state)
    results = JSON.parse(File.read(File.join(state, "probe-results.json")))
    observations = File.readlines(File.join(state, "http-observations.jsonl")).map { JSON.parse(_1) }
    requests = results.map do |result|
      matches = observations.select { _1.fetch("request_id") == result.fetch("request_id") }
      raise "missing/ambiguous HTTP observation" unless matches.size == 1
      observation = matches.fetch(0)
      raise "HTTP observation mismatch" unless observation.fetch("route") == result.fetch("route") && observation.fetch("status") == 200
      result.slice("phase", "route", "status").merge("sites" => observation.fetch("sites"),
        "block_entries" => observation.fetch("sites").values.sum,
        "all_link_to" => observation.fetch("all_link_to"),
        "cache_evidence" => observation.fetch("cache_and_render").filter_map do |event|
          next unless event["hit"] || event["cache_hits"].to_i.positive?
          event.slice("name", "hit", "cache_hits", "count").merge(
            "identifier" => event["identifier"]&.delete_prefix(app + "/"))
        end)
    end
    census = JSON.parse(File.read(File.expand_path("../../docs/helper-census.json", __dir__))).fetch("apps").fetch("fizzy")
    identities = requests.flat_map { _1.fetch("sites").keys }.uniq.sort
    raise "expected 23 cold identities / 18 successful GETs" unless identities.size == 23 && requests.size == 18 &&
      requests.all? { _1.fetch("status") == 200 }
    phases = %w[cold warm warm_repeat]
    ledger = identities.to_h do |site|
      [site, phases.to_h { |phase| [phase, requests.select { _1.fetch("phase") == phase }.sum { _1.fetch("sites").fetch(site, 0) }] }]
    end
    {kind: "untimed_real_production_http_reachability_not_admission_or_price", ruby: "4.0.7", rails: "8.1.4", jit: "interpreter",
      revision: census.fetch("revision"), lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
      reporter_sources: [__FILE__, File.join(__dir__, "fizzy_link_fixture.rb")].to_h { [File.basename(_1), Digest::SHA256.file(_1).hexdigest] },
      authentication: "natural GET /session/new, CSRF/password POST /session; per-process cookie jar",
      fixture: "external disposable upstream SQL fixture data; no test runtime in HTTP worker",
      cache_policy: "stock production caches retained across all 18 GETs; no cache clear or disable",
      limitations: ["path/line b_call diagnostic, not block-ISeq or owner provenance", "block entries, not completed or fast-path hits",
        "no equivalence/SQL/effect/load claim from this reachability projection", "probe harness was not yet frozen in a detached worktree"],
      requests: requests, sites: ledger,
      totals: phases.to_h { |phase| [phase, {block_entries: ledger.values.sum { _1.fetch(phase) }, identities: ledger.values.count { _1.fetch(phase).positive? }}] }}
  end
end

if $PROGRAM_NAME == __FILE__
  mode, app, state, port = ARGV
  abort "usage: fizzy_link_http.rb serve|probe APP STATE PORT | report APP STATE" unless
    (%w[serve probe].include?(mode) && port) || (mode == "report" && state && !port)
  app, state = [app, state].map { File.realpath(_1) }
  case mode
  when "serve" then FizzyLinkHTTP.serve(app, state, Integer(port))
  when "probe" then FizzyLinkHTTP.probe(state, Integer(port))
  when "report" then puts JSON.pretty_generate(FizzyLinkHTTP.report(app, state))
  end
end
