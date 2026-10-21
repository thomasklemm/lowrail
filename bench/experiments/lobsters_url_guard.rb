# frozen_string_literal: true

# Exploration certificate cost, not a production installer. Follow Endpoint's
# intrinsic effective-method + visibility checks, not hook/epoch-only caches.
module LobstersUrlGuard
  CLASS = Kernel.instance_method(:class)
  SINGLETON = Kernel.instance_method(:singleton_class)
  IVAR = Kernel.instance_method(:instance_variable_get)
  METHOD = Module.instance_method(:instance_method)
  PUBLIC = Module.instance_method(:public_method_defined?)
  PRIVATE = Module.instance_method(:private_method_defined?)
  PROTECTED = Module.instance_method(:protected_method_defined?)
  HASH_EACH = Hash.instance_method(:each)
  ARRAY_EACH = Array.instance_method(:each)
  BYTES = String.instance_method(:b)
  STRUCT_GET = Struct.instance_method(:[])
  PUBLIC_METHOD = Kernel.instance_method(:public_method)
  UNBIND = Method.instance_method(:unbind)

  class Certificate
    def initialize(helper, observations, path, coverage)
      @helper, @path, @coverage = helper, path.freeze, coverage
      @route = IVAR.bind_call(helper, :@route)
      @base = ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper
      @targets = observations.to_h do |target, name|
        [ [CLASS.bind_call(target), name], capture(target, [name, :url_options, :default_url_options,
          :_routes, :optimize_routes_generation?]) ]
      end
      @routes = observations.first.first._routes
      @named = @routes.named_routes
      @route_table = IVAR.bind_call(@named, :@routes)
      @route_name = IVAR.bind_call(helper, :@route_name)
      @helper_facts = capture_holder(CLASS.bind_call(helper), %i[call arg_size optimize_routes_generation?
        optimized_helper parameterize_args handle_positional_args])
      @fixed = [capture(@route, %i[format defaults required_parts parts path scope_options]),
        capture(@routes, %i[url_for generate find_script_name default_url_options relative_url_root formatter named_routes]),
        capture(@named, %i[get [] key?])]
      @fixed << capture(ActionDispatch::Http::URL, %i[url_for path_for])
      generator = ActionDispatch::Routing::RouteSet::Generator
      @fixed << capture(generator, [:new])
      @fixed << capture_holder(generator, %i[initialize normalize_options! normalize_controller_action_id!
        use_recall_for use_relative_controller! normalize_controller! generate controller options recall named_route])
      @formatter = @routes.formatter
      @fixed << capture(@formatter, %i[generate extract_parameterized_parts missing_keys match_route named_routes])
      @fixed << capture_holder(ActionDispatch::Journey::Formatter::RouteWithParams, %i[initialize path params])
      @fixed << capture(ActionDispatch::Journey::Formatter::RouteWithParams, [:new])
      @pattern = @route.path
      @fixed << capture(@pattern, %i[requirements requirements_for_missing_keys_check])
      @config = @routes.instance_variable_get(:@config)
      @fixed << capture(@config, [:relative_url_root])
      @formats = []
      collect_format(@route.instance_variable_get(:@path_formatter))
      @fixed.concat(@formats.map { capture(_1, [:evaluate]) })
      @formats.each do |format|
        format.instance_variable_get(:@parts).each do |part|
          @fixed << capture(part, [:name]) if part.is_a?(ActionDispatch::Journey::Format::Parameter)
        end
      end
      # Primitive bodies skipped by the zero-part formatter and root generator.
      @fixed << capture_holder(Hash, %i[[] []= merge merge! dup delete delete_if key? keys each each_key empty?])
      @fixed << capture_holder(Array, %i[dup each each_with_index [] []= join include? reverse_each drop_while |])
      @fixed << capture_holder(String, %i[to_s start_with? [] empty?])
      @fixed << capture(@route_table, %i[[] key?])
      @value_bodies = {
        Hash => %i[merge merge! dup delete delete_if key? [] []= each each_key keys empty?],
        Array => %i[dup each [] []= join size empty? reverse_each],
        String => %i[to_s start_with? [] empty?]
      }.to_h do |klass, names|
        [klass, names.map { |name| [name, METHOD.bind_call(klass, name)] }]
      end
      @state = state
    end

    def capture(object, names) = capture_holder(SINGLETON.bind_call(object), names)

    def capture_holder(holder, names)
      [holder, names.map do |name|
        visibility = [PUBLIC, PRIVATE, PROTECTED].find { _1.bind_call(holder, name) }
        [name, visibility && METHOD.bind_call(holder, name), visibility]
      end]
    end

    def current?(facts, holder = facts.first)
      facts.last.all? do |name, body, visibility|
        body ? visibility.bind_call(holder, name) && METHOD.bind_call(holder, name) == body :
          !PUBLIC.bind_call(holder, name) && !PRIVATE.bind_call(holder, name) && !PROTECTED.bind_call(holder, name)
      end
    rescue NameError, TypeError
      false
    end

    def collect_format(format)
      @formats << format
      format.instance_variable_get(:@parts).each do |part|
        collect_format(part) if part.is_a?(ActionDispatch::Journey::Format)
      end
    end

    def state
      # Typed Rails format/default state only: no app serializers or value hooks.
      @values_safe = true
      [%i[@options @required_parts @arg_size @segment_keys @route_name].map { IVAR.bind_call(@helper, _1) },
        IVAR.bind_call(@routes, :@default_url_options), @route.defaults, @route.required_parts,
        @route.path.requirements, @route.parts, @route.scope_options,
        @formats.map { |format| %i[@parts @children @parameters].map { IVAR.bind_call(format, _1) } }]
        .then { Marshal.dump(scalar_copy(_1)) }
    end

    def scalar_copy(value)
      klass = CLASS.bind_call(value)
      if (bodies = @value_bodies[klass])
        @values_safe &&= bodies.all? do |name, body|
          UNBIND.bind_call(PUBLIC_METHOD.bind_call(value, name)) == body
        rescue NameError
          false
        end
      end
      if klass.equal?(Hash)
        pairs = []
        HASH_EACH.bind_call(value) { |key, item| pairs << [scalar_copy(key), scalar_copy(item)] }
        pairs
      elsif klass.equal?(Array)
        values = []
        ARRAY_EACH.bind_call(value) { values << scalar_copy(_1) }
        values
      elsif klass.equal?(String)
        [value.encoding.name, BYTES.bind_call(value)]
      elsif @formats.any? { _1.equal?(value) }
        [:format, value.object_id]
      elsif klass.equal?(ActionDispatch::Journey::Format::Parameter)
        [:parameter, value.object_id, scalar_copy(STRUCT_GET.bind_call(value, 0))]
      elsif value.nil? || klass.equal?(Symbol) || klass.equal?(Integer) || klass.equal?(TrueClass) || klass.equal?(FalseClass)
        value
      else
        @values_safe = false
        [:unsupported, value.object_id]
      end
    end

    def valid?(target, name)
      expected = @targets[[CLASS.bind_call(target), name]]
      expected && current?(expected, SINGLETON.bind_call(target)) && current?(@helper_facts) &&
        @fixed.all? { current?(_1) } && @routes.named_routes.equal?(@named) &&
        IVAR.bind_call(@named, :@routes).equal?(@route_table) &&
        @routes.formatter.equal?(@formatter) && IVAR.bind_call(@routes, :@config).equal?(@config) &&
        @named.get(@route_name).equal?(@route) && IVAR.bind_call(@helper, :@route).equal?(@route) &&
        IVAR.bind_call(@route, :@path).equal?(@pattern) &&
        IVAR.bind_call(@route, :@path_formatter).equal?(@formats.first) && state == @state && @values_safe
    end

    def count(name)
      LobstersUrlProgram.counts[name] += 1 if @coverage
    end

    def call(target, name, args, inner, strategy)
      unless valid?(target, name)
        count(:entry_fallback)
        # Permanent deopt restores real dispatch, including redefined/private
        # UrlHelper#call; never bind a stale saved body after failed admission.
        SINGLETON.bind_call(@helper).remove_method(:call)
        return @helper.call(target, name, args, inner, strategy)
      end
      unless args.empty? && (inner.nil? || (@route_name.to_s == "root" && inner.instance_of?(Hash) &&
          (inner.keys - [:host, :protocol]).empty?)) &&
          [ActionDispatch::Routing::RouteSet::PATH, ActionDispatch::Routing::RouteSet::UNKNOWN].include?(strategy)
        count(:shape_fallback)
        return IVAR.bind_call(@helper, :@lowrail_url_original).call(target, name, args, inner, strategy)
      end
      if inner.nil? && !@helper.send(:optimize_routes_generation?, target)
        count(:predicate_fallback)
        return METHOD.bind_call(@base, :call).bind_call(@helper, target, name, args, inner, strategy)
      end
      controller = target.url_options
      options = controller.merge(IVAR.bind_call(@helper, :@options))
      unless valid?(target, name)
        count(:boundary_fallback)
        if inner.nil?
          # Continue the already-entered optimized body after url_options.
          return finish(target, options, @helper.send(:optimized_helper, args), strategy)
        end
        hash = @helper.send(:handle_positional_args, controller, inner, args, options,
          IVAR.bind_call(@helper, :@segment_keys))
        return target._routes.url_for(hash, @route_name, strategy, name)
      end
      if inner
        options.merge!(inner)
        routes = target._routes
        unless routes.equal?(@routes) && valid?(target, name) && controller.empty? && routes.default_url_options.empty?
          count(:root_fallback)
          return routes.url_for(options, @route_name, strategy, name)
        end
      end
      count(:hit)
      finish(target, options, +@path, strategy, routes)
    end

    def finish(target, options, path, strategy, routes = nil)
      path << "/" if options[:trailing_slash] && !path.end_with?("/")
      options[:path] = path
      original_script = options.delete(:original_script_name)
      script = (routes || target._routes).find_script_name(options)
      options[:script_name] = original_script ? original_script + script : script
      if routes
        # Preserve the generic root continuation's full option shape, not only
        # its final string. Live URL strategy internals may observe these keys.
        options[:params] = {}
        options[:user] = options[:password] = nil
      end
      strategy.call(options)
    end
  end
end
