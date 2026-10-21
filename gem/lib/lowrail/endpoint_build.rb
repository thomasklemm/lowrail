# frozen_string_literal: true

require "digest"
require_relative "prism_grammar"
require_relative "manifest"
require_relative "endpoint"

module Lowrail
  # First endpoint slice: specialize the no-block link_to body inside Rails'
  # compiled ERB. All nested dispatch (URL generation, tags, models, forms,
  # translations and renderers) remains live. No handwritten application HTML.
  module EndpointBuild
    PASS = "endpoint/action"
    CONTROLLER = "ArticlesController"
    ACTIONS = %w[index show].freeze
    TEMPLATES = %w[articles/index articles/show articles/_article comments/_comment layouts/application].freeze

    class Calls < Prism::Visitor
      attr_reader :calls
      def initialize = @calls = []
      def visit_call_node(node)
        if node.name == :link_to && node.receiver.nil? && node.block.nil? &&
            (2..3).cover?(node.arguments&.arguments&.size || 0) &&
            node.arguments.arguments.none? { Prism::SplatNode === _1 || Prism::ForwardingArgumentsNode === _1 }
          @calls << node
        else
          super
        end
      end
    end

    module_function

    def build(denied: [])
      ledger, units = [], []
      reason = if Rails.version != "8.1.4"
        "unsupported_rails_version"
      elsif Rails.application.class.name != "RealBlogR4::Application"
        "unsupported_application"
      end
      if reason
        return {units: [], ledger: [{"pass" => PASS, "method" => CONTROLLER, "outcome" => reason}]}
      end
      controller = Object.const_get(CONTROLLER)
      original = controller.instance_method(:process)
      helper = controller.view_context_class.instance_method(:link_to)
      # A copied body is not permission to inline custom methods, closures,
      # super, or a future Rails implementation with different control flow.
      expand_helper = helper.owner.equal?(ActionView::Helpers::UrlHelper) && canonical_helper?(helper)
      view = controller.new.view_context
      run = view.class.instance_method(:_run)
      unless run.owner.equal?(ActionView::Base)
        return {units: [], ledger: [{"pass" => PASS, "method" => CONTROLLER, "outcome" => "custom_view_run"}]}
      end
      templates = TEMPLATES.filter_map do |name|
        path = Rails.root.join("app/views/#{name}.html.erb").to_s
        resolver = controller.view_paths.paths.find { _1.instance_of?(ActionView::FileSystemResolver) && path.start_with?("#{_1.path}/") }
        raise "unsupported template resolver: #{path}" unless resolver
        local = File.basename(name).start_with?("_") ? File.basename(name).delete_prefix("_") : nil
        locals = local ? [local, "#{local}_counter", "#{local}_iteration"] : []
        template = resolver.send(:build_unbound_template, path).bind_locals(locals)
        handler = template.handler.call(template, template.send(:encode!))
        compiled = template.send(:compiled_source)
        definition = Prism.parse(compiled, version: PrismGrammar.version).value.statements.body.fetch(0)
        raise "unsupported compiled template" unless Prism::DefNode === definition && !template.strict_locals?
        source = definition.body.location.slice
        lowered, sites = lower(source, expand: expand_helper)
        inline = template_dispatch(path, lowered, original: source)
        ledger.concat(sites.map { {"pass" => PASS, "file" => path, **_1} })
        template.send(:compile!, view)
        [path, {"source_sha256" => Digest::SHA256.file(path).hexdigest,
          "original" => handler, "code" => handler,
          "locals" => locals.sort, "template_iseq" => Endpoint.template_signature(view.method(template.method_name)),
          "inline" => inline}]
      rescue StandardError, ScriptError => error
        ledger << {"pass" => PASS, "file" => path, "outcome" => "template: #{error.class}: #{error.message.lines.first&.strip}"}
        nil
      end.to_h
      return {units: [], ledger: ledger} if templates.empty?
      sources = [__FILE__, File.join(__dir__, "endpoint.rb"), original.source_location.first,
        (helper.source_location.first if expand_helper), run.source_location.first].compact.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
      ACTIONS.each do |action|
        target = "#{CONTROLLER}##{action}"
        if denied.any? { _1["pass"] == PASS && (_1["target"] || _1["file"]) == target }
          ledger << {"pass" => PASS, "method" => target, "outcome" => "denylisted by verify --bisect"}
          next
        end
        units << {"pass" => PASS, "kind" => "runtime", "target" => target, "file" => target,
          "sites" => 1, "facts" => [], "endpoint" => {"controller" => CONTROLLER, "action" => action,
            "locale" => I18n.locale.to_s,
            "sources" => sources, "templates" => templates, "helper" => Endpoint.method_signature(helper),
            "process" => Endpoint.method_signature(original), "run" => Endpoint.method_signature(run),
            "code" => dispatcher(templates)}}
        ledger << {"pass" => PASS, "method" => target, "outcome" => "lowered"}
      end
      {units: units, ledger: ledger}
    end

    def canonical_helper?(method)
      location = method.source_location
      return false unless location && File.file?(location.first)
      source = File.read(location.first)
      node = Prism.parse(source, version: PrismGrammar.version).value
      definitions = Class.new(Prism::Visitor) do
        attr_reader :definitions
        def initialize = @definitions = []
        def visit_def_node(node)
          @definitions << node
          super
        end
      end.new
      node.accept(definitions)
      definition = definitions.definitions.find { _1.name == :link_to && _1.location.start_line == method.source_location.last }
      tokens = ->(text) { Prism.lex(text, version: PrismGrammar.version).value.map(&:first).reject { |token| %i[COMMENT NEWLINE NEWLINE_TERMINATOR IGNORED_NEWLINE SEMICOLON EOF].include?(token.type) }.map { |token| [token.type, token.value] } }
      definition && tokens.call(definition.location.slice) == tokens.call(<<~'RUBY')
        def link_to(name = nil, options = nil, html_options = nil, &block)
          html_options, options, name = options, name, block if block_given?
          options ||= {}
          html_options = convert_options_to_data_attributes(options, html_options)
          url = url_target(name, options)
          html_options["href"] ||= url
          content_tag("a", name || url, html_options, &block)
        end
      RUBY
    end

    def lower(source, expand: true)
      wrapper = "def __lowrail_view__;"
      parsed = Prism.parse("#{wrapper}#{source}\nend", version: PrismGrammar.version)
      raise "compiled ERB does not parse" unless parsed.success?
      calls = Calls.new
      parsed.value.accept(calls)
      unless expand
        return [source, calls.calls.map { {"line" => _1.location.start_line, "outcome" => "helper_implementation", "helper" => "link_to"} }]
      end
      output = source.b.dup
      sites = []
      # A fresh prefix cannot collide with any app locals, including locals
      # assigned elsewhere in the template or in a block's lexical scope.
      prefix = "__lowrail_endpoint_"
      prefix += "_" while source.include?(prefix)
      calls.calls.each_with_index.to_a.reverse_each do |node, index|
        args = node.arguments.arguments.map { Prism::KeywordHashNode === _1 ? "{#{_1.location.slice}}" : _1.location.slice }
        args << "nil" if args.size == 2
        n, o, h, u, p = %w[name options html url plan].map { "#{prefix}#{index}_#{_1}" }
        fallback = node.arguments.arguments.zip([n, o, h]).map { |arg, name| Prism::KeywordHashNode === arg ? "**#{name}" : name }.join(", ")
        # Evaluate exactly once, BEFORE the effective-method check: an
        # argument expression can itself redefine the helper. All methods
        # called by the inlined body remain ordinary, live implicit calls.
        replacement = <<~RUBY
          (begin
            #{n}, #{o}, #{h} = [#{args.join(', ')}]
            #{p} = ::Lowrail::Endpoint.current(self)
            if #{p} && #{p}.helper_current?(self)
              #{o} ||= {}
              #{h} = convert_options_to_data_attributes(#{o}, #{h})
              #{u} = url_target(#{n}, #{o})
              #{h}["href"] ||= #{u}
              content_tag("a", #{n} || #{u}, #{h})
            else
              link_to(#{fallback})
            end
          end)
        RUBY
        output[(node.location.start_offset - wrapper.bytesize)...(node.location.end_offset - wrapper.bytesize)] = replacement.b
        sites << {"line" => node.location.start_line, "outcome" => "lowered", "helper" => "link_to"}
      end
      [output.force_encoding(source.encoding), sites.reverse]
    end

    def template_dispatch(path, source, original: source)
      # Each template has its own method scope: partial locals must not become
      # lexical locals in the parent template. Unknown shapes keep Rails' _run.
      extra = %w[method template locals buffer add_to_stack has_strict_locals block __method__ __callee__ binding eval local_variables]
      tokens = Prism.lex(source, version: PrismGrammar.version).value.map { _1.first.type }
      raise "compiled template uses super" if (tokens & %i[KEYWORD_SUPER]).any?
      parsed = Prism.parse("def __lowrail_view__;#{original}\nend", version: PrismGrammar.version)
      calls = Class.new(Prism::Visitor) do
        attr_reader :names
        def initialize = @names = []
        def visit_call_node(node)
          @names << node.name.to_s
          super
        end
        # A copied method has a different CREF and source location. Do not
        # move operations whose meaning depends on either; the original
        # compiled template continues to handle them, including Comment.new.
        %i[constant_read constant_path class_variable_read class_variable_write
          class_variable_target class_variable_and_write class_variable_or_write
          class_variable_operator_write source_file source_line source_encoding
          def].each do |kind|
          define_method("visit_#{kind}_node") { |_| raise "compiled template depends on lexical scope" }
        end
      end.new
      parsed.value.statements.body.fetch(0).body.accept(calls)
      raise "compiled template shadows dispatch arguments" unless (calls.names & extra).empty?
      prefix = "__lowrail_saved_"
      prefix += "_" while source.include?(prefix)
      <<~RUBY
        Module.new do
          def _run(method, template, locals, buffer, add_to_stack: true, has_strict_locals: false, &block)
            #{prefix}entry = ::Lowrail::Endpoint.current(self)
            return super unless #{prefix}entry && !has_strict_locals &&
              #{prefix}entry.template_current?(self, method, template, locals, #{path.inspect})
            #{prefix}output, #{prefix}path, #{prefix}template = @output_buffer, @virtual_path, @current_template
            begin
              @current_template = template if add_to_stack
              @output_buffer = buffer
              local_assigns, output_buffer, _ = locals, buffer, block
              #{source}
            ensure
              @output_buffer, @virtual_path, @current_template = #{prefix}output, #{prefix}path, #{prefix}template
            end
          end
        end
      RUBY
    end

    def dispatcher(templates)
      <<~RUBY
        # frozen_string_literal: #{!!ActionView::Template.frozen_string_literal}
        [Module.new do
          def process(action, ...)
            return super unless ::Ractor.current.equal?(::Ractor.main)
            previous = ::Lowrail::Endpoint::CURRENT[self]
            ::Lowrail::Endpoint::CURRENT[self] = ::Lowrail::Endpoint.enter(self, action)
            super
          ensure
            ::Lowrail::Endpoint::CURRENT[self] = previous if ::Ractor.current.equal?(::Ractor.main)
          end
        end, [#{templates.values.map { _1.fetch("inline").strip }.join(",\n")}]]
      RUBY
    end
  end
end
