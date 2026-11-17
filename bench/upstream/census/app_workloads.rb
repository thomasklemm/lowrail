# frozen_string_literal: true

# Workloads for an app outside the registered corpus (script/census app). The
# harness loads this only with CENSUS_APP=1. A workloads file is YAML rendered
# with ERB inside the booted app (so <% %> can look records up), or a Ruby file
# defining CensusAppWorkloads.custom(c) that returns c::Op values. Without one,
# GET pages are discovered from the routes once and cached in the copy.
# Format: docs/upstream/census.md#workloads-file.
require "erb"
require "yaml"

module CensusAppWorkloads
  DISCOVERED = "tmp/census-discovered.json"
  WRITE_EXPECT = [200, 201, 202, 204, 302, 303].freeze
  JSON_HEADERS = { "HTTP_ACCEPT" => "application/json", "CONTENT_TYPE" => "application/json" }.freeze

  module_function

  def spec(path)
    return { "discover" => true } unless path
    raise "workloads file not found: #{path}" unless File.exist?(path)
    return nil if path.end_with?(".rb")
    data = YAML.safe_load(ERB.new(File.read(path), trim_mode: "-").result(binding_for_file), aliases: true) || {}
    raise "#{path}: expected a mapping at the top level" unless data.is_a?(Hash)
    unknown = data.keys - %w[sign_in csrf_from requests jobs skip_jobs setup mailers discover]
    raise "#{path}: unknown keys #{unknown.join(", ")}" if unknown.any?
    data
  end

  def binding_for_file = Object.new.instance_eval { binding }

  def load(c, path)
    if path&.end_with?(".rb")
      Kernel.load(File.expand_path(path))
      return custom(c)
    end
    data = spec(path)
    client = c::Client.new
    sign_in(client, data["sign_in"]) if data["sign_in"]
    anonymous = c::Client.new
    requests = Array(data["requests"]).map { request_spec(_1) }
    requests.concat(discovered(c, client, data["discover"])) if data["discover"]
    raise "no workloads: the file lists none and discovery found no page" if requests.empty? && !data["jobs"] && !data["mailers"]
    token_page = data["csrf_from"] || requests.find { _1[:method] == "get" && _1[:kind] == :html }&.dig(:path)
    tokens = {}
    token = ->(cl) { tokens.fetch(cl) { tokens[cl] = token_page && cl.csrf(token_page, required: false) } }
    ops = []
    jobs = []
    requests.each do |r|
      cl = r[:signed_in] == false ? anonymous : client
      turn = [0]
      call = lambda do
        n = turn[0] += 1
        spec = r[:alternate] ? r[:alternate][n % r[:alternate].size - 1] : r
        perform(cl, spec[:counter] ? number(spec, n) : spec, r[:method] == "get" ? nil : token.(cl))
      end
      ops << c::Op.new(r[:name], r[:kind], call)
      jobs.concat(c.jobs_from(&call)) if r[:jobs]
    end
    # setup runs once, after the requests ran (and enqueued their jobs); its
    # local variables are visible to the mailers' code, compiled once each.
    scope = binding_for_file
    scope.eval(data["setup"], "setup") if data["setup"]
    Array(data["mailers"]).each do |m|
      code = m.fetch("ruby")
      build = scope.eval("-> { #{code} }", "mailer")
      ops << c.mail_op(m["name"] || "deliver #{code[/\A[\w:]+(?:\.\w+)?/]}", &build)
    end
    skip = Array(data["skip_jobs"])
    jobs.uniq { _1["job_class"] }.reject { skip.include?(_1["job_class"]) }.each { ops << c.job_op("perform #{_1["job_class"]}", _1) }
    Array(data["jobs"]).each do |j|
      klass = j.fetch("class")
      payload = Object.const_get(klass).new(*Array(j["args"])).serialize
      ops << c.job_op(j["name"] || "perform #{klass}", payload)
    end
    names = ops.map(&:name)
    raise "duplicate workload names: #{names.select { names.count(_1) > 1 }.uniq.join(", ")}" if names.uniq.size != names.size
    ops
  end

  # "GET /path" or a mapping with method, path, params, json, headers, ...
  # alternate: a list of overrides (path, params, json) used in turn, so a
  # write can flip between two states and runs do not accumulate.
  def request_spec(entry)
    entry = { "method" => entry.split(" ", 2)[0], "path" => entry.split(" ", 2)[1] } if entry.is_a?(String)
    if (alternate = entry["alternate"])
      raise "request #{entry["name"] || entry["path"]}: alternate must be a list of mappings" unless alternate.is_a?(Array) && alternate.all?(Hash)
      base = entry.except("alternate")
      spec = request_spec(base.merge(alternate.first))
      return spec.merge(name: entry["name"] || spec[:name], alternate: alternate.map { request_spec(base.merge(_1)).merge(name: spec[:name]) })
    end
    method = entry.fetch("method", "get").downcase
    path = entry.fetch("path")
    raise "request #{entry.inspect}: method must be get, post, patch, put or delete" unless %w[get post patch put delete].include?(method)
    raise "request #{entry.inspect}: path must start with /" unless path.is_a?(String) && path.start_with?("/")
    json = entry.key?("json") || entry["format"] == "json" || path.match?(/\.json(\?|\z)/)
    headers = entry.fetch("headers", {}).to_h { |k, v| [rack_header(k), v.to_s] }
    headers = JSON_HEADERS.merge(headers) if json
    headers["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest" if entry["xhr"]
    kind = entry["kind"]&.to_sym || (json ? :json : method == "get" ? :html : :form)
    { name: entry["name"] || "#{method.upcase} #{path}", method: method, path: path, params: entry["params"] || {},
      body: (JSON.generate(entry["json"]) if entry.key?("json")), headers: headers,
      expect: Array(entry["expect"] || (method == "get" ? 200 : WRITE_EXPECT)), kind: kind,
      csrf: entry.fetch("csrf", json || entry["xhr"] ? "header" : "param").to_s, jobs: entry["jobs"], signed_in: entry["signed_in"],
      counter: entry.to_s.include?("%{n}") }
  end

  # %{n} in a path, param or JSON value is the operation's number, for writes
  # that must differ each time (a comment's text).
  def number(spec, n)
    fill = ->(v) { v.is_a?(String) ? v.gsub("%{n}", n.to_s) : v.is_a?(Hash) ? v.transform_values(&fill) : v.is_a?(Array) ? v.map(&fill) : v }
    spec.merge(path: fill.(spec[:path]), params: fill.(spec[:params]), body: spec[:body] && fill.(spec[:body]))
  end

  def rack_header(name)
    key = name.to_s.upcase.tr("-", "_")
    %w[CONTENT_TYPE CONTENT_LENGTH].include?(key) || key.start_with?("HTTP_") ? key : "HTTP_#{key}"
  end

  def perform(client, r, token)
    headers = r[:headers]
    params = r[:params]
    if token && r[:csrf] != "false"
      headers = headers.merge("HTTP_X_CSRF_TOKEN" => token) if %w[header both].include?(r[:csrf])
      params = params.merge("authenticity_token" => token) if %w[param both].include?(r[:csrf]) && !r[:body]
    end
    client.request(r[:method].to_sym, r[:path], params: params, headers: headers, expect: r[:expect], body: r[:body])
  end

  # Signs the measuring client in once: the form page's token, then the POST;
  # or a cookie (signed: true for a signed one), e.g. a session token the
  # file's ERB created.
  def sign_in(client, s)
    if (cookie = s["cookie"])
      name, value = cookie.fetch("name"), cookie.fetch("value").to_s
      return client.cookie(*(cookie["signed"] ? RailsCensus.signed_cookie(name.to_sym, value) : [name, value]))
    end
    path = s.fetch("path")
    body = client.get(s.fetch("form", path)).body
    token = body[/<meta name="csrf-token" content="([^"]+)"/, 1] || body[/name="authenticity_token" value="([^"]+)"/, 1]
    params = s.fetch("params")
    params = params.merge("authenticity_token" => token) if token
    client.request(s.fetch("method", "post").downcase.to_sym, path, params: params, headers: token ? { "HTTP_X_CSRF_TOKEN" => token } : {},
      expect: Array(s["expect"] || [302, 303]))
  rescue RuntimeError => e
    raise "sign_in failed: #{e.message}"
  end

  # GET routes the app serves with 200, found once (at setup) and cached, so
  # every later run measures the same pages.
  def discovered(c, client, options)
    if File.exist?(DISCOVERED)
      found = JSON.parse(File.read(DISCOVERED))
    else
      limit = options.is_a?(Hash) ? Integer(options.fetch("limit", 20)) : 20
      found = discover(client, limit)
      FileUtils.mkdir_p("tmp")
      File.write(DISCOVERED, JSON.pretty_generate(found) + "\n")
      found["skipped"].each { |s| puts format("skip     %-40s %s", s["route"], s["reason"]) }
    end
    found["requests"].map { request_spec(_1) }
  end

  def discover(client, limit)
    picked = []
    skipped = []
    seen = {}
    Rails.application.routes.routes.each do |route|
      next unless route.verb.to_s.split("|").include?("GET")
      template = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next if seen[template]
      seen[template] = true
      controller = route.defaults[:controller].to_s
      # Framework routes (health check, Active Storage, Action Mailbox) are not the app's pages.
      next if route.internal || template.start_with?("/rails/", "/assets", "/cable") || controller.start_with?("rails/")
      klass = "#{controller.camelize}Controller".safe_constantize unless controller.empty?
      where = klass && Object.const_source_location(klass.name)&.first
      reason = if controller.empty? then "not a controller action (mounted app, engine or redirect)"
      elsif template.include?("*") then "glob segment"
      elsif where && !where.start_with?(Rails.root.to_s + "/") then "controller from a gem (#{klass.name})"
      end
      next skipped << { "route" => template, "reason" => reason } if reason
      path, why = fill(template, route.required_parts, controller)
      next skipped << { "route" => template, "reason" => why } unless path
      next if picked.size >= limit
      begin
        3.times { client.get(path) }
        picked << { "name" => "GET #{template}", "method" => "get", "path" => path }
      rescue RuntimeError => e
        skipped << { "route" => template, "reason" => e.message[/HTTP \d+|empty body/] || e.message[0, 80] }
      rescue StandardError, ScriptError => e
        skipped << { "route" => template, "reason" => "#{e.class}: #{e.message[0, 80]}" }
      end
    end
    { "requests" => picked, "skipped" => skipped }
  end

  # :id from the controller's model, :NAME_id from NAME's model: the first
  # record by primary key. Anything else is skipped.
  def fill(template, parts, controller)
    path = template.gsub(/\([^()]*\)/, "")
    parts.each do |part|
      name = part == :id ? controller.split("/").last.singularize : part.to_s.delete_suffix("_id")
      return [nil, "needs :#{part}"] unless part == :id || part.to_s.end_with?("_id")
      model = name.camelize.safe_constantize
      return [nil, "needs :#{part} (no model #{name.camelize})"] unless model.is_a?(Class) && model < ActiveRecord::Base
      record = model.order(model.primary_key).first
      return [nil, "needs :#{part} (no #{model.name} record)"] unless record
      path = path.sub(":#{part}", record.to_param.to_s)
    end
    [path, nil]
  end

  # Fixture data for the copy: CENSUS_APP_PREPARE (a Ruby file run inside the
  # booted app), else the app's db/seeds.rb.
  def prepare
    # Seeds that draw random values draw the same ones in every setup.
    srand(42)
    begin
      require "faker"
      Faker::Config.random = Random.new(42)
    rescue LoadError
      nil
    end
    script = ENV["CENSUS_APP_PREPARE"]
    if script
      Kernel.load(script)
    elsif File.exist?("db/seeds.rb")
      Kernel.load("db/seeds.rb")
    end
  end
end
