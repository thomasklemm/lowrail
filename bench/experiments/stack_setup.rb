# frozen_string_literal: true

# External screen adapter only. Never installed by Lowrail or an app. All
# controls are inactive outside the login/untimed validation contexts; the
# measured request retains native clocks/randomness, GC and public guards.
require_relative "../../fixtures/corpus/blog_production"

module NativeBench
  module Exploration
    module_function

    def install(config:, state:, arm:)
      @config, @state = config, state
      if config.fetch("workload") == "lobsters"
        require_relative "lobsters_native_validation"
        LobstersNativeValidation.install(config.fetch("app"))
        return
      end
      policy = case config.fetch("workload")
      when "blog"
        JSON.parse(File.read(BlogProduction::Entropy::POLICY))
      when "campfire"
        require_relative "campfire_room_companion"
        SecureRandom.singleton_class.prepend(CampfireRoomCompanion::SessionRandom)
        JSON.parse(File.read(CampfireRoomCompanion::POLICY))
      when "fizzy"
        JSON.parse(File.read(File.join(ROOT, "docs/fizzy-link-gates.json")))
          .fetch("entropy_policy")
      end
      control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
      raise control.fetch("reason") unless control.fetch("active")
      BlogProduction::Entropy.install(policy)
      NativeBench.singleton_class.prepend(LoginInputs) if %w[campfire fizzy].include?(config.fetch("workload"))
    end

    # The existing drivers perform natural GET/POST login, then (Campfire)
    # one GET for its POST token. The context ends before warmup/timing.
    module LoginInputs
      def routes(config, state, arm)
        requests = config.fetch("workload") == "campfire" ? 3 : 2
        result, evidence = BlogProduction::Entropy.with(0, "stack-login", requests: requests, wall_clock: true) { super }
        raise "login input control refused: #{evidence.fetch('errors')}" unless evidence.fetch("errors").empty?
        result
      end
    end

    def validation_request(route:, seed:, request:)
      before = database_digest
      response, evidence = if @config.fetch("workload") == "lobsters"
        response, controls = LobstersNativeValidation.validation_request(route: route, seed: seed, request: request)
        [response, controls.fetch("entropy")]
      else
        BlogProduction::Entropy.with(seed, "stack/#{route}", wall_clock: true, &request)
      end
      after = database_digest
      [response, {"passed" => evidence.fetch("errors").empty? && before == after,
        "control" => "pinned stock entropy inputs, untimed only",
        "errors" => evidence.fetch("errors"), "db_unchanged" => before && before == after,
        "db_gate" => before ? "GET unchanged locally; compare cross-arm digests separately" : "not covered",
        "db_sha256" => after, "entropy_trace" => evidence.fetch("trace")}]
    end

    def database_digest
      if @config.fetch("workload") == "blog"
        Digest::SHA256.hexdigest(JSON.generate(BlogProduction.effects))
      elsif @config.fetch("workload") == "lobsters"
        require "sqlite3"
        db = SQLite3::Database.new(File.join(@state, "primary.sqlite3"), readonly: true)
        begin
          rows = db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").to_h do |(name)|
            table = '"' + name.gsub('"', '""') + '"'
            [name, db.execute2("SELECT * FROM #{table} ORDER BY rowid")]
          end
          Digest::SHA256.hexdigest(Marshal.dump(rows))
        ensure
          db.close
        end
      else
        # These apps can update session/cache/queue state during a GET.
        # Their complete cold-state/completion gates remain separate and red;
        # never claim that a successful response screen closes those gaps.
        nil
      end
    end
  end
end
