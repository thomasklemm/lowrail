# frozen_string_literal: true

# In-app allocation profile (docs/profile.md). Loaded only by exe/lowrail-profile,
# through RUBYOPT, when LOWRAIL_PROFILE names an output directory; nothing in
# Lowrail requires it otherwise, so an app with the gem but without the
# variable runs unchanged.
#
# Counts objects per source line inside windows: Rails::Engine#call (every
# request the app serves: integration and system tests, a local server, a path
# list), Active Job's perform_now, a mail's build and delivery, and Action Cable
# channel actions. Each window is named by its controller action, job, mailer
# action or channel action. Writes one TSV per process at exit. It never forces
# a load: every hook is installed from Active Support's on_load hooks, when the
# framework class is defined. Like the rest of setup, it requires no default
# gems, so Bundler's activation is unchanged. Any failure leaves the app as is.
if (dir = ENV["LOWRAIL_PROFILE"]) && !dir.empty?
  begin
    require ENV.fetch("LOWRAIL_PROFILE_EXT")
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
        SUBSCRIBED = "subscribed"
        DELIVER = "deliver_mail"
        ACTION = "action"

        module Window
          def call(env)
            Profile.enter(0)
            super
          ensure
            Profile.leave
            Profile.note(env) if Profile.shapes
          end
        end

        # Names the request after the first controller action it dispatches.
        module Dispatch
          def dispatch(name, request, response)
            Profile.label(self.class, HASH, name)
            super
          end
        end

        module Job
          def perform_now
            Profile.enter(1)
            Profile.label(self.class, HASH, PERFORM)
            super
          ensure
            Profile.leave
          end
        end

        # A worker deserializes the job's arguments before perform_now.
        module JobExecute
          def execute(...)
            Profile.enter(1)
            super
          ensure
            Profile.leave
          end
        end

        # A mail's build (the mailer action and its templates) and its
        # delivery are separate windows, as the app runs them.
        module MailBuild
          def process(method_name, ...)
            Profile.enter(2)
            Profile.label(self.class, HASH, method_name)
            super(method_name, ...)
          ensure
            Profile.leave
          end
        end

        module MailDelivery
          def deliver_mail(...)
            Profile.enter(2)
            Profile.label(self, DOT, DELIVER)
            super
          ensure
            Profile.leave
          end
        end

        module Cable
          def perform_action(data)
            Profile.enter(3)
            Profile.label(self.class, HASH, (data[ACTION] if data.is_a?(Hash)) || "perform_action")
            super
          ensure
            Profile.leave
          end

          def subscribe_to_channel
            Profile.enter(3)
            Profile.label(self.class, HASH, SUBSCRIBED)
            super
          ensure
            Profile.leave
            Profile.note(env) if Profile.shapes
          end
        end

        # A forked worker (parallel tests, a preforking server) starts from
        # zero, so the parent's requests are not counted twice.
        module Fork
          def _fork
            pid = super
            Profile.reset if pid == 0
            pid
          end
        end

        class << self
          # lowrail-profile --record: request shapes by route, noted after the
          # window closes, so they are not counted.
          attr_accessor :shapes

          def note(env)
            return if env["lowrail.profile.noted"] || !(route = env["action_dispatch.route"])
            env["lowrail.profile.noted"] = true
            json = [env["CONTENT_TYPE"], env["HTTP_ACCEPT"]].any? { _1.to_s.start_with?("application/json") }
            xhr = env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
            verb = (env["rack.methodoverride.original_method"] && env["REQUEST_METHOD"] || env["REQUEST_METHOD"]).downcase
            shape = shapes[[verb, route.path.spec.to_s, json, xhr]] ||= begin
              controller = route.defaults[:controller].to_s
              parts = route.required_parts.map do |part|
                model = part == :id ? controller.split("/").last.to_s.singularize.camelize : part.to_s.delete_suffix("_id").camelize if part == :id || part.to_s.end_with?("_id")
                [part.to_s, (model unless model.to_s.empty?)]
              end
              params = (env["action_dispatch.request.request_parameters"] || {}).except("authenticity_token") unless verb == "get"
              # Only a path's first route is named (PATCH and DELETE share GET's helper).
              spec = route.path.spec.to_s
              name = route.name || env["action_dispatch.routes"]&.routes&.find { _1.name && _1.path.spec.to_s == spec }&.name
              { "verb" => verb, "template" => spec.sub(/\(\.:format\)\z/, ""), "route" => name, "parts" => parts,
                "format" => env.dig("action_dispatch.request.path_parameters", :format), "json" => json, "xhr" => xhr,
                "path" => env["ORIGINAL_FULLPATH"], "params" => plain(params), "count" => 0 }
            end
            shape["count"] += 1
          rescue StandardError
            nil
          end

          def plain(value)
            case value
            when Hash then value.to_h { [_1.to_s, plain(_2)] }
            when Array then value.first(5).map { plain(_1) }
            when String, Integer, Float, true, false, nil then value.is_a?(String) ? value[0, 200] : value
            else "(#{value.class})"
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

    Lowrail::LoadHooks.active_support do
      ActiveSupport.on_load(:before_configuration) do
        Rails::Engine.prepend(Lowrail::Profile::Window) unless Rails::Engine < Lowrail::Profile::Window
      end
      # Each hook runs when the app loads the class; the modules they prepend
      # into (Metal, Base) are already loaded by then.
      ActiveSupport.on_load(:action_controller) do
        metal = ActionController::Metal
        metal.prepend(Lowrail::Profile::Dispatch) unless metal < Lowrail::Profile::Dispatch
      end
      ActiveSupport.on_load(:active_job) do
        prepend(Lowrail::Profile::Job) unless self < Lowrail::Profile::Job
        singleton_class.prepend(Lowrail::Profile::JobExecute) unless singleton_class < Lowrail::Profile::JobExecute
      end
      ActiveSupport.on_load(:action_mailer) do
        prepend(Lowrail::Profile::MailBuild) unless self < Lowrail::Profile::MailBuild
        singleton_class.prepend(Lowrail::Profile::MailDelivery) unless singleton_class < Lowrail::Profile::MailDelivery
      end
      ActiveSupport.on_load(:action_cable_channel) do
        prepend(Lowrail::Profile::Cable) unless self < Lowrail::Profile::Cable
      end
    end
    # The repeat run records the nearest app frame of every allocation.
    if ENV["LOWRAIL_PROFILE_ATTRIBUTE"] == "1"
      Lowrail::Profile.attribute(File.join(ENV.fetch("LOWRAIL_PROFILE_ROOT", Dir.pwd), ""))
    end
    Lowrail::Profile.shapes = {} if ENV["LOWRAIL_PROFILE_RECORD"] == "1"
    Process.singleton_class.prepend(Lowrail::Profile::Fork)
    at_exit { Lowrail::Profile.write(dir) }
    Lowrail::Profile.start
  rescue StandardError, ScriptError => error
    warn "[lowrail-profile] off: #{error.class}: #{error.message}"
  end
end
