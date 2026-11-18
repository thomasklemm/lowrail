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
        # Accept values a workloads file sends anyway (html, IntegrationTest's, xhr:, as: :json).
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
          # lowrail-profile --record: request shapes by route, noted after the
          # window closes, so they are not counted.
          attr_accessor :shapes

          # Each returns quietly when the profiler cannot do its part.
          def open(kind)
            Ractor.main? && enter(kind)
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
            label(klass, separator, action) if Ractor.main?
          rescue StandardError
            nil
          end

          def cable_named(klass, data)
            label(klass, HASH, (data[ACTION] if Hash === data) || PERFORM_ACTION) if Ractor.main?
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

          def note(env)
            return if env[NOTED] || !(route = env["action_dispatch.route"])
            env[NOTED] = true
            path_params = env["action_dispatch.request.path_parameters"] || {}
            format = path_params[:format]&.to_s
            accept = env["HTTP_ACCEPT"].to_s
            first = accept[/\A[^,;]*/].strip.downcase
            accept = nil if first.empty? || PLAIN_ACCEPT.include?(first)
            json = [env["CONTENT_TYPE"], env["HTTP_ACCEPT"]].any? { _1.to_s.start_with?(JSON_TYPE) }
            xhr = env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
            verb = env["REQUEST_METHOD"].to_s.downcase
            spec = route.path.spec.to_s
            shape = shapes[[verb, spec, json, xhr, format, accept]] ||=
              shape_of(env, route, verb, spec, path_params, format: format, json: json, xhr: xhr, accept: accept)
            shape["count"] += 1
          rescue StandardError
            nil
          end

          # What a workloads file needs to send the request again, with the
          # app's filter_parameters applied before anything is kept. Params
          # are kept only if they could be filtered; nothing is taken from the
          # raw path or query string.
          def shape_of(env, route, verb, spec, path_params, **flags)
            lossy = [false]
            controller = route.defaults[:controller].to_s
            required = route.required_parts.map(&:to_s)
            parts = required.map do |part|
              base = part == "id" ? controller.split("/").last.to_s : part.delete_suffix("_id") if part == "id" || part.end_with?("_id")
              model = base.singularize.camelize if base && !base.empty?
              [part, (model if model && record_class?(model))]
            end
            lossy[0] = true if (path_params.keys.map(&:to_s) - %w[controller action format] - required - route.defaults.keys.map(&:to_s)).any?
            query = env["QUERY_STRING"].to_s
            params = if verb == "get"
              query.empty? ? {} : env["action_dispatch.request.query_parameters"] || (lossy[0] = true; {})
            else
              lossy[0] = true unless query.empty?
              env["action_dispatch.request.request_parameters"] || (env["CONTENT_LENGTH"].to_i > 0 ? (lossy[0] = true; {}) : {})
            end
            if (filter = parameter_filter(env))
              params = plain(filter.filter(params.except("authenticity_token")), lossy)
              seen = plain(filter.filter(path_params.transform_keys(&:to_s).slice(*required)), lossy)
            end
            name = route.name || env["action_dispatch.routes"]&.routes&.find { _1.name && _1.path.spec.to_s == spec }&.name
            { "verb" => verb, "template" => spec.sub(/\(\.:format\)\z/, ""), "route" => name, "parts" => parts,
              "seen" => seen, **flags.transform_keys(&:to_s), "params" => params, "unfiltered" => !filter,
              "filtered" => filtered?(params) || filtered?(seen), "lossy" => lossy[0], "count" => 0 }
          end

          def parameter_filter(env)
            klass = Lowrail.loaded_constant("ActiveSupport::ParameterFilter") or return
            filters = env["action_dispatch.parameter_filter"] || []
            @filter = nil unless @filter_source.equal?(filters)
            @filter_source = filters
            @filter ||= klass.new(filters, mask: FILTERED)
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
              else value
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
            lines = [["# lowrail-profile 2", "requests=#{windows[0]}", "objects=#{objects[0]}", "dropped=#{dropped}",
              "windows=#{windows.join(",")}", "kind_objects=#{objects.join(",")}",
              "pid=#{Process.pid}", "root=#{root || Dir.pwd}", "ruby=#{RUBY_DESCRIPTION}",
              "rails_env=#{ENV["RAILS_ENV"]}"].join("\t")]
            rows.each do |path, line, type, count, reached, first, via, kind|
              lines << [path || "-", line, TYPES[type], count, reached, first, via ? 1 : 0, KINDS[kind]].join("\t")
            end
            actions.each { |kind, name, *rest| lines << ["A", KINDS[kind], name || "-", *rest].join("\t") }
            attributed.each { |kind, name, *rest| lines << ["@", KINDS[kind], name || "-", *rest.map { _1 || "-" }].join("\t") }
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
