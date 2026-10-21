# frozen_string_literal: true

# DELIBERATELY UNSAFE. Only script/screen's explicit four-arm exploration may
# install this. Nothing under gem/ requires it or reads the opt-in variable.
raise "guard ceiling is an exploration hook, not a runtime preload" unless defined?(NativeBench::SCRIPT)
require_relative "../../fixtures/corpus/blog_production"
require_relative "campfire_room_companion"

module NativeBench::Exploration
  class << self
    def install(config:, state:, arm:)
      raise "guard ceiling requires the explicit four-arm screen" unless config["screen"] && config["explore_unguarded"] &&
        NativeBench.arms(config).include?(arm)
      raise "unsafe opt-in/arm mismatch" unless (ENV["LOWRAIL_EXPLORE_UNGUARDED"] == "1") == (arm == "unguarded")
      @config, @state, @arm = config, state, arm
      if config.fetch("workload") == "lobsters"
        require_relative "lobsters_native_validation"
        require_relative "lobsters_url_program"
        LobstersNativeValidation.install(config.fetch("app"))
        workload = NativeBench.routes(config, state, arm)
        LobstersUrlProgram.discover do
          workload.each_value { raise "discovery HTTP failure" unless _1.call.status == 200 }
        end
        LobstersUrlProgram.compile(coverage: !ENV["LOWRAIL_STATS"].nil?, guarded: true)
        raise "no naturally observed fixed URL programs" if LobstersUrlProgram.programs.empty?
        LobstersUrlProgram.select(%w[on unguarded].include?(arm))
        return
      end
      policy = case config.fetch("workload")
      when "blog" then JSON.parse(File.read(BlogProduction::Entropy::POLICY))
      when "campfire" then JSON.parse(File.read(CampfireRoomCompanion::POLICY))
      when "fizzy" then config.fetch("entropy_policy")
      else raise "unsupported guard-ceiling specimen"
      end
      @control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
      raise @control.fetch("reason") unless @control.fetch("active")
      BlogProduction::Entropy.install(policy)
      SecureRandom.singleton_class.prepend(CampfireRoomCompanion::SessionRandom) if config.fetch("workload") == "campfire"
      # Login gets the existing companion inputs in ALL arms, never during
      # timing. Ordinary request construction/body consumption stays unchanged.
      case config.fetch("workload")
      when "campfire"
        CampfireScenario::Driver.prepend(LoginCompanion)
      when "fizzy"
        FizzyLinkVector::Driver.prepend(LoginCompanion)
      end
    end

    def validation_request(route:, seed:, request:)
      return LobstersNativeValidation.validation_request(route: route, seed: seed, request: request) if @config.fetch("workload") == "lobsters"
      response, trace = BlogProduction::Entropy.with(seed, "guard-ceiling/#{route}", wall_clock: true) { request.call }
      [response, {"passed" => trace.fetch("errors").empty?, "control" => @control, "entropy" => trace}]
    end

    def warmup_complete
      return unless @arm == "unguarded"
      case @config.fetch("workload")
      when "blog"
        [Lowrail::FormScaffold, Lowrail::TokenTag, Lowrail::CollectionRender].each do |unit|
          raise "natural admission missing: #{unit}: #{unit.refusal}" unless unit.admitted?
        end
        Lowrail::FormScaffold.singleton_class.prepend(FormChecks)
        Lowrail::TokenTag.singleton_class.prepend(TokenChecks)
        Lowrail::CollectionRender.singleton_class.prepend(CollectionChecks)
        Lowrail::ARInstantiate::Entry.prepend(RowChecks)
      when "campfire"
        Lowrail::ARInstantiate::Entry.prepend(RowChecks)
      when "fizzy"
        raise "no naturally admitted link contexts" unless BlockLinkSpecimen.contexts.values.any? { _1[:state] == "active" }
        BlockLinkSpecimen.singleton_class.prepend(@config["guard_scope"] == "suffix" ? SuffixChecks : LinkChecks)
      when "lobsters"
        LobstersUrlGuard::Certificate.prepend(UrlChecks)
      end
    end

    def counts
      return LobstersUrlProgram.counts if @config.fetch("workload") == "lobsters"
      return BlockLinkSpecimen.counts if @config.fetch("workload") == "fizzy"
      if Lowrail::Stats.enabled?
        {"hits" => Lowrail::Stats.unit_hits.dup, "fallbacks" => Lowrail::Stats.unit_fallbacks.dup}
      end
    end
  end

  module LoginCompanion
    def login
      result, trace = BlogProduction::Entropy.with(0, "guard-ceiling/login", requests: 2, wall_clock: true) { super }
      raise "login entropy rejected: #{trace.fetch('errors')}" unless trace.fetch("errors").empty?
      result
    end
  end

  module RowChecks
    def valid? = true
    def current? = true
  end

  module UrlChecks
    def valid?(_target, _name) = true
  end

  module FormChecks
    def valid?(_view, _model, _scope, _url, _format, _options, _block) = count(true)
  end

  module CollectionChecks
    def valid?(_renderer, _view, _template, _layout) = count(true)
  end

  module TokenChecks
    def valid?(_view, _token, _options) = true

    # Same live token/name generation, escaping, ordering and output as
    # TokenTag.render; only its post-live epoch/holder/fallback branch is gone.
    def render(view, options)
      unit = self
      Lowrail::Sealed::VIEW_CONTEXT.bind_call(view) do
        unless defined?(protect_against_forgery?) && protect_against_forgery?
          unit.count(true)
          next ""
        end
        value = form_authenticity_token(form_options: options.merge(authenticity_token: nil))
        name = request_forgery_protection_token.to_s
        remove_autocomplete = ActionView::Base.remove_hidden_field_autocomplete
        unit.count(true)
        autocomplete = remove_autocomplete ? "" : ' autocomplete="off"'
        name = ERB::Util.unwrapped_html_escape(name)
        name = name.gsub('"', "&quot;") if name.include?('"')
        value = ERB::Util.unwrapped_html_escape(value)
        value = value.gsub('"', "&quot;") if value.include?('"')
        %(<input type="hidden" name="#{name}" value="#{value}"#{autocomplete} />).html_safe
      end
    end
  end

  module LinkChecks
    # Keep finite site selection and the invocation stack/counters, but remove
    # template/compiler/ISeq digests, holder/witness/constructor/buffer checks.
    # URL conversion, original block/capture and specialized suffix stay live.
    def template_source(*) = nil
    def template_enter(*) = nil
    def template_leave(*) = nil
    def constructor?(*) = true
    def builder_created(*) = nil
    def capture_begin(*) = Thread.current[BlockLinkSpecimen::THREAD_LINK]
    def capture_receiver(_view, receiver) = receiver
    def buffer_enter(*) = nil
    def buffer_leave(*) = nil
    def capture_end(*) = nil

    def link_enter(view, block, _name, options, html)
      call = {previous: Thread.current[BlockLinkSpecimen::THREAD_LINK], completed: false, fast: false}
      Thread.current[BlockLinkSpecimen::THREAD_LINK] = call
      if block && html.nil? && (sequence = RubyVM::InstructionSequence.of(block)) &&
          (site = @catalog[[sequence.path, sequence.first_lineno]])
        call[:site] = "#{site.fetch('file')}:#{site.fetch('line')}"
        count(call, "entries")
      end
      call
    end

    def fast?(call, *) = !!call&.fetch(:site, nil)
  end

  # Separately labelled causal control: leave the common observer/selector
  # work in ALL arms, bypass only the on-only post-capture predicate. The broad
  # ceiling above also removes common work and cannot price this scan alone.
  module SuffixChecks
    def predicate(_call, _builder, _content, _options, _escape) = nil
  end
end
