# frozen_string_literal: true

# In-app allocation profile (docs/profile.md). Loaded only by exe/lowrail-profile,
# through RUBYOPT, when LOWRAIL_PROFILE names an output directory; nothing in
# Lowrail requires it otherwise, so an app with the gem but without the
# variable runs unchanged.
#
# Counts objects per source line inside windows: Rails::Engine#call (every
# request the app serves: integration and system tests, a local server, a
# workloads file), Active Job's perform_now, a mail's build and delivery, and
# Action Cable channel actions. Each window is named by its controller action,
# job, mailer action or channel action. Writes one TSV per process at exit. It
# never forces a load: every hook is installed from Active Support's on_load
# hooks, when the framework class is defined. Like the rest of setup, it
# requires no default gems, so Bundler's activation is unchanged.
#
# Never break the app: an extension of another version is refused before
# anything is hooked, and every profiler call (installing a hook, opening,
# naming and closing a window, recording) is contained where it runs, so the
# app's own results and exceptions pass through unchanged. Code in other
# Ractors runs uncounted: the native tables are the main Ractor's.
if (dir = ENV["LOWRAIL_PROFILE"]) && !dir.empty?
  begin
    ext = ENV.fetch("LOWRAIL_PROFILE_EXT")
    require ext
    api = (Lowrail::Profile::API if defined?(Lowrail::Profile::API))
    raise LoadError, "#{ext} is not this lowrail-profile's counter (API #{api.inspect}, expected 2); run lowrail-profile again" unless api == 2
    require_relative "load_hooks"

    module Lowrail
      module Profile
        TYPES = %w[NONE Object Class Module Float String Regexp Array Hash Struct Bignum File Data MatchData
          Complex Rational 0x10 nil true false Symbol Fixnum undef 0x17 0x18 0x19 IMEMO Node ICLASS Zombie
          Moved 0x1f].freeze

        KINDS = %w[request job mail cable].freeze
        # What exe/lowrail-profile sets for the command (leave_env removes it).
        ENV_KEYS = %w[LOWRAIL_PROFILE LOWRAIL_PROFILE_EXT LOWRAIL_PROFILE_ROOT LOWRAIL_PROFILE_ATTRIBUTE LOWRAIL_PROFILE_RECORD
          LOWRAIL_PROFILE_ALLOW_WRITES LOWRAIL_PROFILE_LIB LOWRAIL_PROFILE_CALLER_SEED LOWRAIL_PROFILE_CALLER_SPEC_OPTS].freeze
        APP_ROOT = ENV["LOWRAIL_PROFILE_ROOT"]
        HASH = "#"
        DOT = "."
        PERFORM = "perform"
        PERFORM_ACTION = "perform_action"
        SUBSCRIBED = "subscribed"
        DELIVER = "deliver_mail"
        ACTION = "action"
        NOTED = "lowrail.profile.noted"
        FILTERED = "[FILTERED]"
        JSON_TYPE = "application/json"
        # A write's Accept values a workloads file sends anyway (html, IntegrationTest's, xhr:, as: :json).
        PLAIN_ACCEPT = %w[*/* text/html text/xml application/xml application/xhtml+xml application/json text/javascript].freeze
        CONSTANT = /\A[A-Z]\w*(?:::[A-Z]\w*)*\z/
        KERNEL_CLASS = Kernel.instance_method(:class)

        module Window
          def call(env)
            open = Profile.open(0)
            super
          ensure
            Profile.close(open, env)
          end
        end

        # Names the request after the first controller action it dispatches.
        module Dispatch
          def dispatch(name, request, response)
            Profile.named(self.class, HASH, name)
            super
          end
        end

        # Minitest reads SEED in Minitest.run, before it initializes plugins
        # (register_plugin since 5.24; init_plugins before).
        module Suite
          def self.minitest_plugin_init(_options) = Profile.leave_env

          def init_plugins(...)
            Profile.leave_env
            super
          end
        end

        module Job
          def perform_now
            open = Profile.open(1)
            Profile.named(self.class, HASH, PERFORM) if open
            super
          ensure
            Profile.close(open)
          end
        end

        # A worker deserializes the job's arguments before perform_now.
        module JobExecute
          def execute(...)
            open = Profile.open(1)
            super
          ensure
            Profile.close(open)
          end
        end

        # A mail's build (the mailer action and its templates) and its
        # delivery are separate windows, as the app runs them.
        module MailBuild
          def process(method_name, ...)
            open = Profile.open(2)
            Profile.named(self.class, HASH, method_name) if open
            super(method_name, ...)
          ensure
            Profile.close(open)
          end
        end

        module MailDelivery
          def deliver_mail(...)
            open = Profile.open(2)
            Profile.named(self, DOT, DELIVER) if open
            super
          ensure
            Profile.close(open)
          end
        end

        # Channel actions are not request shapes: --record notes only Rack requests.
        module Cable
          def perform_action(data)
            open = Profile.open(3)
            Profile.cable_named(self.class, data) if open
            super
          ensure
            Profile.close(open)
          end

          def subscribe_to_channel
            open = Profile.open(3)
            Profile.named(self.class, HASH, SUBSCRIBED) if open
            super
          ensure
            Profile.close(open)
          end
        end

        # A forked worker (parallel tests, a preforking server) starts from
        # zero, so the parent's requests are not counted twice.
        module Fork
          def _fork
            pid = super
            Profile.forked if pid == 0
            pid
          end
        end

        class << self
          # Ractor.main? is Ruby 3.4's.
          if Ractor.respond_to?(:main?)
            def main? = Ractor.main?
          else
            def main? = Ractor.current.equal?(Ractor.main)
          end

          # lowrail-profile --record: request shapes by route, noted after the
          # window closes, so they are not counted.
          attr_accessor :shapes

          # Each returns quietly when the profiler cannot do its part.
          def open(kind)
            main? && enter(kind)
          rescue StandardError
            false
          end

          def close(open, env = nil)
            return unless open
            leave
            note(env) if env && shapes
          rescue StandardError
            nil
          end

          def named(klass, separator, action)
            label(klass, separator, action) if main?
          rescue StandardError
            nil
          end

          def cable_named(klass, data)
            label(klass, HASH, (data[ACTION] if Hash === data) || PERFORM_ACTION) if main?
          rescue StandardError
            nil
          end

          def forked
            reset
            self.shapes = {} if shapes
          rescue StandardError
            nil
          end

          # A framework hook that cannot be installed (a frozen class) leaves
          # that framework uncounted and the app's load as it was.
          def install(what)
            yield
          rescue StandardError, ScriptError => error
            warn "[lowrail-profile] #{what} not profiled: #{error.class}: #{error.message}"
          end

          # Once the suite has read its seed, puts back the environment
          # exe/lowrail-profile changed, so every process the suite starts
          # (an rspec in after(:suite), a rake task) runs as without it:
          # unprofiled, with the caller's SEED and SPEC_OPTS. Bundler's own
          # RUBYOPT and RUBYLIB entries stay.
          def leave_env
            return if @left
            @left = true
            ENV["SEED"] = ENV["LOWRAIL_PROFILE_CALLER_SEED"]
            ENV["SPEC_OPTS"] = ENV["LOWRAIL_PROFILE_CALLER_SPEC_OPTS"]
            lib = ENV["LOWRAIL_PROFILE_LIB"]
            { "RUBYOPT" => [" ", ["-I#{lib}", "-rlowrail/profile"]], "RUBYLIB" => [File::PATH_SEPARATOR, [lib]] }.each do |key, (separator, ours)|
              parts = ENV[key].to_s.split(separator)
              ours.each { |part| (i = parts.index(part)) && parts.delete_at(i) }
              ENV[key] = parts.empty? ? nil : parts.join(separator)
            end
            ENV_KEYS.each { ENV.delete(_1) }
          rescue StandardError => error
            warn "[lowrail-profile] processes the suite starts may be profiled: #{error.class}: #{error.message}"
          end

          def note(env)
            return if env[NOTED] || !(route = env["action_dispatch.route"] || matched_route(env))
            env[NOTED] = true
            verb = env["REQUEST_METHOD"].to_s.downcase
            filter = parameter_filter(env)
            # Every path value, the format included, is filtered before it names,
            # groups or is kept; without the app's filter none is kept.
            path_params = filter ? filter.filter((env["action_dispatch.request.path_parameters"] || {}).transform_keys(&:to_s)) : {}
            format = path_params["format"]&.to_s&.dup&.freeze
            # Accept is filtered as Rails' filtered_env filters it, and not kept
            # without the app's filter.
            accept = filter ? filter.filter("HTTP_ACCEPT" => env["HTTP_ACCEPT"].to_s)["HTTP_ACCEPT"].to_s.dup.freeze : ""
            first = accept[/\A[^,;]*/].strip.downcase
            # A GET keeps its Accept as sent, never as: :json, which would send its query as a body.
            json = verb != "get" && [env["CONTENT_TYPE"], env["HTTP_ACCEPT"]].any? { _1.to_s.start_with?(JSON_TYPE) }
            accept = nil if first.empty? || (verb != "get" && PLAIN_ACCEPT.include?(first))
            xhr = env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
            spec = route.path.spec.to_s
            shape = shapes[[verb, spec, json, xhr, format, accept, !filter]] ||=
              shape_of(env, route, verb, spec, path_params, filter, format: format, json: json, xhr: xhr, accept: accept)
            shape["count"] += 1
          rescue StandardError
            nil
          end

          # Rails before 8.1 keeps only the matched route's pattern and
          # parameters: the route with that pattern, controller and action,
          # or none when routes share them (their constraints and defaults,
          # which tell them apart, are not run again here).
          def matched_route(env)
            spec = env["action_dispatch.route_uri_pattern"] or return
            params = env["action_dispatch.request.path_parameters"] || {}
            candidates = env["action_dispatch.routes"]&.routes&.select do |r|
              r.path.spec.to_s == spec && r.defaults[:controller] == params[:controller] && r.defaults[:action] == params[:action]
            end
            candidates.first if candidates&.size == 1
          end

          # What a workloads file needs to send the request again, with the
          # app's filter_parameters applied before anything is kept. Params
          # are kept only if they could be filtered; nothing is taken from the
          # raw path or query string.
          def shape_of(env, route, verb, spec, path_params, filter, **flags)
            lossy = [false]
            controller = route.defaults[:controller].to_s
            required = route.required_parts.map(&:to_s)
            parts = required.map do |part|
              base = part == "id" ? controller.split("/").last.to_s : part.delete_suffix("_id") if part == "id" || part.end_with?("_id")
              model = base.singularize.camelize if base && !base.empty?
              [part, (model if model && record_class?(model))]
            end
            lossy[0] = true if (path_params.keys - %w[controller action format] - required - route.defaults.keys.map(&:to_s)).any?
            query = env["QUERY_STRING"].to_s
            params = if verb == "get"
              lossy[0] = true if env["CONTENT_LENGTH"].to_i > 0
              query.empty? ? {} : env["action_dispatch.request.query_parameters"] || (lossy[0] = true; {})
            else
              lossy[0] = true unless query.empty?
              env["action_dispatch.request.request_parameters"] || (env["CONTENT_LENGTH"].to_i > 0 ? (lossy[0] = true; {}) : {})
            end
            params = filter && plain(filter.filter(params.except("authenticity_token")), lossy)
            seen = filter && plain(path_params.slice(*required), lossy)
            name = route.name || env["action_dispatch.routes"]&.routes&.find { _1.name && _1.path.spec.to_s == spec }&.name
            { "verb" => verb, "template" => spec.sub(/\(\.:format\)\z/, ""), "route" => name, "parts" => parts,
              "seen" => seen, **flags.transform_keys(&:to_s), "params" => params, "unfiltered" => !filter,
              "filtered" => filtered?(params) || filtered?(seen) || flags[:format] == FILTERED || flags[:accept] == FILTERED, "lossy" => lossy[0], "count" => 0 }
          end

          # The app's filter, only when its list is names and patterns: a Proc
          # may depend on Rails' merged params, which the parts filtered here
          # are not, so with one no request value is kept. Rebuilt when the
          # list's contents change (an initializer or test may change it after
          # the first request, or a String in it in place).
          def parameter_filter(env)
            klass = Lowrail.loaded_constant("ActiveSupport::ParameterFilter") or return
            filters = Array(env["action_dispatch.parameter_filter"])
            return unless filters.all? { Symbol === _1 || String === _1 || Regexp === _1 }
            unless @filter && @filter_source == filters
              @filter_source = filters.map { String === _1 ? _1.dup.freeze : _1 }.freeze
              @filter = klass.new(@filter_source, mask: FILTERED)
            end
            @filter
          end

          # An Active Record model the app has loaded already (never loads one).
          def record_class?(name)
            return false unless name.match?(CONSTANT)
            base = Lowrail.loaded_constant("ActiveRecord::Base")
            model = base && Lowrail.loaded_constant(name)
            Class === model && model < base ? true : false
          end

          def filtered?(value)
            case value
            when Hash then value.each_value.any? { filtered?(_1) }
            when Array then value.any? { filtered?(_1) }
            else value == FILTERED
            end
          end

          # JSON-safe copy; lossy[0] is set when anything was shortened or replaced.
          def plain(value, lossy)
            case value
            when Hash then value.to_h { [_1.to_s, plain(_2, lossy)] }
            when Array then (lossy[0] = true if value.size > 50; value.first(50).map { plain(_1, lossy) })
            when String
              if !value.valid_encoding? || (value.encoding != Encoding::UTF_8 && !value.ascii_only?) then (lossy[0] = true; "(binary)")
              elsif value.size > 2000 then (lossy[0] = true; value[0, 2000])
              else value.dup.freeze
              end
            when Integer, true, false, nil then value
            when Float then value.finite? ? value : (lossy[0] = true; nil)
            else (lossy[0] = true; "(#{KERNEL_CLASS.bind_call(value)})")
            end
          end

          def write(dir)
            windows, objects, dropped, rows, actions, attributed = snapshot
            return if windows.sum == 0
            root = (Rails.root.to_s if defined?(Rails) && Rails.respond_to?(:root) && Rails.root)
            lines = [["# lowrail-profile 3", "requests=#{windows[0]}", "objects=#{objects[0]}", "dropped=#{dropped}",
              "windows=#{windows.join(",")}", "kind_objects=#{objects.join(",")}",
              "pid=#{Process.pid}", "root=#{root || Dir.pwd}", "app_root=#{APP_ROOT || Dir.pwd}",
              "ruby=#{RUBY_DESCRIPTION}",
              "rails_env=#{ENV["RAILS_ENV"]}", "rails=#{Lowrail.loaded_constant("Rails::VERSION::STRING")}"].join("\t")]
            # Each path once, as a "P id path" row before its first use: paths
            # were four fifths of an attribution run's bytes.
            ids = {}
            id = lambda do |path|
              next "-" unless path
              ids.fetch(path) { lines << "P\t#{ids.size}\t#{path}"; ids[path] = ids.size.to_s }
            end
            rows.each do |path, line, type, count, reached, first, via, kind|
              lines << [id.(path), line, TYPES[type], count, reached, first, via ? 1 : 0, KINDS[kind]].join("\t")
            end
            actions.each { |kind, name, *rest| lines << ["A", KINDS[kind], name || "-", *rest].join("\t") }
            attributed.each do |kind, name, path, line, caller_path, caller_line, count, first|
              lines << ["@", KINDS[kind], name || "-", id.(path), line || "-", id.(caller_path), caller_line || "-", count, first].join("\t")
            end
            # Gems from a path (Bundler's path:, gemspec), which no gem
            # directory names: the report classifies their lines by these.
            Gem.loaded_specs.each_value do |spec|
              gem_dir = spec.full_gem_path
              lines << ["G", spec.name, gem_dir].join("\t") unless gem_dir.match?(%r{/(?:gems|bundler/gems)/[^/]+-(?:\d|\h{12})[^/]*\z})
            end
            File.write(File.join(dir, "#{Process.pid}.tsv"), lines.join("\n") << "\n")
            if shapes&.any?
              # At exit Bundler has long set up, so json resolves to the app's own.
              require "json"
              File.write(File.join(dir, "#{Process.pid}.shapes.json"), JSON.generate(shapes.values))
            end
          rescue StandardError => error
            warn "[lowrail-profile] not written: #{error.class}: #{error.message}"
          end
        end
      end
    end

    # The repeat run records the nearest app frame of every allocation.
    if ENV["LOWRAIL_PROFILE_ATTRIBUTE"] == "1"
      Lowrail::Profile.attribute(File.join(ENV.fetch("LOWRAIL_PROFILE_ROOT", Dir.pwd), ""))
    end
    Lowrail::Profile.shapes = {} if ENV["LOWRAIL_PROFILE_RECORD"] == "1"
    Lowrail::Profile.start
    Lowrail::LoadHooks.active_support do
      ActiveSupport.on_load(:before_configuration) do
        Lowrail::Profile.install("Rails::Engine#call") do
          Rails::Engine.prepend(Lowrail::Profile::Window) unless Rails::Engine < Lowrail::Profile::Window
        end
      end
      # RSpec read SPEC_OPTS when its runner started, before the suite boots
      # the app; a rake parent that boots it to start the suite has no runner.
      ActiveSupport.on_load(:before_configuration) do
        Lowrail::Profile.leave_env if Lowrail.loaded_constant("RSpec::Core::Runner")
      end
      ActiveSupport.on_load(:active_support_test_case) do
        Lowrail::Profile.install("Minitest") do
          if Minitest.respond_to?(:register_plugin)
            Minitest.register_plugin(Lowrail::Profile::Suite)
          else
            Minitest.singleton_class.prepend(Lowrail::Profile::Suite)
          end
        end
      end
      # Each hook runs when the app loads the class; the modules they prepend
      # into (Metal, Base) are already loaded by then.
      ActiveSupport.on_load(:action_controller) do
        Lowrail::Profile.install("ActionController::Metal#dispatch") do
          metal = ActionController::Metal
          metal.prepend(Lowrail::Profile::Dispatch) unless metal < Lowrail::Profile::Dispatch
        end
      end
      ActiveSupport.on_load(:active_job) do
        Lowrail::Profile.install("Active Job") do
          prepend(Lowrail::Profile::Job) unless self < Lowrail::Profile::Job
          singleton_class.prepend(Lowrail::Profile::JobExecute) unless singleton_class < Lowrail::Profile::JobExecute
        end
      end
      ActiveSupport.on_load(:action_mailer) do
        Lowrail::Profile.install("Action Mailer") do
          prepend(Lowrail::Profile::MailBuild) unless self < Lowrail::Profile::MailBuild
          singleton_class.prepend(Lowrail::Profile::MailDelivery) unless singleton_class < Lowrail::Profile::MailDelivery
        end
      end
      ActiveSupport.on_load(:action_cable_channel) do
        Lowrail::Profile.install("Action Cable") do
          prepend(Lowrail::Profile::Cable) unless self < Lowrail::Profile::Cable
        end
      end
    end
    Process.singleton_class.prepend(Lowrail::Profile::Fork)
    at_exit { Lowrail::Profile.write(dir) }
  rescue StandardError, ScriptError => error
    warn "[lowrail-profile] off: #{error.class}: #{error.message}"
  end
end
