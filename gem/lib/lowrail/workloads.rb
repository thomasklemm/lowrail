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

    # One request as the file declares it. #at(n) is the request for its n-th
    # run (from 1): alternates in turn, or the block's overrides for n.
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
        @name = opts[:name] || "#{verb.upcase} #{path}"
        @expect = Array(opts[:expect] || (verb == :get ? 200 : WRITE_EXPECT)).freeze
        @kind = @json ? :json : verb == :get ? :html : :form
        @csrf = opts.key?(:csrf) && !opts[:csrf] ? "false" : @json || @xhr ? "header" : "param"
        @jobs = opts[:jobs] ? true : false
        @signed_in = opts.fetch(:signed_in, true)
        @headers = Workloads.rack_headers(opts[:headers]).merge(opts[:env] || {})
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
      end

      def at(n)
        if @alternate then @alternate[n % @alternate.size - 1]
        elsif @block then copy(@scope.instance_exec(n, &@block))
        else self
        end
      end

      def to_h
        h = { "name" => name, "method" => verb.to_s, "path" => path, "params_sha256" => Workloads.digest(params),
          "body_sha256" => Workloads.digest(body), "headers" => headers.keys.sort, "expect" => expect, "kind" => kind.to_s }
        h["xhr"] = true if @xhr
        h["as"] = "json" if @json
        h["jobs"] = true if jobs
        h["signed_in"] = false unless signed_in
        h["csrf"] = false if csrf == "false"
        h["alternate"] = alternate.map { { "path" => _1.path, "params_sha256" => Workloads.digest(_1.params), "body_sha256" => Workloads.digest(_1.body) } } if alternate
        h["block"] = source if block
        h
      end

      protected

      # params as rack sends them (string keys), or for as: :json the body.
      def set(path, params)
        raise ArgumentError, "#{@source}: path must be a String starting with / (got #{path.inspect})" unless path.is_a?(String) && path.start_with?("/")
        @path = path.dup.freeze
        params = Workloads.stringify(params || {})
        @params, @body = @json && @verb != :get ? [{}.freeze, (params.to_json.freeze unless params.empty?)] : [params, nil]
      end

      private

      def copy(overrides)
        unknown = overrides.keys - %i[path params]
        raise ArgumentError, "#{@source}: an override sets only path: and params: (got #{unknown.join(", ")})" if unknown.any?
        dup.tap { _1.set(overrides.fetch(:path, @path), overrides.key?(:params) ? overrides[:params] : @params) }
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
        @sign_in_spec = { path: path, params: Workloads.stringify(params), method: method, form: form, expect: Array(expect), cookie: cookie }
      end

      # The page whose CSRF token the writes send (default: the first HTML GET).
      def csrf_from(path) = @csrf_page = path

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
          "format" => 1, "file" => file, "sha256" => (Digest::SHA256.file(file).hexdigest if File.exist?(file)),
          "setup" => setups, "lets" => @lets.keys.map(&:to_s).sort,
          "sign_in" => (sign_in_spec && (sign_in_spec[:cookie] ? { "cookie" => sign_in_spec[:cookie][:name].to_s } :
            { "method" => sign_in_spec[:method].to_s, "path" => sign_in_spec[:path], "params_sha256" => Workloads.digest(sign_in_spec[:params]) })),
          "csrf_from" => csrf_page_or_default, "requests" => requests.map(&:to_h),
          "mails" => mails.map { { "name" => _1.name, "block" => _1.source } },
          "jobs" => jobs.map { { "name" => _1.name, "block" => _1.source } }, "skip_jobs" => skipped_jobs)
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
        [%w[CONTENT_TYPE CONTENT_LENGTH].include?(key) || key.start_with?("HTTP_") ? key : "HTTP_#{key}", v.to_s]
      end
    end

    def stringify(value)
      case value
      when Hash then value.to_h { |k, v| [k.to_s, stringify(v)] }
      when Array then value.map { stringify(_1) }
      when Symbol then value.to_s
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

    def source(block) = block.source_location.then { "#{File.basename(_1)}:#{_2}" }
    def caller_source(locations) = locations.first.then { "#{File.basename(_1.path)}:#{_1.lineno}" }

    # A default name from the block's first source line.
    def guess(block, pattern)
      file, line = block.source_location
      text = File.exist?(file) ? File.readlines(file)[line - 1].to_s : ""
      (m = text.match(pattern)) && yield(*m.captures)
    end

    # Recorded request shapes (lowrail-profile --record) as render entries,
    # most frequent first. A write repeats one test's params, so it starts
    # commented out: it must not accumulate state from run to run.
    def recorded(shapes, limit)
      shapes.sort_by { [-_1["count"], _1["verb"] == "get" ? 0 : 1, _1["template"]] }.first(limit).map do |s|
        name = "#{s["verb"].upcase} #{s["template"]}#{".#{s["format"]}" if s["format"]}"
        { name: name, verb: s["verb"], route: s["route"], parts: s["parts"], template: s["template"], path: s["path"],
          format: s["format"], json: s["json"], xhr: s["xhr"], params: s["params"], commented: s["verb"] != "get",
          note: "#{s["count"]} #{s["count"] == 1 ? "request" : "requests"}#{" (a write: make it repeatable, then uncomment)" if s["verb"] != "get"}" }
      end
    end

    # A starter file from request shapes: name:, verb:, route: (helper name or
    # nil), parts: [[part, "Model" or nil]], template:, path: (an example),
    # format:, json:, xhr:, params:, note:, commented:. Each record a path
    # needs is the model's first row, looked up when the file is evaluated.
    def render(entries, intro)
      var = ->(model) { model.gsub("::", "_").gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase }
      models = entries.flat_map { |e| e[:parts].map(&:last) }.compact.uniq
      out = intro.lines.map { "# #{_1.chomp}".rstrip + "\n" }.join
      out << "\n" << models.map { "#{var.(_1)} = #{_1}.first!\n" }.join unless models.empty?
      spaced = true
      entries.each do |e|
        resolved = e[:parts].all?(&:last)
        target = if resolved && e[:route]
          args = e[:parts].map { var.(_2) }
          args << "format: :#{e[:format]}" if e[:format]
          "#{e[:route]}_path#{"(#{args.join(", ")})" unless args.empty?}"
        elsif resolved
          path = e[:template].gsub(/\([^()]*\)/, "")
          e[:parts].each { |part, model| path = path.sub(":#{part}", "\#{#{var.(model)}.to_param}") }
          %("#{path}#{".#{e[:format]}" if e[:format]}")
        else
          e[:path].inspect
        end
        line = +"#{e[:verb]} #{target}, name: #{e[:name].inspect}"
        line << ", as: :json" if e[:json]
        line << ", xhr: true" if e[:xhr]
        line << ", params: #{e[:params].inspect}" if e[:params] && !e[:params].empty?
        noted = e[:note] || !resolved
        out << "\n" if noted || spaced
        spaced = noted
        Array(e[:note]).each { out << "# #{_1}\n" }
        out << "# needs #{e[:parts].reject(&:last).map { ":#{_1[0]}" }.join(", ")}: the path is the one seen\n" unless resolved
        out << (e[:commented] ? "# " : "") << line << "\n"
      end
      out
    end
  end
end
