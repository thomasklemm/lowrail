# frozen_string_literal: true

# In-app allocation profile (docs/profile.md). Loaded only by exe/lowrail-profile,
# through RUBYOPT, when LOWRAIL_PROFILE names an output directory; nothing in
# Lowrail requires it otherwise, so an app with the gem but without the
# variable runs unchanged.
#
# Counts objects per source line inside Rails::Engine#call (every request the
# app serves: integration and system tests, a local server, a path list) and
# writes one TSV per process at exit. It never forces a load: the window is
# installed from ActiveSupport's before_configuration hook, when the app's
# Application class is defined. Like the rest of setup, it requires no default
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

        module Window
          def call(env)
            Profile.enter
            super
          ensure
            Profile.leave
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
          def write(dir)
            requests, objects, dropped, rows = snapshot
            return if requests == 0
            root = (Rails.root.to_s if defined?(Rails) && Rails.respond_to?(:root) && Rails.root)
            lines = [["# lowrail-profile 1", "requests=#{requests}", "objects=#{objects}", "dropped=#{dropped}",
              "pid=#{Process.pid}", "root=#{root || Dir.pwd}", "ruby=#{RUBY_DESCRIPTION}",
              "rails_env=#{ENV["RAILS_ENV"]}"].join("\t")]
            rows.each do |path, line, type, count, reached, first, via|
              lines << [path || "-", line, TYPES[type], count, reached, first, via ? 1 : 0].join("\t")
            end
            callers.each { |row| lines << ["@", *row.map { _1 || "-" }].join("\t") }
            File.write(File.join(dir, "#{Process.pid}.tsv"), lines.join("\n") << "\n")
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
    end
    # Lines to attribute to their nearest app frame (lowrail-profile passes the
    # first run's top lines to the next run).
    if (watch = ENV["LOWRAIL_PROFILE_WATCH"]) && File.exist?(watch)
      list = File.readlines(watch, chomp: true).map { |row| path, line = row.split("\t"); [path, Integer(line)] }
      Lowrail::Profile.watch(list, File.join(ENV.fetch("LOWRAIL_PROFILE_ROOT", Dir.pwd), ""))
    end
    Process.singleton_class.prepend(Lowrail::Profile::Fork)
    at_exit { Lowrail::Profile.write(dir) }
    Lowrail::Profile.start
  rescue StandardError, ScriptError => error
    warn "[lowrail-profile] off: #{error.class}: #{error.message}"
  end
end
