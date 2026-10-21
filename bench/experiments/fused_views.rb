# frozen_string_literal: true

# EXPLORATION ONLY. Explicit boot-time compiler, not a registered Lowrail pass.
# The driver must accept the sealed no-mutation/introspection contract. Rails
# still owns actions, helpers, collection selection/iteration, events and state.
require "prism"
require "digest"

module FusedViews
  CURRENT = :lowrail_experimental_fused_views
  MISS = Object.new.freeze
  PLANS = {}
  LEDGER = []
  COUNTS = Hash.new(0)
  ATTEMPTED = {}
  TARGETS = {"ArticlesController" => {"show" => ["comments/comment"], "index" => ["articles/article"]},
    "RoomsController" => {"show" => []}}.freeze
  METHOD = Kernel.instance_method(:public_method)
  class Refused < StandardError; end

  # Campfire retains Prism 1.4 in its unchanged bundle. Ruby 4.0 was named
  # 3.5 in that parser's grammar API; never use its unspecified latest mode.
  GRAMMAR = Gem::Version.new(Prism::VERSION) >= Gem::Version.new("2.0") ? "current" : "3.5"

  # These seams are installed symmetrically by the experiment driver. They do
  # not run in ordinary Lowrail builds and must not be used as production API.
  module Renderer
    private

    def render_template(view, template, layout_name, locals)
      controller, action = view.controller.class, view.controller.action_name
      key = [controller.name, action]
      # Own-suite witness only: never force controller autoloads at initialize!
      # when the app's own test boot leaves them lazy.
      if FusedViews.enabled? && !PLANS.key?(key) && !ATTEMPTED[key] && TARGETS.dig(*key)
        FusedViews.install(controller, action, partials: TARGETS.dig(*key))
      end
      plan = PLANS[key]
      return super unless FusedViews.enabled? && plan && locals.empty?
      layout = layout_name && find_layout(layout_name, locals.keys, [formats.first])
      return super(view, template, layout, locals) unless plan.valid?(view, template, layout)
      COUNTS[plan.key] += 1
      build_rendered_template(view.public_send(plan.method_name, self, template, layout, locals), template)
    end
  end

  module Partial
    def render(view, locals, buffer = nil, implicit_locals: [], add_to_stack: true, &block)
      context = Thread.current.thread_variable_get(CURRENT)
      if context && context.first.equal?(view) && !buffer && add_to_stack && !strict_locals?
        value = context.last.call(self, locals)
        return value unless value.equal?(MISS)
      end
      super
    end
  end

  class << self
    attr_accessor :enabled
    def enabled? = @enabled

    def install(controller, action, partials: [])
      ATTEMPTED[[controller.name, action]] = true
      raise Refused, "Ruby/Rails version" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      plan = Plan.new(controller, action, partials)
      PLANS[[controller.name, action]] = plan
      LEDGER << {target: plan.key, outcome: "compiled", templates: plan.templates.map(&:virtual_path),
        source_bytes: plan.code.bytesize, source_sha256: Digest::SHA256.hexdigest(plan.code)}
    rescue Refused, StandardError, ScriptError => error
      LEDGER << {target: "#{controller.name}##{action}", outcome: "refused", reason: error.message}
    end

    def observe
      ActionView::TemplateRenderer.prepend(Renderer)
      ActionView::Template.prepend(Partial)
    end

    def chain(method)
      result = []
      while method
        result << method
        method = method.super_method
      end
      result
    end

    def original(view, template, locals)
      saved = Thread.current.thread_variable_get(CURRENT)
      Thread.current.thread_variable_set(CURRENT, nil)
      template.render(view, locals) { |*name| view._layout_for(*name) }
    ensure
      Thread.current.thread_variable_set(CURRENT, saved)
    end
  end

  class Plan
    attr_reader :templates, :key, :method_name, :code

    def initialize(controller, action, partials)
      @key = "#{controller.name}##{action}.html"
      @method_name = "__lowrail_fused_#{action}_html"
      @view_class = controller.view_context_class
      lookup = controller.new.lookup_context
      raise Refused, "custom resolver" unless lookup.view_paths.all? { _1.instance_of?(ActionView::FileSystemResolver) }
      @template = lookup.find_template("#{controller.controller_path}/#{action}", [], false, [], formats: [:html])
      @layout = lookup.find_template("layouts/application", [], false, [], formats: [:html])
      @partials = partials.map do |path|
        name = File.basename(path)
        lookup.find_template(path, [], true, [name.to_sym, :"#{name}_counter", :"#{name}_iteration"], formats: [:html])
      end
      @templates = [@template, @layout, *@partials]
      @sources = @templates.to_h { [_1, _1.source.dup.freeze] }
      @methods = {}
      view = controller.new.view_context
      bodies = @templates.each_with_index.to_h do |template, index|
        raise Refused, "strict locals or non-ERB: #{template.virtual_path}" if template.strict_locals? ||
          template.handler != ActionView::Template.handler_for_extension(:erb)
        template.send(:compile!, view)
        @methods[template] = @view_class.instance_method(template.method_name)
        [template, region(template, index)]
      end
      @dependencies = [
        [@view_class, :_run], [@view_class, :render], [ActionView::Template, :render],
        [ActionView::Template, :compiled_source], [ActionView::TemplateRenderer, :render_template],
        [ActionView::CollectionRenderer, :collection_with_template]
      ].map { |holder, name| [holder, name, FusedViews.chain(holder.instance_method(name))] }
      @render = FusedViews.chain(ActionView::Template.instance_method(:render))
      @run = @view_class.instance_method(:_run)
      @view_paths = controller.view_paths
      branches = @partials.map.with_index do |template, n|
        "#{n.zero? ? 'if' : 'elsif'} __fv_partial.equal?(__fv_plan.templates[#{@templates.index(template)}])\n#{bodies.fetch(template)}"
      end
      callback = branches.empty? ? "::FusedViews::MISS" : "#{branches.join("\n")}\nelse\n::FusedViews::MISS\nend"
      @code = <<~RUBY
        # frozen_string_literal: #{!!ActionView::Template.frozen_string_literal}
        def #{@method_name}(__fv_renderer, __fv_template, __fv_layout, __fv_locals)
          __fv_previous = Thread.current.thread_variable_get(::FusedViews::CURRENT)
          __fv_plan = ::FusedViews::PLANS[#{[controller.name, action].inspect}]
          __fv_callback = lambda do |__fv_partial, __fv_partial_locals|
            #{callback}
          end
          Thread.current.thread_variable_set(::FusedViews::CURRENT, [self, __fv_callback])
          ActiveSupport::Notifications.instrument("render_layout.action_view", identifier: __fv_layout.identifier) do
            __fv_body = ActiveSupport::Notifications.instrument("render_template.action_view",
              identifier: __fv_template.identifier, layout: __fv_layout.virtual_path, locals: __fv_locals) do
              #{bodies.fetch(@template)}
            end
            view_flow.set(:layout, __fv_body)
            #{bodies.fetch(@layout)}
          end
        ensure
          Thread.current.thread_variable_set(::FusedViews::CURRENT, __fv_previous)
        end
      RUBY
      # The same compilation container/CREF as stock Template#compile. App
      # constants (e.g. Comment.new) must not resolve in the experiment module.
      @view_class.compiled_method_container.module_eval(@code, "lowrail:fused:#{@key}", 1)
    end

    def valid?(view, template, layout)
      return false unless view.class.equal?(@view_class) && template.equal?(@template) && layout.equal?(@layout) &&
        view.lookup_context.view_paths.equal?(@view_paths) && view.lookup_context.variants.empty?
      # Direct method identity catches suppressed mutation hooks between
      # requests. This is NOT a certificate for mutations during live helpers;
      # those are excluded by the explicitly accepted sealed contract.
      @dependencies.all? { |holder, name, body| FusedViews.chain(holder.instance_method(name)) == body } &&
        @templates.all? { |t| t.source == @sources.fetch(t) && @view_class.instance_method(t.method_name) == @methods.fetch(t) }
    rescue NameError
      false
    end

    def render_current?(template)
      FusedViews.chain(METHOD.bind_call(template, :render).unbind) == @render
    rescue NameError
      false
    end

    def body_current?(view, template)
      template.source == @sources.fetch(template) &&
        METHOD.bind_call(view, :_run).unbind == @run &&
        METHOD.bind_call(view, template.method_name).unbind == @methods.fetch(template)
    rescue NameError
      false
    end

    def region(template, index)
      compiled = template.send(:compiled_source)
      parsed = Prism.parse(compiled, version: GRAMMAR)
      raise Refused, "unparseable handler" unless parsed.success?
      definition = parsed.value.statements.body.fetch(0)
      raise Refused, "custom handler shape" unless Prism::DefNode === definition
      body = definition.body.location.slice.b
      scanner = Scanner.new
      definition.body.accept(scanner)
      raise Refused, scanner.refusal if scanner.refusal
      # Rename all lexical locals to preserve the separate method scopes of
      # compiled templates. Nested capture/form blocks remain ordinary blocks.
      prefix = "__fv_#{index}_"
      raise Refused, "reserved experiment local" if compiled.include?(prefix)
      edits = scanner.locals.map { |location| [location, prefix + location.slice] }
      scanner.yields.each do |node|
        raise Refused, "partial yield" unless index == 1
        args = node.arguments&.location&.slice
        edits << [node.location, "_layout_for(#{args})"]
      end
      origin = definition.body.location.start_offset
      edits.sort_by { _1.first.start_offset }.reverse_each do |location, replacement|
        body[(location.start_offset - origin)...(location.end_offset - origin)] = replacement.b
      end
      body.force_encoding(compiled.encoding)
      input = index < 2 ? "__fv_locals" : "__fv_partial_locals"
      object = index == 0 ? "__fv_template" : index == 1 ? "__fv_layout" : "__fv_partial"
      <<~RUBY
        #{prefix}template = #{object}
        if !__fv_plan.render_current?(#{prefix}template)
          ::FusedViews.original(self, #{prefix}template, #{input})
        else
          begin
            #{prefix}template.send(:instrument_render_template) do
              if __fv_plan.body_current?(self, #{prefix}template)
                ::FusedViews::COUNTS[#{"#{key}/#{template.virtual_path}".inspect}] += 1
                #{prefix}saved = [@output_buffer, @virtual_path, @current_template]
                begin
                  @current_template = #{prefix}template
                  @output_buffer = ActionView::OutputBuffer.new
                  #{prefix}local_assigns, #{prefix}output_buffer = #{input}, @output_buffer
                  #{prefix}result = begin
                    #{body}
                  end
                ensure
                  @output_buffer, @virtual_path, @current_template = #{prefix}saved
                end
              else
                #{prefix}template.send(:compile!, self)
                #{prefix}result = _run(#{prefix}template.method_name, #{prefix}template, #{input}, ActionView::OutputBuffer.new) { |*name| _layout_for(*name) }
              end
              #{prefix}result.is_a?(ActionView::OutputBuffer) ? #{prefix}result.to_s : #{prefix}result
            end
          rescue => #{prefix}error
            #{prefix}template.send(:handle_render_error, self, #{prefix}error)
          end
        end
      RUBY
    end
  end

  class Scanner < Prism::Visitor
    attr_reader :locals, :yields, :refusal
    def initialize
      @locals, @yields = [], []
    end

    def visit_call_node(node)
      if %i[cache cache_if cache_unless render_stream provide_stream binding eval local_variables].include?(node.name)
        @refusal = "unsupported #{node.name}"
      elsif node.name == :render
        args = node.arguments&.arguments || []
        @refusal = "render options/block (including cached collections)" unless args.one? && !node.block &&
          !(Prism::KeywordHashNode === args.first || Prism::HashNode === args.first)
      end
      super
    end

    def visit_yield_node(node)
      @yields << node
    end

    %i[local_variable_read local_variable_write local_variable_target local_variable_and_write
      local_variable_or_write local_variable_operator_write required_parameter optional_parameter
      rest_parameter block_parameter].each do |kind|
      define_method("visit_#{kind}_node") do |node|
        location = node.respond_to?(:name_loc) ? node.name_loc : node.location
        @locals << location if location
        super(node)
      end
    end

    %i[super forwarding_super def class module return break next redo retry].each do |kind|
      define_method("visit_#{kind}_node") { |_| @refusal = "unsupported control flow: #{kind}" }
    end
  end
end
