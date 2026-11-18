# frozen_string_literal: true

# The workloads file, lowrail/workloads.rb in the app, read by both
# `script/census app` and `lowrail-profile` (docs/upstream/census.md#workloads-file).
# It is Ruby in ActionDispatch::IntegrationTest's words (get, post, params:,
# headers:, xhr:, as: :json, route helpers), evaluated only inside an app that
# has finished booting, so it loads nothing earlier than the app would. Loading
# this file requires nothing; json and digest are required when a manifest is built.
module Lowrail
  module Workloads
    PATH = "lowrail/workloads.rb"
    VERBS = %i[get post patch put delete].freeze
    WRITE_EXPECT = [200, 201, 202, 204, 302, 303].freeze
    JSON_TYPE = "application/json"
    OPTIONS = %i[params headers env xhr as name expect jobs alternate signed_in csrf].freeze
    # What a recording writes for a value the app's filter_parameters hides.
    FILTERED = "[FILTERED]"
    # A browser's headers, which both clients send under each request's own:
    # census 4's Rack::Test client and lowrail-profile's (MockClient, which
    # also sends the Host header Rack::Test sends). Apps
    # branch on them (allow_browser, Origin and Sec-Fetch-Site CSRF checks).
    BROWSER = { "HTTPS" => "on", "HTTP_USER_AGENT" => "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
      "HTTP_ACCEPT" => "text/html", "HTTP_SEC_FETCH_SITE" => "same-origin", "HTTP_ORIGIN" => "https://localhost" }.freeze
    CONSTANT = /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/
    HELPER = /\A[a-z_]\w*\z/

    # One request as the file declares it. #at(n) is the request for its n-th
    # run (from 1): alternates in turn, or the block's overrides for n. Its
    # values are frozen copies, so changing an object the file passed in does
    # not change the request after its manifest was written.
    class Request
      attr_reader :name, :verb, :path, :params, :body, :headers, :expect, :kind, :csrf, :jobs, :signed_in, :alternate, :block, :source

      def initialize(verb, path, opts, block, scope, source)
        unknown = opts.keys - OPTIONS
        raise ArgumentError, "#{source}: unknown option #{unknown.map(&:inspect).join(", ")} (#{OPTIONS.join(", ")})" if unknown.any?
        raise ArgumentError, "#{source}: as: #{opts[:as].inspect} is not supported (only :json)" if opts[:as] && opts[:as] != :json
        @verb, @scope, @source, @block = verb, scope, source, block
        @json = opts[:as] == :json
        @xhr = opts[:xhr] ? true : false
        # IntegrationTest sends a JSON GET with params as a POST with a method override.
        @verb = :post if verb == :get && @json && opts[:params]
        @name = -((opts[:name] || "#{verb.upcase} #{path}").to_s)
        @expect = [*(opts[:expect] || (verb == :get ? 200 : WRITE_EXPECT))].freeze
        @kind = @json ? :json : verb == :get ? :html : :form
        @csrf = opts.key?(:csrf) && !opts[:csrf] ? "false" : @json || @xhr ? "header" : "param"
        @jobs = opts[:jobs] ? true : false
        @signed_in = opts.fetch(:signed_in, true) ? true : false
        @headers = Workloads.rack_headers(opts[:headers]).merge(Workloads.stringify(opts[:env] || {}))
        @headers = { "HTTP_ACCEPT" => JSON_TYPE, "CONTENT_TYPE" => JSON_TYPE }.merge(@headers) if @json
        @headers["HTTP_X_HTTP_METHOD_OVERRIDE"] = "GET" if @verb != verb
        if @xhr
          @headers["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest"
          @headers["HTTP_ACCEPT"] ||= "text/javascript, text/html, application/xml, text/xml, */*"
        end
        @headers.freeze
        set(path, opts[:params])
        if (list = opts[:alternate])
          raise ArgumentError, "#{source}: alternate: takes a list of overrides (path:, params:)" unless list.is_a?(Array) && list.all?(Hash)
          @alternate = list.map { |o| copy(o) }.freeze
        end
        freeze
      end

      def at(n)
        if @alternate then @alternate[n % @alternate.size - 1]
        elsif @block then copy(@scope.instance_exec(n, &@block))
        else self
        end
      end

      # The declaration only: a block's overrides are not known until it runs
      # (lowrail-profile --workloads lists the variants it measured).
      def to_h
        h = { "name" => name, "method" => verb.to_s, "path" => path, "params_sha256" => Workloads.digest(params),
          "body_sha256" => Workloads.digest(body), "headers" => headers.keys.sort,
          "headers_sha256" => Workloads.digest(headers.sort.map { |k, v| [k, String === v ? v : Workloads.class_of(v).name] }),
          "expect" => expect, "kind" => kind.to_s }
        h["xhr"] = true if @xhr
        h["as"] = "json" if @json
        h["jobs"] = true if jobs
        h["signed_in"] = false unless signed_in
        h["csrf"] = false if csrf == "false"
        h["alternate"] = alternate.map(&:variant) if alternate
        h["block"] = source if block
        h
      end

      def variant = { "path" => path, "params_sha256" => Workloads.digest(params), "body_sha256" => Workloads.digest(body) }

      protected

      # params as rack sends them (string keys), or for as: :json the body.
      def set(path, params)
        raise ArgumentError, "#{@source}: path must be a String starting with / (got #{path.inspect})" unless path.is_a?(String) && path.start_with?("/")
        @path = -path
        # Kept apart from the body, so an override of the path alone keeps them.
        @declared = Workloads.stringify(params || {})
        @params, @body = @json && @verb != :get ? [{}.freeze, (-@declared.to_json unless @declared.empty?)] : [@declared, nil]
      end

      private

      def copy(overrides)
        raise ArgumentError, "#{@source}: an override is a Hash of path: and params: (got #{overrides.inspect})" unless overrides.is_a?(Hash)
        unknown = overrides.keys - %i[path params]
        raise ArgumentError, "#{@source}: an override sets only path: and params: (got #{unknown.join(", ")})" if unknown.any?
        dup.tap { _1.set(overrides.fetch(:path, @path), overrides.key?(:params) ? overrides[:params] : @declared) }.freeze
      end
    end

    Mail = Struct.new(:name, :block, :source)
    Job = Struct.new(:name, :block, :source)

    # The file's evaluation context. Methods a file may call are public; route
    # helpers come from the app's routes.
    class Definition
      attr_reader :file, :requests, :mails, :jobs, :skipped_jobs, :sign_in_spec, :csrf_page, :setups

      def initialize(file)
        @file = file
        @requests, @mails, @jobs, @skipped_jobs, @setups = [], [], [], [], []
        @lets = {}
        singleton_class.include(Rails.application.routes.url_helpers) if defined?(Rails.application.routes)
      end

      VERBS.each do |verb|
        define_method(verb) do |path, **opts, &block|
          @requests << Request.new(verb, path, opts, block, self, Workloads.caller_source(caller_locations(1, 1)))
          nil
        end
      end

      # Runs at once, in file order: resets and lookups the requests below need.
      def setup(&block)
        @setups << Workloads.source(block)
        instance_exec(&block)
      end

      # A value computed on first use, then kept: a record the requests create
      # before a mail or job uses it.
      def let(name, &block)
        lets = @lets
        define_singleton_method(name) { lets.fetch(name) { lets[name] = instance_exec(&block) } }
      end

      # Sign the measuring client in once: GET form (default: path) for its
      # token, then this request; or set a cookie (signed: true for a signed one).
      def sign_in(path = nil, params: {}, method: :post, form: path, expect: [302, 303], cookie: nil)
        raise ArgumentError, "sign_in takes a path or cookie:" unless path || cookie
        @sign_in_spec = Workloads.deep_freeze({ path: path && -path, params: Workloads.stringify(params), method: method.to_sym,
          form: form && -form, expect: [*expect], cookie: cookie && Workloads.stringify(cookie.to_h).transform_keys(&:to_sym) })
      end

      # The page whose CSRF token the writes send (default: the first HTML GET).
      def csrf_from(path) = @csrf_page = -path

      # A mail delivered with deliver_now; the block returns the message.
      def mail(name = nil, &block)
        source = Workloads.source(block)
        @mails << Mail.new(name || Workloads.guess(block, /\b([A-Z]\w*(?:::[A-Z]\w*)*Mailer)\.(\w+)/) { "deliver #{_1}##{_2}" } || "mail at #{source}", block, source)
      end

      # A job performed as a queue would run it; the block returns the job (MyJob.new(args)).
      def job(name = nil, &block)
        source = Workloads.source(block)
        @jobs << Job.new(name || Workloads.guess(block, /\b([A-Z]\w*(?:::[A-Z]\w*)*)\.new\b/) { "perform #{_1}" } || "job at #{source}", block, source)
      end

      # Jobs that requests with jobs: true enqueue, left out by class name.
      def skip_jobs(*names) = @skipped_jobs.concat(names.flatten.map(&:to_s))

      def csrf_page_or_default = @csrf_page || requests.find { _1.verb == :get && _1.kind == :html }&.path

      def manifest
        require "json"
        require "digest"
        @manifest ||= Workloads.deep_freeze(
          "format" => 2, "file" => file, "sha256" => (Digest::SHA256.file(file).hexdigest if File.exist?(file)),
          "setup" => setups, "lets" => @lets.keys.map(&:to_s).sort, "sign_in" => sign_in_manifest,
          "csrf_from" => csrf_page_or_default, "requests" => requests.map(&:to_h),
          "mails" => mails.map { { "name" => _1.name, "block" => _1.source } },
          "jobs" => jobs.map { { "name" => _1.name, "block" => _1.source } }, "skip_jobs" => skipped_jobs)
      end

      private

      # Digests, not values: the manifest is written next to reports.
      def sign_in_manifest
        s = sign_in_spec or return
        if (cookie = s[:cookie])
          { "cookie" => cookie[:name].to_s, "signed" => cookie[:signed] ? true : false, "value_sha256" => Workloads.digest(cookie[:value].to_s) }
        else
          { "method" => s[:method].to_s, "path" => s[:path], "form" => s[:form], "expect" => s[:expect], "params_sha256" => Workloads.digest(s[:params]) }
        end
      end
    end

    # The request policy both clients follow, so script/census app and
    # lowrail-profile --workloads send the same requests: sign-in, the CSRF
    # token (from csrf_from's page, as a param or X-CSRF-Token header), and
    # each request's turn. A client answers request(verb, path, params:,
    # headers:, body:, expect:) with a response that has #body (raising when
    # the status is not expected), and cookie(name, value).
    class Replayer
      def initialize(definition, signed_in, anonymous)
        @definition, @signed_in, @anonymous = definition, signed_in, anonymous
        @tokens = {}.compare_by_identity
        @turns = {}.compare_by_identity
      end

      def sign_in
        s = @definition.sign_in_spec or return
        if (cookie = s[:cookie])
          name, value = cookie.fetch(:name).to_s, cookie.fetch(:value).to_s
          return @signed_in.cookie(*(cookie[:signed] ? Workloads.signed_cookie(name, value) : [name, value]))
        end
        token = Workloads.csrf_token(@signed_in.request(:get, s[:form]).body)
        params = token ? s[:params].merge("authenticity_token" => token) : s[:params]
        @signed_in.request(s[:method], s[:path], params: params, headers: token ? { "HTTP_X_CSRF_TOKEN" => token } : {}, expect: s[:expect])
      end

      # The request's next turn; returns the request as sent (path and params).
      def perform(r)
        client = r.signed_in ? @signed_in : @anonymous
        spec = r.at(@turns[r] = @turns.fetch(r, 0) + 1)
        headers, params = spec.headers, spec.params
        if r.verb != :get && r.csrf != "false" && (token = token(client))
          headers = headers.merge("HTTP_X_CSRF_TOKEN" => token) if r.csrf == "header"
          params = params.merge("authenticity_token" => token) if r.csrf == "param" && !spec.body
        end
        client.request(r.verb, spec.path, params: params, headers: headers, expect: r.expect, body: spec.body)
        spec
      end

      private

      def token(client)
        @tokens.fetch(client) do
          page = @definition.csrf_page_or_default
          @tokens[client] = page && Workloads.csrf_token(client.request(:get, page).body)
        end
      end
    end

    # lowrail-profile --workloads' client: Rack::MockRequest through the app's
    # full middleware stack with BROWSER's headers, keeping the cookies earlier
    # responses set, as a browser keeps the session. Requires rack/mock.
    class MockClient
      Response = Struct.new(:status, :body)

      def initialize(app, host)
        @app, @host, @cookies = app, host, {}
        @headers = BROWSER.merge("HTTP_HOST" => host, "HTTP_ORIGIN" => "https://#{host}").freeze
      end

      def cookie(name, value) = @cookies[name] = value

      def request(verb, path, params: {}, headers: {}, expect: [200], body: nil)
        opts = { method: verb.to_s.upcase, **@headers, **headers }
        opts["HTTP_COOKIE"] = @cookies.map { "#{_1}=#{_2}" }.join("; ") unless @cookies.empty?
        # As Rack::Test: a write without a body is still an empty form.
        if body then opts[:input] = body
        elsif verb != :get || !params.empty? then opts[:params] = params
        end
        status, response_headers, response = @app.call(Rack::MockRequest.env_for("https://#{@host}#{path}", opts))
        text = +""
        begin
          response.each { text << _1 }
        ensure
          response.close if response.respond_to?(:close)
        end
        Array(response_headers["set-cookie"]).flat_map { _1.split("\n") }.each do |line|
          key, value = line.split(";", 2).first.split("=", 2)
          line.match?(/;\s*max-age=0|;\s*expires=Thu, 01 Jan 1970/i) ? @cookies.delete(key) : @cookies[key] = value
        end
        raise "#{verb.upcase} #{path} returned #{status} (expected #{Array(expect).join(" or ")})" unless Array(expect).include?(status)
        raise "#{verb.upcase} #{path}: empty body" if status == 200 && text.empty? && verb == :get
        Response.new(status, text)
      end
    end

    module_function

    def load(file)
      definition = Definition.new(file)
      definition.instance_eval(File.read(file), file, 1)
      names = definition.requests.map(&:name) + definition.mails.map(&:name) + definition.jobs.map(&:name)
      dups = names.select { names.count(_1) > 1 }.uniq
      raise ArgumentError, "#{file}: duplicate names #{dups.join(", ")}; give one of each a name:" if dups.any?
      definition.requests.freeze
      definition
    end

    def rack_headers(headers)
      (headers || {}).to_h do |k, v|
        key = k.to_s.upcase.tr("-", "_")
        [%w[CONTENT_TYPE CONTENT_LENGTH].include?(key) || key.start_with?("HTTP_") ? key : "HTTP_#{key}", -v.to_s]
      end
    end

    # A frozen copy with string keys; strings are copied, other objects kept.
    def stringify(value)
      case value
      when Hash then value.to_h { |k, v| [-k.to_s, stringify(v)] }.freeze
      when Array then value.map { stringify(_1) }.freeze
      when Symbol then -value.to_s
      when String then -value
      else value
      end
    end

    def digest(value)
      return if value.nil? || value.respond_to?(:empty?) && value.empty?
      Digest::SHA256.hexdigest(value.is_a?(String) ? value : JSON.generate(value))[0, 16]
    end

    def deep_freeze(value)
      case value
      when Hash then value.each_value { deep_freeze(_1) }.freeze
      when Array then value.each { deep_freeze(_1) }.freeze
      else value.freeze
      end
    end

    KERNEL_CLASS = Kernel.instance_method(:class)
    def class_of(value) = KERNEL_CLASS.bind_call(value)

    def source(block) = block.source_location.then { "#{File.basename(_1)}:#{_2}" }
    def caller_source(locations) = locations.first.then { "#{File.basename(_1.path)}:#{_1.lineno}" }

    # A default name from the block's first source line.
    def guess(block, pattern)
      file, line = block.source_location
      text = File.exist?(file) ? File.readlines(file)[line - 1].to_s : ""
      (m = text.match(pattern)) && yield(*m.captures)
    end

    # The token a page gives a form: its csrf-token meta tag, or a form's field.
    def csrf_token(body)
      body[/<meta name="csrf-token" content="([^"]+)"/, 1] || body[/name="authenticity_token" value="([^"]+)"/, 1]
    end

    # A cookie signed with the app's own key generator, as the app signs it.
    def signed_cookie(name, value)
      require "action_dispatch/testing/test_request"
      request = ActionDispatch::TestRequest.create
      request.env.merge!(Rails.application.env_config)
      request.cookie_jar.signed[name.to_sym] = value
      request.cookie_jar.to_header.split("=", 2)
    end

    # Recorded request shapes (lowrail-profile --record) as render entries,
    # most frequent first. Only a shape that replays as recorded is enabled:
    # a GET whose path parts are records the file can look up and whose params
    # were kept whole and unfiltered. A write repeats one test's params, so it
    # must not accumulate state from run to run; it and every other shape
    # start commented out, with the reason.
    def recorded(shapes, limit)
      shapes.sort_by { [-_1["count"], _1["verb"] == "get" ? 0 : 1, _1["template"], _1["format"].to_s] }.first(limit).map do |s|
        format = s["format"]
        name = "#{s["verb"].upcase} #{s["template"]}#{".#{format}" if format}#{" (#{s["accept"]})" if s["accept"]}"
        reasons = []
        reasons << "a write: make it repeatable, then uncomment" if s["verb"] != "get"
        reasons << "the app's filter_parameters could not be applied, so its params were not kept" if s["unfiltered"]
        reasons << "values the app filters are #{FILTERED}: fill them in" if s["filtered"]
        reasons << "part of the request was not kept (long or binary values, uploads, optional path parts or a write's query)" if s["lossy"]
        missing = s["parts"].reject(&:last).map { ":#{_1[0]}" }
        reasons << "needs #{missing.join(", ")}: the path is the one seen" if missing.any?
        { name: name, verb: s["verb"], route: s["route"], parts: s["parts"], template: s["template"], seen: s["seen"],
          format: format, json: s["json"], xhr: s["xhr"], accept: s["accept"], params: s["params"], commented: reasons.any?,
          note: "#{s["count"]} #{s["count"] == 1 ? "request" : "requests"}#{" (#{reasons.join("; ")})" if reasons.any?}" }
      end
    end

    # A starter file from request shapes: name:, verb:, route: (helper name or
    # nil), parts: [[part, "Model" or nil]], template:, path: or seen: (the
    # path an unresolved shape was seen with), format:, json:, xhr:, accept:,
    # params:, note:, commented:. Each record a path needs is the model's first
    # row, looked up when the file is evaluated (commented out when only
    # commented-out requests use it). Every value from a request is a quoted
    # literal, never Ruby syntax.
    def render(entries, intro)
      var = ->(model) { model.gsub("::", "_").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase }
      entries = entries.map do |e|
        parts = e[:parts].map { |part, model| [part.to_s, (model if model.is_a?(String) && model.match?(CONSTANT))] }
        e.merge(parts: parts, resolved: parts.all?(&:last))
      end
      models = ->(list) { list.flat_map { |e| e[:parts].map(&:last) }.compact.uniq }
      live = models.(entries.select { _1[:resolved] && !_1[:commented] })
      out = intro.lines.map { "# #{_1.chomp}".rstrip + "\n" }.join
      bindings = models.(entries).map { "#{"# " unless live.include?(_1)}#{var.(_1)} = #{_1}.first!\n" }
      out << "\n" << bindings.join unless bindings.empty?
      spaced = true
      entries.each do |e|
        target = if e[:resolved] && e[:route].is_a?(String) && e[:route].match?(HELPER)
          args = e[:parts].map { var.(_2) }
          args << "format: #{e[:format].to_s.inspect}" if e[:format]
          "#{e[:route]}_path#{"(#{args.join(", ")})" unless args.empty?}"
        elsif e[:resolved]
          path_literal(e[:template], e[:parts].to_h { |part, model| [part, [:ruby, "#{var.(model)}.to_param"]] }, e[:format])
        elsif e[:path]
          e[:path].to_s.inspect
        else
          path_literal(e[:template], (e[:seen] || {}).to_h { |part, value| [part.to_s, [:text, value.to_s]] }, e[:format])
        end
        line = +"#{e[:verb]} #{target}, name: #{e[:name].to_s.inspect}"
        line << ", as: :json" if e[:json]
        line << ", xhr: true" if e[:xhr]
        line << ", headers: { \"Accept\" => #{e[:accept].to_s.inspect} }" if e[:accept]
        line << ", params: #{e[:params].inspect}" if e[:params].is_a?(Hash) && !e[:params].empty?
        commented = e[:commented] || !e[:resolved]
        noted = e[:note] || !e[:resolved]
        out << "\n" if noted || spaced
        spaced = noted
        Array(e[:note]).each { out << "# #{_1}\n" }
        out << "# needs #{e[:parts].reject(&:last).map { ":#{_1[0]}" }.join(", ")}: the path is the one seen\n" if !e[:resolved] && !e[:note]
        out << (commented ? "# " : "") << line << "\n"
      end
      out
    end

    # A double-quoted Ruby string for a route template: its text escaped,
    # each :part a value ([:ruby, expression] interpolated, [:text, string]
    # escaped), optional segments left out, then the format.
    def path_literal(template, values, format)
      text = ->(s) { s.inspect[1..-2] }
      body = template.to_s.gsub(/\([^()]*\)/, "").split(/(:[a-z_]\w*)/).map do |piece|
        kind, value = values[piece.delete_prefix(":")] if piece.start_with?(":")
        if kind == :ruby then "\#{#{value}}"
        elsif kind == :text then text.(value)
        else text.(piece)
        end
      end.join
      %("#{body}#{text.(".#{format}") if format}")
    end
  end
end
