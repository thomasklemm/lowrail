# frozen_string_literal: true

module Lowrail
  # A read-only witness, after the app's first original form has run. Never
  # ask Rails to populate a cache, compile a template, or load a dependency.
  module FormScaffoldAdmission
    IVAR = Object.instance_method(:instance_variable_get)
    FETCH = Hash.instance_method(:fetch)
    EACH = Hash.instance_method(:each_pair)
    DEFAULT = Hash.instance_method(:default)
    DEFAULT_PROC = Hash.instance_method(:default_proc)
    CVAR = Module.instance_method(:class_variable_get)
    TRANSLATIONS = [[:helpers, :label], [:activerecord, :attributes], [:attributes]].freeze

    module_function

    def ivar(object, name) = IVAR.bind_call(object, name)
    def fetch(hash, key) = FETCH.bind_call(hash, key, nil)

    # Only a code label contains Rails' process-local generated method name.
    # Retain all operands, locals, catches, line events and source paths.
    def block_signature(sequence, method_name)
      labels = ->(value) do
        return value unless Array === value
        value = value.map { labels.call(_1) }
        if value.first == "YARVInstructionSequence/SimpleDataFormat"
          value[5] = value[5].sub(method_name, "__lowrail_template__")
        end
        value
      end
      Sealed.signature(IVAR, sequence: labels.call(sequence.to_a)).fetch("iseq")
    end

    # No lookup/default proc, interpolation, symbol alias or translation
    # callback is invoked. Concurrent::Hash is the stock Simple backend root.
    def translations(backend, exact)
      tree = ivar(backend, :@translations)
      plain_hash = ->(value) {
        exact.call(value, Hash) || (type = Lowrail.loaded_constant("Concurrent::Hash")) && exact.call(value, type)
      }
      literal_hash = ->(value) {
        plain_hash.call(value) && DEFAULT.bind_call(value).nil? && DEFAULT_PROC.bind_call(value).nil?
      }
      literal = ->(value) do
        return value if value.nil? || exact.call(value, String)
        raise ArgumentError, "dynamic translation cache" unless literal_hash.call(value)
        result = {}
        EACH.bind_call(value) do |key, item|
          raise ArgumentError, "dynamic translation key" unless Symbol === key || exact.call(key, String)
          result[key.to_s] = literal.call(item)
        end
        result
      end
      raise ArgumentError, "translation cache not already loaded" unless plain_hash.call(tree)
      # Simple's root has a stock locale-creating default proc. Fetch only the
      # already-present English tree; never run it or assume it is pure.
      english = fetch(tree, :en)
      raise ArgumentError, "English translation cache not already loaded" unless literal_hash.call(english)
      TRANSLATIONS.map do |path|
        value = english
        path.each do |key|
          break if value.nil?
          raise ArgumentError, "dynamic translation cache" unless literal_hash.call(value)
          value = fetch(value, key)
        end
        literal.call(value)
      end
    end

    def check(data, view, block)
      passive = data.fetch("passive")
      native = Lowrail.loaded_constant("Lowrail::Native")
      return "missing actual-holder primitive; keep original" unless native
      exact = native.method(:exact_class?)
      return "actual-holder primitive changed; rebuild" unless Sealed.signature(exact) == passive.fetch("native_method")
      return "view context dispatch changed; rebuild" unless Sealed.view_context_fact == passive.fetch("view_context")
      return "unknown form block holder; keep original" unless exact.call(block, Proc)
      binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return "actual-holder binary not certified; rebuild" unless data.fetch("sources").key?(binary)
      return "stale sources; rebuild" unless data.fetch("sources").all? { |path, sha| File.file?(path) && Manifest.sha256_file(path) == sha }
      controller = Lowrail.loaded_constant("ArticlesController")
      view_class = controller && ivar(controller, :@view_context_class)
      return "view class not naturally cached; keep original" unless view_class && exact.call(view, view_class)
      return "application class changed; rebuild" unless Rails.application.class.name == data.fetch("inventory").fetch("application_class")

      mutation_holders = {native => [:exact_class?], BasicObject => [:instance_exec]}
      data.fetch("inventory").fetch("methods").each do |name, expected|
        if name == "template_compiler"
          type = Lowrail.loaded_constant("ActionView::Template")
          return "template dependency not already loaded" unless type
          (mutation_holders[type] ||= []) << :compiled_source
          method = type.instance_method(:compiled_source)
          method = method.super_method if defined?(Templates::CompiledSource) && method.owner.equal?(Templates::CompiledSource)
          return "template compiler changed; rebuild" unless FormScaffoldInventory.runtime_fact(method) == expected
          next
        end
        singleton = name.end_with?(".singleton")
        constructor = name.end_with?(".new")
        target = name.delete_suffix(".singleton").delete_suffix(".new")
        type = target == "view" ? view_class : Lowrail.loaded_constant(target)
        return "dependency #{target} not already loaded; keep original" unless type
        facts = constructor ? {"new" => expected} : expected
        (mutation_holders[type] ||= []).concat(facts.keys)
        facts.each do |method_name, fact|
          method = singleton || constructor ? type.method(method_name) : type.instance_method(method_name)
          method = method.super_method if target == "view" && method_name == "form_with" && method.owner.equal?(FormScaffold::Variant)
          if target == "view" && method_name == "token_tag" && defined?(TokenTag::Variant) && method.owner.equal?(TokenTag::Variant)
            # Only this explicitly certified symmetric observer may precede
            # the stock helper. Never unwrap an arbitrary helper override.
            return "token observer changed; rebuild" unless passive["token_observer"] &&
              Sealed.signature(method) == passive.fetch("token_observer")
            method = method.super_method
          end
          expected_body = fact.reject { |key, _| key == "visibility" }
          actual_body = FormScaffoldInventory.runtime_fact(method)
          if method_name == "tag_builder" && Sealed::ACTIVE[0]
            # The link certificate already proves its delivered stock factory
            # plus builder witness. Match that exact body, not arbitrary code
            # at the stock source location, before using its stock audit fact.
            delivery = Lowrail.manifest.units.find { _1["pass"] == Sealed::PASS }&.dig("sealed", "delivery", method.source_location.first)
            actual_body = expected_body if delivery && Loader.served?(method.source_location.first) && actual_body == delivery.fetch("signature")
          end
          return "method #{name}##{method_name} changed; rebuild" unless actual_body == expected_body
          return "visibility #{name}##{method_name} changed; rebuild" if fact["visibility"] &&
            Sealed.visibility(type, method_name) != fact.fetch("visibility")
        end
      end

      # Each class-attribute reader is independently restricted at build time
      # to the stock closure that returns its captured value without sends.
      readers = passive.fetch("readers").to_h do |target, expected|
        type_name, method_name = target.split(".", 2)
        type = Lowrail.loaded_constant(type_name)
        return "cache owner #{type_name} not already loaded" unless type
        (mutation_holders[type] ||= []) << method_name
        method = type.method(method_name)
        return "cache reader #{target} changed; rebuild" unless Sealed.signature(method) == expected
        [target, method.call]
      end
      callbacks = readers.fetch("Comment.__class_attr___callbacks")
      return "initialization callback cache unavailable" unless exact.call(callbacks, Hash)
      chain = fetch(callbacks, :initialize)
      return "initialization callback cache unavailable" unless exact.call(chain, Lowrail.loaded_constant("ActiveSupport::Callbacks::CallbackChain"))
      list = ivar(chain, :@chain)
      return "initialization callbacks; keep original" unless exact.call(list, Array) && list.empty?
      defaults = readers.fetch("ArticlesController.__class_attr_default_url_options")
      return "custom URL defaults; keep original" unless exact.call(defaults, Hash) && defaults.empty?

      comment = Lowrail.loaded_constant("Comment")
      article = Lowrail.loaded_constant("Article")
      return "model caches not naturally populated" unless [comment, article].all? { |type| type && ivar(type, :@schema_loaded) && ivar(type, :@attribute_methods_generated) }
      attributes = ivar(comment, :@default_attributes)
      return "default attribute cache unavailable" unless exact.call(attributes, Lowrail.loaded_constant("ActiveModel::AttributeSet"))
      attributes = ivar(attributes, :@attributes)
      return "default attribute cache unavailable" unless exact.call(attributes, Hash)
      {"commenter" => "ActiveModel::Type::String", "body" => "ActiveRecord::Type::Text"}.each do |field, name|
        attribute = fetch(attributes, field)
        return "custom/defaulted #{field}; keep original" unless exact.call(attribute, Lowrail.loaded_constant("ActiveModel::Attribute::FromDatabase")) &&
          ivar(attribute, :@value_before_type_cast).nil? && exact.call(ivar(attribute, :@type), Lowrail.loaded_constant(name))
      end
      {article => {:@singular_route_key => "article", :@route_key => "articles"},
        comment => {:@param_key => "comment", :@route_key => "comments"}}.each do |type, names|
        model_name = ivar(type, :@_model_name)
        return "model naming cache unavailable" unless exact.call(model_name, Lowrail.loaded_constant("ActiveModel::Name")) &&
          names.all? { |key, value| exact.call(ivar(model_name, key), String) && ivar(model_name, key) == value }
      end

      form = Lowrail.loaded_constant("ActionView::Helpers::FormHelper")
      tags = Lowrail.loaded_constant("ActionView::Helpers::FormTagHelper")
      base = Lowrail.loaded_constant("ActionView::Base")
      builder = Lowrail.loaded_constant("ActionView::Helpers::FormBuilder")
      return "custom form configuration; keep original" unless CVAR.bind_call(form, :@@form_with_generates_ids) == true &&
        CVAR.bind_call(form, :@@form_with_generates_remote_forms) == false && CVAR.bind_call(tags, :@@default_enforce_utf8) == false &&
        CVAR.bind_call(tags, :@@prepend_content_exfiltration_prevention) == false &&
        CVAR.bind_call(base, :@@automatically_disable_submit_tag) == true && CVAR.bind_call(base, :@@default_form_builder).equal?(builder)
      config = Fiber[:i18n_config]
      config_type = Lowrail.loaded_constant("I18n::Config")
      proxy_type = Lowrail.loaded_constant("ActionView::I18nProxy")
      if proxy_type && exact.call(config, proxy_type)
        return "foreign I18n render context; keep original" unless ivar(config, :@lookup_context).equal?(ivar(view, :@lookup_context)) &&
          ivar(config, :@owner).equal?(Fiber.current)
        config = ivar(config, :@original_config)
      end
      return "I18n config not naturally populated" unless config_type && exact.call(config, config_type)
      backend = CVAR.bind_call(config_type, :@@backend)
      return "I18n backend not naturally initialized" unless exact.call(backend, Lowrail.loaded_constant("I18n::Backend::Simple")) && ivar(backend, :@initialized)
      return "literal translations changed; rebuild" unless translations(backend, exact) == passive.fetch("translations")
      # The independently audited stock getter only reads @_routes or its
      # captured RouteSet. Reading the ivar alone misses the normal nil case.
      routes = view_class.instance_method(:_routes).bind_call(view)
      return "route cache unavailable" unless exact.call(routes, Lowrail.loaded_constant("ActionDispatch::Routing::RouteSet")) &&
        routes.equal?(ivar(Rails.application, :@routes))
      url_defaults = ivar(routes, :@default_url_options)
      mappings = ivar(routes, :@polymorphic_mappings)
      return "custom routes/defaults; keep original" unless exact.call(url_defaults, Hash) && url_defaults.empty? && exact.call(mappings, Hash) &&
        %w[Array Article Comment].all? { fetch(mappings, _1).nil? }
      polymorphic = Lowrail.loaded_constant("ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder")
      cache = Lowrail.loaded_constant("ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder::CACHE")
      return "polymorphic cache unavailable" unless exact.call(cache, Hash) && exact.call(fetch(cache, :path), Hash)
      cached = fetch(fetch(cache, :path), nil)
      return "polymorphic cache unavailable" unless exact.call(cached, polymorphic)
      key = ivar(cached, :@key_strategy)
      return "custom polymorphic cache; rebuild" unless exact.call(key, Proc) && ivar(cached, :@prefix) == "" && ivar(cached, :@suffix) == "path" &&
        Sealed.signature(key.method(:call), sequence: RubyVM::InstructionSequence.of(key)&.to_a) == passive.fetch("polymorphic_key")
      return "custom literal tables; keep original" unless Sealed.literal_state?(exact_class: exact) &&
        %w[for type name id rows value data-disable-with action accept-charset method].all? { fetch(ActionView::Helpers::TagHelper::TAG_TYPES, _1).nil? }
      text_field = Lowrail.loaded_constant("ActionView::Helpers::Tags::TextField")
      return "text-field type cache unavailable" unless ivar(text_field, :@field_type) == "text"

      template = ivar(view, :@current_template)
      return "template not naturally compiled" unless exact.call(template, Lowrail.loaded_constant("ActionView::Template")) && ivar(template, :@compiled) == true &&
        exact.call(ivar(template, :@identifier), String) && ivar(template, :@identifier) == data.fetch("site").fetch("source_location").first &&
        exact.call(ivar(template, :@locals), Array) && ivar(template, :@locals).empty? && ivar(template, :@strict_locals).nil? && exact.call(ivar(template, :@method_name), String)
      return "custom ERB handler; keep original" unless exact.call(ivar(template, :@handler), Lowrail.loaded_constant("ActionView::Template::Handlers::ERB"))
      sequence = RubyVM::InstructionSequence.of(block)
      return "natural form body differs; rebuild" unless sequence && block_signature(sequence, ivar(template, :@method_name)) == passive.fetch("block_iseq")
      {holder: exact, view_class: view_class, article_class: article, model_class: comment,
        form_class: builder, builder_class: Lowrail.loaded_constant("ActionView::Helpers::TagHelper::TagBuilder"),
        buffer_class: Lowrail.loaded_constant("ActionView::OutputBuffer"), table: ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS,
        mutation_holders: mutation_holders}
    rescue StandardError, ScriptError => error
      "passive admission: #{error.class}: #{error.message.lines.first&.strip}; keep original"
    end
  end
end
