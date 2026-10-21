# frozen_string_literal: true

# BENCH ONLY. No registration, production admission or binding/purity claim.
require_relative "block_link_delivery"
require_relative "../../gem/lib/lowrail/sealed"
require_relative "../../gem/lib/lowrail/form_scaffold_admission"

module BlockLinkSpecimen
  IVAR = Object.instance_method(:instance_variable_get)
  CLASS = Object.instance_method(:class)
  METHOD = Object.instance_method(:method)
  FETCH = Hash.instance_method(:fetch)
  KEYS = Hash.instance_method(:keys)
  EPOCH = [0]
  BUILDERS = ObjectSpace::WeakKeyMap.new
  VIEWS = ObjectSpace::WeakKeyMap.new
  THREAD_TEMPLATE = :__bench_block_link_template
  THREAD_LINK = :__bench_block_link_call

  class << self
    attr_reader :contexts, :counts, :discovered

    def install(app:, artifact:, contexts:, arm:, discover: false)
      @app, @artifact, @arm, @discover = app, artifact, arm, discover
      @manifest = contexts.to_h { |entry| [entry.fetch("key"), entry] }.freeze
      @contexts = @manifest.to_h { |key, _| [key, {state: "pending", lock: Mutex.new, attempts: 0}] }
      @counts, @discovered = {}, {}
      @catalog = JSON.parse(File.read(File.expand_path("../../docs/helper-census.json", __dir__))).fetch("apps").fetch("fizzy").fetch("sites").select do |site|
        site["helper"] == "link_to" && site["receiver"] == "bare" && site["block"] &&
          site["file"].start_with?("app/views/") && site["file"].end_with?(".html.erb") &&
          site.dig("options", "keys") == ["class"] && site.dig("options", "values") == "literal"
      end.to_h { |site| [[File.join(app, site.fetch("file")), site.fetch("line")], site] }
      raise "23 finite sites required" unless @catalog.size == 23
      ENV["LOWRAIL"] = "1" # Same source-only bench delivery in ALL arms.
      raise "cold bench delivery setup refused: #{Lowrail.refusal_reason}" unless Lowrail.setup(root: app, dir: artifact)
    end

    def ivar(value, key) = IVAR.bind_call(value, key)
    def klass(value) = CLASS.bind_call(value)
    def exact(value, type) = Lowrail::Native.exact_class?(value, type)
    def signature(sequence, method_name) = Lowrail::FormScaffoldAdmission.block_signature(sequence, method_name.to_s)

    def template_enter(view, method_name, template, locals, buffer, strict)
      previous = Thread.current[THREAD_TEMPLATE]
      entry = {previous: previous, view: view, reason: "not a selected template"}
      Thread.current[THREAD_TEMPLATE] = entry
      return entry unless @catalog && @catalog.keys.any? { _1.first == ivar(template, :@identifier) }
      return entry.merge!(reason: "custom template/locals/buffer") unless exact(template, ActionView::Template) && exact(locals, Hash) && exact(buffer, ActionView::OutputBuffer)
      source = ivar(template, :@source)
      path = ivar(template, :@identifier)
      compiled = METHOD.bind_call(view, method_name)
      sequence = RubyVM::InstructionSequence.of(compiled)
      controller = ivar(view, :@controller)
      controller_class = klass(controller)
      cached_view = ivar(controller_class, :@view_context_class)
      return entry.merge!(reason: "unnatural view/compiler context") unless sequence && exact(view, cached_view) &&
        ivar(template, :@compiled) && ivar(template, :@handler).equal?(ActionView::Template::Handlers::ERB) && exact(source, String)
      keys, template_locals, strict_locals = KEYS.bind_call(locals), ivar(template, :@locals), ivar(template, :@strict_locals)
      return entry.merge!(reason: "unsupported locals metadata") unless keys.all? { Symbol === _1 || exact(_1, String) } &&
        exact(template_locals, Array) && template_locals.all? { exact(_1, String) } &&
        (strict_locals.nil? || exact(strict_locals, String))
      descriptor = {"controller" => controller_class.name, "file" => path.delete_prefix(@app + "/"),
        "source_sha256" => Digest::SHA256.hexdigest(source), "source_encoding" => source.encoding.name,
        "disk_sha256" => Digest::SHA256.file(path).hexdigest,
        "template_locals" => template_locals.map(&:dup), "locals" => keys.map { Symbol === _1 ? _1.name : _1.dup },
        "strict" => strict, "strict_locals" => strict_locals&.dup,
        "compiled_body" => signature(sequence, method_name), "compile_options" => RubyVM::InstructionSequence.compile_option}
      # All instance/Proc/template references live ONLY on this invocation stack.
      entry.merge!(reason: nil, descriptor: descriptor, sequence: sequence, method_name: method_name,
        view_holder: cached_view, compiled_holder: compiled.owner, controller_holder: controller_class)
    rescue StandardError => error
      entry.merge!(reason: "entry context unavailable: #{error.class}")
    end

    def template_leave(entry)
      Thread.current[THREAD_TEMPLATE] = entry && entry[:previous]
    end

    def child?(parent, wanted)
      found = false
      parent.each_child { |child| found ||= child.equal?(wanted) || child?(child, wanted) }
      found
    end

    def link_enter(view, block, _name, options, html)
      previous = Thread.current[THREAD_LINK]
      call = {previous: previous, view: view, epoch: EPOCH[0], completed: false, fast: false}
      Thread.current[THREAD_LINK] = call
      return call unless block && html.nil? && exact(block, Proc) && exact(options, Hash) && KEYS.bind_call(options) == [:class]
      sequence = RubyVM::InstructionSequence.of(block)
      return call unless sequence && (site = @catalog[[sequence.path, sequence.first_lineno]])
      call[:site] = "#{site.fetch('file')}:#{site.fetch('line')}"
      count(call, "entries")
      entry = Thread.current[THREAD_TEMPLATE]
      return refuse(call, "unknown entry context") unless entry && entry[:view].equal?(view) && !entry[:reason] && child?(entry[:sequence], sequence)
      css = FETCH.bind_call(options, :class)
      return refuse(call, "nonliteral class value") unless exact(css, String) && css.encoding == Encoding::UTF_8 && css.valid_encoding?
      descriptor = entry[:descriptor].merge("site" => call[:site], "block" => signature(sequence, entry[:method_name]),
        "block_location" => sequence.to_a.fetch(4).fetch(:code_location), "class" => css)
      key = Digest::SHA256.hexdigest(JSON.generate(descriptor))
      call.merge!(key: key, descriptor: descriptor, entry: entry, css: css.dup.freeze)
      @discovered[key] = descriptor.merge("key" => key) if @discover
      state = @contexts[key]
      return refuse(call, "context absent from frozen manifest") unless state
      call[:state] = state
      # Never reread this choice after URL/block/nested/concurrent work.
      call[:eligible_at_entry] = @arm == "on" && state[:state] == "active"
      if state[:state] == "pending" && state[:lock].try_lock
        if state[:state] == "pending"
          state.merge!(state: "observing", attempts: 1)
          call[:witness] = true
        else
          state[:lock].unlock
        end
      end
      call
    end

    def refuse(call, reason)
      call[:reason] = reason
      call
    end

    def constructor?(builder)
      @dependencies && builder.equal?(ActionView::Helpers::TagHelper::TagBuilder) &&
        builder.method(:new) == @constructor && @constructor.source_location.nil? && @constructor.owner.equal?(Class) &&
        builder.instance_method(:initialize) == @initialize
    end

    def builder_created(view, builder, stock)
      if stock && exact(builder, ActionView::Helpers::TagHelper::TagBuilder)
        token = VIEWS[view] ||= Object.new
        BUILDERS[builder] = [klass(view), token]
      end
    end

    def capture_begin(view, builder, block, name, options, escape)
      call = Thread.current[THREAD_LINK]
      return unless call && call[:key] && call[:view].equal?(view) && name == "a" && escape == true && block &&
        !call[:capture_started]
      call.merge!(capture_started: true, builder: builder, options: options)
      call
    end

    def capture_receiver(view, receiver)
      call = Thread.current[THREAD_LINK]
      call[:buffer] = receiver if call && call[:capture_started] && !call[:buffer] && call[:view].equal?(view)
      receiver
    end

    def buffer_enter(receiver, old, fresh)
      call = Thread.current[THREAD_LINK]
      return unless call && call[:buffer].equal?(receiver) && !call[:buffer_started]
      call.merge!(buffer_started: true, old_raw: old, fresh_raw: fresh)
      call
    end

    def buffer_leave(call, receiver, old, fresh, restored)
      return unless call
      call[:restored] = call[:buffer].equal?(receiver) && call[:old_raw].equal?(old) &&
        call[:fresh_raw].equal?(fresh) && restored.equal?(old)
    end

    def capture_end(call)
      call[:capture_completed] = true if call
    end

    def dependencies!
      builder = ActionView::Helpers::TagHelper::TagBuilder
      @constructor, @initialize = builder.method(:new), builder.instance_method(:initialize)
      @dependencies = [
        [ActionView::Helpers::UrlHelper, %i[link_to convert_options_to_data_attributes url_target]],
        [ActionView::Helpers::TagHelper, %i[content_tag tag_builder ensure_valid_html5_tag_name]],
        [ActionView::Helpers::CaptureHelper, %i[capture]], [ActionView::OutputBuffer, %i[capture]],
        [builder, %i[initialize content_tag_string tag_options tag_option]],
        [String, %i[to_s empty? size == match? include? gsub encoding valid_encoding? blank? present? html_safe? html_safe]],
        [Hash, %i[each_pair empty? [] size keys default default_proc]], [Regexp, %i[match?]]
      ].flat_map { |holder, names| names.map { |name| [holder, name, holder.instance_method(name), Lowrail::Sealed.visibility(holder, name)] } }
      # Read build-time ISeq evidence. No runtime compilation, handler/resolver
      # invocation or warming is allowed to manufacture the witness.
      expected = JSON.parse(File.read(File.join(@artifact, "expected-methods.json")))
      delivered = BlockLinkDelivery::STOCK.keys.map { Gem.loaded_specs.fetch("actionview").full_gem_path + "/lib/action_view/#{_1}" }
      @dependencies.each do |_, name, method, _|
        next unless (path, line = method.source_location) && delivered.include?(path)
        digest = expected.fetch(JSON.generate([path, name.to_s, line]))
        raise "effective stock body differs: #{name}" unless digest == Lowrail::Sealed.signature(method).fetch("iseq")
      end
      raise "native holder unavailable" unless defined?(Lowrail::Native) && Lowrail::Native.method(:exact_class?).source_location.nil?
      raise "cold seams not delivered" unless delivered.all? { Lowrail::Loader.served?(_1) }
      @escaping = %i[unwrapped_html_escape xml_name_escape].map { |name| [name, ERB::Util.method(name)] }
      @dependencies
    end

    def dependencies?
      @dependencies && @dependencies.all? { |holder, name, method, visibility|
        holder.instance_method(name) == method && Lowrail::Sealed.visibility(holder, name) == visibility
      } && @escaping.all? { |name, method| ERB::Util.method(name) == method } &&
        Lowrail::Sealed.literal_state?(exact_class: Lowrail::Native.method(:exact_class?))
    end

    def predicate(call, builder, content, options, escape)
      return "seal/holder/dependency changed" unless Ractor.current.equal?(Ractor.main) && EPOCH[0] == call[:epoch] && EPOCH[0].zero? && dependencies?
      return "owner holder changed" if call[:state] && call[:state][:holders] &&
        call[:state][:holders] != call[:entry].values_at(:view_holder, :controller_holder, :compiled_holder)
      token = BUILDERS[builder]
      return "foreign saved builder" unless exact(builder, ActionView::Helpers::TagHelper::TagBuilder) && token &&
        token[0].equal?(call[:entry][:view_holder]) && token[1].equal?(VIEWS[call[:view]]) &&
        ivar(builder, :@view_context).equal?(call[:view])
      return "buffer provenance/restoration unavailable" unless call[:capture_completed] && call[:restored] && exact(call[:buffer], ActionView::OutputBuffer)
      return "converted options not exact class/href ordered hash" unless exact(options, Hash) &&
        options.default.nil? && options.default_proc.nil? && options.keys == ["class", "href"] &&
        exact(options["class"], String) && options["class"] == call[:css] && escape == true
      url = options["href"]
      return "URL encoding/safety/holder" unless exact(url, String) && url.encoding == Encoding::UTF_8 && url.valid_encoding?
      return "content encoding/safety/holder" unless content.nil? ||
        ((exact(content, String) || exact(content, ActiveSupport::SafeBuffer)) && content.encoding == Encoding::UTF_8 && content.valid_encoding?)
      nil
    end

    def fast?(call, builder, content, options, escape)
      return false unless call && call[:eligible_at_entry]
      reason = predicate(call, builder, content, options, escape)
      call[:reason] = reason if reason
      !reason
    end

    def render(call, content, options)
      # Class is the guarded literal. URL escape stays live in the exact
      # class-before-href order; nothing restarts after either escaping step.
      css = ERB::Util.unwrapped_html_escape(options["class"])
      css = css.gsub('"', "&quot;") if css.include?('"')
      url = ERB::Util.unwrapped_html_escape(options["href"])
      url = url.gsub('"', "&quot;") if url.include?('"')
      tag_options = %( class="#{css}" href="#{url}")
      content = ERB::Util.unwrapped_html_escape(content) if content.present?
      result = "<a#{tag_options}>#{ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS['a']}#{content}</a>".html_safe
      call[:fast] = true # Only a normally completed suffix is a hit.
      result
    end

    def link_completed(call, _result)
      return unless call
      call[:completed] = true
      count(call, call[:fast] ? "hits" : "original_completed") if call[:site]
      return unless call[:witness]
      reason = predicate(call, call[:builder], nil, call[:options], true)
      state = call.fetch(:state)
      state[:reason] = reason
      state[:holders] = call[:entry].values_at(:view_holder, :controller_holder, :compiled_holder) unless reason
      # Last publication, only after WHOLE original link returned normally.
      state[:state] = reason ? "refused" : "active"
    end

    def link_leave(call)
      return unless call
      if call[:witness]
        call[:state].merge!(state: "refused", reason: "original did not complete") unless call[:completed]
        call[:state][:lock].unlock
      end
      count(call, "fallback: #{call[:reason] || 'first original or off arm'}") if call[:site] && !call[:fast]
      Thread.current[THREAD_LINK] = call[:previous]
    end

    def count(call, name)
      return unless @counts && call[:site]
      row = (@counts[call[:site]] ||= Hash.new(0))
      row[name] += 1
    end

    def report
      {counts: @counts, contexts: @contexts.transform_values { _1.reject { |key, _| %i[lock holders].include?(key) } },
        discovered: @discovered.values, epoch: EPOCH[0]}
    end
  end
end
