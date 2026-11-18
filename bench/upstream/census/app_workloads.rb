# frozen_string_literal: true

# Workloads for an app outside the registered corpus (script/census app). The
# harness loads this only with CENSUS_APP=1. The workloads file is the app's
# lowrail/workloads.rb (or --workloads FILE), the DSL lowrail-profile reads too
# (gem/lib/lowrail/workloads.rb), evaluated here after the app has booted.
# Without one, GET pages are discovered from the routes once and cached in the
# copy. Format: docs/upstream/census.md#workloads-file.
require_relative "../../../gem/lib/lowrail/workloads"

module CensusAppWorkloads
  DISCOVERED = "tmp/census-discovered.json"

  class << self
    attr_reader :manifest
  end

  module_function

  def definition(client, path)
    return Lowrail::Workloads.load(path) if path && File.exist?(path)
    d = Lowrail::Workloads::Definition.new("(discovered from the routes)")
    discovered(client)["requests"].each { d.get(_1["path"], name: _1["name"]) }
    d
  end

  def load(c, path)
    client = c::Client.new
    d = definition(client, path)
    sign_in(client, d.sign_in_spec) if d.sign_in_spec
    @manifest = d.manifest
    raise "no workloads: the file lists none and discovery found no page" if d.requests.empty? && d.mails.empty? && d.jobs.empty?
    anonymous = c::Client.new
    token_page = d.csrf_page_or_default
    tokens = {}
    token = ->(cl) { tokens.fetch(cl) { tokens[cl] = token_page && cl.csrf(token_page, required: false) } }
    ops = []
    jobs = []
    d.requests.each do |r|
      cl = r.signed_in ? client : anonymous
      turn = [0]
      call = -> { perform(cl, r.at(turn[0] += 1), r.verb == :get ? nil : token.(cl)) }
      ops << c::Op.new(r.name, r.kind, call)
      jobs.concat(c.jobs_from(&call)) if r.jobs
    end
    # Mail and job blocks run in the file's context, so its let values
    # (records the requests above created) are looked up on first use.
    d.mails.each { |m| ops << c.mail_op(m.name) { d.instance_exec(&m.block) } }
    jobs.uniq { _1["job_class"] }.reject { d.skipped_jobs.include?(_1["job_class"]) }.each { ops << c.job_op("perform #{_1["job_class"]}", _1) }
    d.jobs.each { |j| ops << c.job_op(j.name, d.instance_exec(&j.block).serialize) }
    names = ops.map(&:name)
    raise "duplicate workload names: #{names.select { names.count(_1) > 1 }.uniq.join(", ")}" if names.uniq.size != names.size
    ops
  end

  def perform(client, r, token)
    headers = r.headers
    params = r.params
    if token && r.csrf != "false"
      headers = headers.merge("HTTP_X_CSRF_TOKEN" => token) if r.csrf == "header"
      params = params.merge("authenticity_token" => token) if r.csrf == "param" && !r.body
    end
    client.request(r.verb, r.path, params: params, headers: headers, expect: r.expect, body: r.body)
  end

  # Signs the measuring client in once: the form page's token, then the POST;
  # or a cookie (signed: true for a signed one), e.g. a session token the
  # file created.
  def sign_in(client, s)
    if (cookie = s[:cookie])
      name, value = cookie.fetch(:name).to_s, cookie.fetch(:value).to_s
      return client.cookie(*(cookie[:signed] ? RailsCensus.signed_cookie(name.to_sym, value) : [name, value]))
    end
    body = client.get(s[:form]).body
    token = body[/<meta name="csrf-token" content="([^"]+)"/, 1] || body[/name="authenticity_token" value="([^"]+)"/, 1]
    params = s[:params]
    params = params.merge("authenticity_token" => token) if token
    client.request(s[:method].to_sym, s[:path], params: params, headers: token ? { "HTTP_X_CSRF_TOKEN" => token } : {},
      expect: s[:expect])
  rescue RuntimeError => e
    raise "sign_in failed: #{e.message}"
  end

  # GET routes the app serves with 200, found once (at setup) and cached, so
  # every later run measures the same pages.
  def discovered(client)
    return JSON.parse(File.read(DISCOVERED)) if File.exist?(DISCOVERED)
    found = discover(client, 20)
    FileUtils.mkdir_p("tmp")
    File.write(DISCOVERED, JSON.pretty_generate(found) + "\n")
    found["skipped"].each { |s| puts format("skip     %-40s %s", s["route"], s["reason"]) }
    found
  end

  # script/census app --init: the discovered pages as a starter workloads file.
  def init(c, output)
    found = discover(c::Client.new, 20)
    entries = found["requests"].map do |r|
      { name: r["name"], verb: "get", route: r["route"], parts: r["parts"], template: r["name"].delete_prefix("GET "), path: r["path"] }
    end
    skipped = found["skipped"].map { "  #{_1["route"]}: #{_1["reason"]}" }
    File.write(output, Lowrail::Workloads.render(entries, <<~TEXT))
      Workloads for script/census app and lowrail-profile (docs/upstream/census.md#workloads-file).
      Written by `script/census app --init` from the GET routes that answered 200; edit freely.
      Writes go below, as in an integration test, for example:
        sign_in "/session", params: { email: "census@example.com", password: "secret" }
        post comments_path, params: { comment: { body: "Hello" } }, expect: 302
        mail { CommentMailer.created(Comment.last!) }
      #{skipped.empty? ? "" : "Routes left out:\n#{skipped.join("\n")}"}
    TEXT
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
      path, why, models = fill(template, route.required_parts, controller)
      next skipped << { "route" => template, "reason" => why } unless path
      next if picked.size >= limit
      begin
        3.times { client.get(path) }
        picked << { "name" => "GET #{template}", "method" => "get", "path" => path, "route" => route.name,
          "parts" => route.required_parts.map(&:to_s).zip(models) }
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
    models = []
    parts.each do |part|
      name = part == :id ? controller.split("/").last.singularize : part.to_s.delete_suffix("_id")
      return [nil, "needs :#{part}"] unless part == :id || part.to_s.end_with?("_id")
      model = name.camelize.safe_constantize
      return [nil, "needs :#{part} (no model #{name.camelize})"] unless model.is_a?(Class) && model < ActiveRecord::Base
      record = model.order(model.primary_key).first
      return [nil, "needs :#{part} (no #{model.name} record)"] unless record
      path = path.sub(":#{part}", record.to_param.to_s)
      models << model.name
    end
    [path, nil, models]
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
