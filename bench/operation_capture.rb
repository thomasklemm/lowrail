# frozen_string_literal: true

require "prism"
require "json"
require "digest"

# Untimed, worker-local capture. Replay closures contain the emitted expression,
# not this instrumentation. No TracePoint: constructing one disables memo passes.
module OperationCapture
  class Source
    attr_reader :specs, :code, :path

    def initialize(code, path, units)
      @code, @path, @specs = code, path, []
      parsed = Prism.parse(code, version: "current")
      raise "cannot parse budget source: #{path}" unless parsed.success?
      visit = ->(node) {
        id, original = nil, nil
        if Prism::IfNode === node && (match = node.predicate.location.slice.match(/\A\(*(?:self\.class\.equal\?\(::Lowrail::K\[\d+\]\) \|\| )?::Lowrail\.ok\?\((\d+), self\.class\)/))
          id = Integer(match[1])
          original = node.subsequent&.statements
        elsif Prism::CallNode === node && %w[::Lowrail::Memo ::Lowrail::DigestMemo].include?(node.receiver&.location&.slice)
          args = node.arguments&.arguments
          if args && Prism::IntegerNode === args.first
            id = args.first.value
            receiver, *arguments = args.drop(1).map { _1.location.slice }
            original = case node.name
            when :join then "#{receiver}.join(#{arguments.join(', ')})"
            when :digest then "#{receiver}.base64digest(#{arguments.join(', ')})"
            when :hexdigest then "#{receiver}.file(#{arguments.fetch(0)}).hexdigest"
            end
          end
        end
        unit = units.find { _1.fetch("id") == id }
        if unit && original
          @specs << { key: "#{id}:#{node.location.start_offset}", id: id, node: node,
            original: original, pass: unit.fetch("pass") }
        end
        node.compact_child_nodes.each { visit.call(_1) }
      }
      visit.call(parsed.value)
    end

    def span(spec) = spec.fetch(:node).location

    def replace(location, candidates, &block)
      text = location.slice.dup
      roots = candidates.reject do |spec|
        candidates.any? { |other| other != spec && span(other).start_offset <= span(spec).start_offset && span(other).end_offset >= span(spec).end_offset }
      end
      roots.sort_by { span(_1).start_offset }.reverse_each do |spec|
        first = span(spec).start_offset - location.start_offset
        text.bytesplice(first, span(spec).length, block.call(spec))
      end
      text
    end

    def original(spec)
      value = spec.fetch(:original)
      return value if String === value
      nested = specs.select { span(_1).start_offset >= value.location.start_offset && span(_1).end_offset <= value.location.end_offset }
      replace(value.location, nested) { original(_1) }
    end

    def expression(spec)
      nested = specs.select { _1 != spec && span(_1).start_offset > span(spec).start_offset && span(_1).end_offset < span(spec).end_offset }
      # Registry order is semantic. Price link_to before route lowering, then
      # route operations at their actual post-link_to request frequency.
      replace(span(spec), nested) { original(_1) }
    end

    def counted(spec, text = expression(spec), callback = "completed")
      nodes = []
      visit = ->(node) {
        if spec.fetch(:pass) == "route/path" && Prism::CallNode === node &&
            node.name == :finish && node.receiver&.location&.slice == "::Lowrail::Routes"
          nodes << node
        elsif spec.fetch(:pass) == "view/link_to" && Prism::IfNode === node &&
            node.predicate.location.slice.include?("::Lowrail.ok?")
          nodes << node.statements
          next
        end
        node.compact_child_nodes.each { visit.call(_1) }
      }
      visit.call(Prism.parse(text, version: "current").value)
      nodes.sort_by { _1.location.start_offset }.reverse_each do |node|
        location = node.location
        text.bytesplice(location.start_offset, location.length, "(::OperationCapture.#{callback}(#{spec.fetch(:id)}); #{location.slice})")
      end
      text
    end

    def instrument
      wrap = ->(spec) {
        nested = specs.select { _1 != spec && span(_1).start_offset > span(spec).start_offset && span(_1).end_offset < span(spec).end_offset }
        body = replace(span(spec), nested) { wrap.call(_1) }
        body = counted(spec, body, "request_completed")
        "::OperationCapture.record(#{spec.fetch(:key).dump}, binding) { #{body} }"
      }
      location = Prism.parse(code, version: "current").value.location
      code.dup.bytesplice(location.start_offset, location.length, replace(location, specs) { wrap.call(_1) })
    end

    def literal_policy
      magic = Prism.parse(code, version: "current").magic_comments.find { _1.key == "frozen_string_literal" }
      value = if path.end_with?(".erb")
        ActionView::Template.frozen_string_literal
      elsif magic
        magic.value == "true"
      else
        RubyVM::InstructionSequence.compile_option[:frozen_string_literal]
      end
      value.nil? ? "" : "# frozen_string_literal: #{value}\n"
    end
  end

  class << self
    attr_reader :records, :sources, :completions, :request_completions

    def install
      @records, @sources, @specs, @completions = {}, {}, {}, Hash.new(0)
      @request_completions = Hash.new(0)
      @contexts = {}
      @manifest = Lowrail.manifest
      @manifest.templates.each do |path, entry|
        source = add_source(entry.fetch("code"), path)
        # Keep the on-disk manifest and pristine source intact.
        Lowrail::Templates.entries[path] = entry.merge("code" => source.instrument)
      end
      input = JSON.parse(File.read(File.join(@manifest.dir, "units.json")))
      input.fetch("files").each do |entry|
        path = entry.fetch("path")
        next unless @manifest.files.key?(path)
        add_source(File.read(entry.fetch("lowered")), path)
      end
      Lowrail::Loader.singleton_class.prepend(Module.new do
        def serve(path, ...)
          delivered = super
          source = OperationCapture.sources[path]
          return delivered unless delivered && source && !source.specs.empty?
          recipe = Lowrail::Compilation.original(path)
          binary = Lowrail::Compilation.lowered(source.code, path, recipe).to_binary
          expected = File.binread(File.join(Lowrail.manifest.dir, Lowrail.manifest.files.fetch(path).fetch("iseq")))
          raise "budget source does not reproduce delivered ISeq: #{path}" unless binary == expected
          Lowrail::Compilation.lowered(source.instrument, path, recipe)
        end
      end)
    end

    def add_source(code, path)
      source = Source.new(code, path, @manifest.units)
      @sources[path] = source
      source.specs.each { @specs[_1.fetch(:key)] = [source, _1] }
      source
    end

    def record(key, context)
      if @recording
        source, spec = @specs.fetch(key)
        id = spec.fetch(:id)
        ambient = ActiveSupport::CurrentAttributes.descendants.to_h { [_1, _1.attributes.dup] }
        raise "ambient request context changes within captured unit #{id}" if @contexts.key?(id) && @contexts.fetch(id) != ambient
        @contexts[id] = ambient
        # A new environment snapshots locals while retaining the real view or
        # helper receiver AND lexical constant scope. Reused render-loop
        # bindings must not change earlier samples.
        names = context.local_variables
        environment = context.eval("->(#{names.join(',')}) { binding }").call(*names.map { context.local_variable_get(_1) })
        pair = %i[original expression counted].to_h do |arm|
          [arm, environment.eval("#{source.literal_policy}-> { #{source.public_send(arm, spec)} }", source.path, source.span(spec).start_line)]
        end
        (@records[spec.fetch(:id)] ||= []) << pair
      end
      value = yield
      pair[:actual] = value if pair
      value
    end

    def completed(id) = @completions[id] += 1
    def request_completed(id)
      @request_completions[id] += 1 if @recording
    end

    def restore_context(id = @contexts.keys.first)
      # Rails' executor clears CurrentAttributes at request completion. Replay
      # must not turn a live route fallback into an optimized route afterwards.
      # A memo can run before the controller populates Current; restore each
      # unit's own context outside its client window, not one global snapshot.
      @contexts[id]&.each { |klass, attributes| klass.instance.attributes = attributes.dup }
    end

    def capture
      @records.clear
      @request_completions.clear
      @contexts.clear
      @recording = true
      # Runtime forms have no rewritten source expression. Capture the real
      # ERB block without a TracePoint, then remove this method before replay.
      form = @manifest.units.find { _1["pass"] == "sealed/form_scaffold" }
      if form
        calls, contexts = [], @contexts
        id = form.fetch("id")
        site = form.fetch("data").fetch("site").fetch("source_location")
        wrapper = Module.new do
          define_method(:form_with) do |model: false, scope: nil, url: nil, format: nil, **options, &block|
            if block && block.source_location == site
              ambient = ActiveSupport::CurrentAttributes.descendants.to_h { [_1, _1.attributes.dup] }
              raise "ambient request context changes within captured unit #{id}" if contexts.key?(id) && contexts.fetch(id) != ambient
              contexts[id] = ambient
              call = [self, model, scope, url, format, options, block]
              calls << call
            end
            value = super(model: model, scope: scope, url: url, format: format, **options, &block)
            call << value if call
            value
          end
        end
        ArticlesController.view_context_class.prepend(wrapper)
      end
      yield
      wrapper.send(:remove_method, :form_with) if wrapper
      calls&.each do |view, models, scope, url, format, options, block, actual|
        on = view.method(:form_with)
        off = on.super_method
        raise "form variant inactive" unless on.owner == Lowrail::FormScaffold::Variant && off
        raise "unknown form constructor" unless models.instance_of?(Array) && models.size == 2 && models.last.instance_of?(Comment)
        article = models.first
        # Both arms pay the same Method#call, array and fresh constructor. The
        # production variant, not the earlier handwritten micro, is priced.
        pair = { original: -> { off.call(model: [article, Comment.new], scope: scope, url: url, format: format, **options, &block) },
          expression: -> { on.call(model: [article, Comment.new], scope: scope, url: url, format: format, **options, &block) }, actual: actual }
        pair[:counted] = pair.fetch(:expression)
        pair[:equivalent] = ->(left, right) { form_equivalent?(view, left, right) }
        (@records[id] ||= []) << pair
      end
    ensure
      wrapper.send(:remove_method, :form_with) if wrapper&.instance_methods(false)&.include?(:form_with)
      @recording = false
    end

    def form_equivalent?(view, left, right)
      # Real entropy remains enabled. Validate each token independently before
      # normalizing only its mask for the operation's output comparison.
      [left, right].each do |html|
        token = html[/name="authenticity_token" value="([^"]+)"/, 1] or raise "form token missing"
        controller = view.controller
        decoded = controller.send(:unmask_token, controller.send(:decode_csrf_token, token))
        action = html[/action="([^"]+)"/, 1]
        verb = html[/name="_method" value="([^"]+)"/, 1] || "post"
        expected = controller.send(:per_form_csrf_token, view.session, URI.parse(action).path, verb)
        raise "invalid replay token" unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded, expected)
      end
      normalize = ->(html) { html.gsub(/(name="authenticity_token" value=")[^"]+/, '\\1MASK') }
      left.class == right.class && left.encoding == right.encoding && left.html_safe? == right.html_safe? &&
        normalize.call(left) == normalize.call(right)
    end
  end
end
