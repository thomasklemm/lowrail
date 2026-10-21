# frozen_string_literal: true

# Separate untimed controls; these are NOT Fizzy sites or production authority.
# Each invocation is a new process with its own original witness. Both arms
# render this labelled template normally on a naturally used production view.
require_relative "fizzy_link_vector"

module BlockLinkControls
  TEMPLATE = File.expand_path("fixtures/block_link.html.erb", __dir__).freeze
  SITE = {"file" => TEMPLATE, "line" => 2}.freeze
  MODES = %w[normal nil whitespace unsafe safe nested next raise throw break return builder singleton buffer foreign streaming url_error].freeze

  class << self
    def observe(view)
      return unless @acquiring && !@view
      controller = BlockLinkSpecimen.ivar(view, :@_controller)
      @view = view if BlockLinkSpecimen.klass(controller).name == "BucketsController"
    end

    def invoke(template, view, mode)
      log, observations = [], {}
      target = "/target?x=1&y=2"
      if mode == "url_error"
        target = Object.new
        target.define_singleton_method(:to_model) { log << "url"; raise "URL failure" }
      end
      outcome = catch(:bench_exit) do
        result = template.render(view, {mode: mode, log: log, observations: observations, target: target})
        {"result" => BlockLinkSpecimen.exact(result, ActionView::StreamingBuffer) ? {"streaming" => true} : BlogProduction.value(result)}
      end
      outcome = {"throw" => outcome} unless Hash === outcome
      outcome.merge("log" => log, "before" => observations[:before]&.raw_buffer,
        "link_result" => BlogProduction.value(observations[:link_result]),
        "old_after_link" => observations[:old_after_link], "replacement_after_link" => observations[:replacement_after_link],
        "replacement" => observations[:replacement]&.raw_buffer,
        "builder_replaced" => observations[:saved] && !observations[:saved].equal?(BlockLinkSpecimen.ivar(view, :@tag_builder)))
    rescue StandardError => error
      error = error.cause while error.cause
      {"error" => error.class.name, "message" => error.message, "log" => log,
        "before" => observations[:before]&.raw_buffer}
    end

    def checks(ledgers, arm, mode)
      site = SITE.values.join(":")
      counts = ledgers.map { _1.fetch("specimen").fetch("counts").fetch(site, {}) }
      outcome = ledgers.last.fetch("outcome")
      unwind = %w[raise throw break return url_error].include?(mode)
      fallback = %w[foreign singleton streaming].include?(mode)
      checks = {
        "completed_first_original" => counts.first["original_completed"] == 1 && counts.first.fetch("hits", 0).zero?,
        "exercised_fast_prelude" => arm == "off" || counts[1]["hits"] == 1,
        "block_exactly_once" => outcome.fetch("log").count("block") == (mode == "url_error" ? 0 : 1),
        "completed_hit_delta" => counts.last.fetch("hits", 0) - counts[1].fetch("hits", 0) == (arm == "on" && !unwind && !fallback ? 1 : 0),
        "unwind_not_completed" => !unwind || counts.last["original_completed"] == counts[1]["original_completed"]
      }
      anchor = '<a class="literal" href="/target?x=1&amp;y=2">'
      content = {"nil" => "", "buffer" => "", "whitespace" => " \t", "unsafe" => "unsafe&lt;&amp;",
        "safe" => "safe<&", "next" => "next&lt;&amp;", "nested" => "nested<&"}.fetch(mode, "héllo<&")
      expected = mode == "singleton" ? "new saved receiver" : mode == "break" ? "broken" : "#{anchor}#{content}</a>"
      unless %w[raise throw return url_error].include?(mode)
        encoded = outcome["link_result"]
        checks["exact_link_result"] = encoded && encoded["base64"] && Base64.strict_decode64(encoded["base64"]) == expected
      end
      checks["new_saved_method_once"] = outcome["log"] == ["block", "new saved method"] if mode == "singleton"
      checks["old_buffer_restored"] = outcome["old_after_link"] == "old" && outcome["replacement_after_link"] == "new+block" if mode == "buffer"
      checks["actual_streaming_fallback"] = outcome.dig("result", "streaming") == true && outcome["log"].include?(["stream", expected]) if mode == "streaming"
      checks["URL_before_block"] = outcome.values_at("message", "log") == ["URL failure", ["url"]] if mode == "url_error"
      checks
    end

    def run(app, state, artifact, contexts, arm, mode, destination, discover: false)
      raise "unknown control" unless MODES.include?(mode)
      pin = FizzyLinkVector.pin!
      pin["control_template_sha256"] = Digest::SHA256.file(TEMPLATE).hexdigest
      FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      require File.join(app, "config/boot")
      BlockLinkSpecimen.install(app: app, artifact: artifact, contexts: contexts,
        arm: arm, discover: discover, control_sites: [SITE])
      FizzyLinkFixture.boot(app)
      BlockLinkSpecimen.dependencies!
      driver = FizzyLinkVector::Driver.new(state, record: false)
      @acquiring = true
      begin
        driver.login
        raise "natural buckets request failed" unless driver.request("GET", "/buckets").status == 200
      ensure
        @acquiring = false
      end
      view, @view = @view, nil # Only this external harness holds the view.
      raise "no naturally used buckets view" unless view
      # This is an ordinary labelled bench template render, not a compiler,
      # resolver or view/container construction probe. Its context is separate.
      template = ActionView::Template.new(File.binread(TEMPLATE), TEMPLATE,
        ActionView::Template.registered_template_handler(:erb),
        locals: %w[mode log observations target], format: :html)
      ledgers = []
      %w[normal normal].each do |normal|
        outcome = invoke(template, view, normal)
        ledgers << {"outcome" => outcome, "specimen" => JSON.parse(JSON.generate(BlockLinkSpecimen.report))}
      end
      outcome = invoke(template, view, mode)
      ledgers << {"outcome" => outcome, "specimen" => JSON.parse(JSON.generate(BlockLinkSpecimen.report))}
      data = {"pins" => pin, "arm" => arm, "mode" => mode, "site" => SITE,
        "ledgers" => ledgers, "specimen" => BlockLinkSpecimen.report,
        "checks" => discover ? nil : checks(ledgers, arm, mode),
        "qualification" => "separate control context; not Fizzy coverage or a completed HTTP equivalence gate"}
      File.write(destination, JSON.pretty_generate(data), perm: 0o600)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  operation, app, state, artifact, contexts, arm, mode, destination = ARGV
  abort "usage: block_link_controls.rb discover|gate APP STATE ARTIFACT CONTEXTS_JSON off|on MODE DESTINATION" unless %w[discover gate].include?(operation) && destination
  BlockLinkControls.run(*[app, state, artifact].map { File.realpath(_1) },
    JSON.parse(File.read(contexts)), arm, mode, destination, discover: operation == "discover")
end
