# frozen_string_literal: true

require "json"
require_relative "manifest"
require_relative "sealed"

module Lowrail
  # Build-only closed inventory. Its synthetic schema, translation, view and
  # compiler probes are not a passive observation of a running application.
  # These are audited gem-source pins, not hashes learned from an app's boot.
  module FormScaffoldInventory
    STOCK = {
      "actionview" => "b7135e378dc024f779abcf81b6f002e4ffc840fd691a77ea8278803ceddd35fd",
      "actionpack" => "aa7b3edafe53f19d4a54737b1dc5f84e49af40e08fc694f07bd28fcc7d609844",
      "activemodel" => "2927864a4658fc82c0d2aac115b7d72521739306ac8b2e2a3ee520d9f3edb39b",
      "activerecord" => "71e11e0f71594fdfbf318dc2b289c4f6da5f1e5b8daae2a8cc36ff9e5e7d3d6c",
      "activesupport" => "7b52dc2e11d86c2abe911faf31882990cd783d49e3c5bc54c554130cdcc1a0f7",
      "i18n" => "5428c85c55a8c7af9a535cbe6f2ada4d96739e168ada02553ddfa917a06c3229"
    }.freeze

    module_function

    def check(runtime: false)
      # The current certificate has no read-only witness for these synthetic
      # probes. Do not try to produce one by executing them in the app. Until
      # such a certificate exists, exact-or-refuse means the original form.
      return "form certification requires runtime controller/view/I18n/ERB effects; passive activation unavailable; keep original" if runtime
      return "source inventory released; restart to recertify" if @released
      return "requires production Ruby 4.0.7 / Rails 8.1.4 blog" unless ENV["RAILS_ENV"] == "production" &&
        RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      return "eager-loaded targets required; keep lazy applications original" unless Rails.application.config.eager_load &&
        %w[Article Comment ArticlesController].all? { Lowrail.loaded_constant(_1) }
      @roots = STOCK.keys.to_h { |name| [name, Gem.loaded_specs.fetch(name).full_gem_path] }
      @compiled = {}
      STOCK.each do |name, expected|
        root = @roots.fetch(name)
        files = Dir[File.join(root, "lib/**/*.rb")].sort.to_h { [_1.delete_prefix(root + "/"), Manifest.sha256_file(_1)] }
        return "non-stock #{name} source inventory" unless Digest::SHA256.hexdigest(JSON.generate(files)) == expected
      end
      Article.define_attribute_methods
      Comment.define_attribute_methods
      require "objspace"
      holder = ObjectSpace.method(:internal_class_of)
      view = ArticlesController.new.view_context
      return "custom form builder; use stock FormBuilder or keep this form original" unless view.send(:default_form_builder_class).equal?(ActionView::Helpers::FormBuilder)
      return "non-stock form config" unless ActionView::Helpers::FormHelper.form_with_generates_ids == true &&
        ActionView::Helpers::FormHelper.form_with_generates_remote_forms == false && view.send(:default_enforce_utf8) == false &&
        ActionView::Base.automatically_disable_submit_tag == true && view.send(:prepend_content_exfiltration_prevention) == false
      return "initialization callbacks; move form defaults outside the certified constructor" unless Comment._initialize_callbacks.empty?
      return "nonblank schema defaults; keep this form original" unless %w[commenter body].all? { Comment.column_defaults.fetch(_1).nil? }
      return "custom field types" unless holder.call(Comment.type_for_attribute("commenter")).equal?(ActiveModel::Type::String) &&
        holder.call(Comment.type_for_attribute("body")).equal?(ActiveRecord::Type::Text)
      return "custom model naming" unless [Article, Comment].all? { holder.call(_1.model_name).equal?(ActiveModel::Name) } &&
        [Article.model_name.singular_route_key, Article.model_name.route_key, Comment.model_name.param_key, Comment.model_name.route_key] ==
          %w[article articles comment comments]
      return "custom I18n backend" unless holder.call(I18n.backend).equal?(I18n::Backend::Simple)
      return "non-English build locale" unless I18n.locale == :en
      return "custom labels/translations; keep this form original" unless
        Comment.human_attribute_name(:commenter) == "Commenter" && Comment.human_attribute_name(:body) == "Body" &&
        %i[commenter body].all? { I18n.t("helpers.label.comment.#{_1}", default: nil).nil? }
      literal_translation = ->(value) do
        case value
        when nil then true
        when String then holder.call(value).equal?(String)
        when Hash then holder.call(value).equal?(Hash) && value.values.all? { literal_translation.call(_1) }
        else false # A Proc or Symbol alias is not proved pure by one lookup.
        end
      end
      return "dynamic label translations; use literal English labels or keep Rails" unless
        %w[helpers.label activerecord.attributes attributes].all? do |key|
          literal_translation.call(I18n.backend.send(:lookup, :en, key, [], resolve: false))
        end
      return "custom URL defaults" unless ArticlesController.default_url_options.empty? && Rails.application.routes.default_url_options.empty?
      return "custom polymorphic mappings" if %w[Array Article Comment].any? { Rails.application.routes.polymorphic_mappings.key?(_1) }

      tag = ActionView::Helpers::TagHelper
      return "custom literal escaping/tables" unless Sealed.literal_state? &&
        %w[for type name id rows value data-disable-with action accept-charset method].all? { tag::TAG_TYPES[_1].nil? }
      form = ActionView::Helpers::FormBuilder
      tags = ActionView::Helpers::Tags
      methods = {
        "view" => [ArticlesController.view_context_class, %i[form_with capture convert_to_model model_name_from_record_or_class
          instantiate_builder default_form_builder_class default_form_builder form_with_generates_ids
          form_with_generates_remote_forms default_enforce_utf8 prepend_content_exfiltration_prevention
          html_options_for_form_with html_options_for_form extra_tags_for_form
          form_tag_with_body form_tag_html label text_field text_area submit_tag label_tag content_tag tag token_tag
          field_name field_id set_default_disable_with safe_join prevent_content_exfiltration _object_for_form_builder
          polymorphic_path polymorphic_mapping _routes]],
        form.name => [form, %i[initialize label text_field text_area submit objectify_options convert_to_legacy_options multipart?]],
        tags::Base.name => [tags::Base, tags::Base.instance_methods(false) + tags::Base.private_instance_methods(false)],
        tags::Label.name => [tags::Label, tags::Label.instance_methods(false) + tags::Label.private_instance_methods(false)],
        tags::Label::LabelBuilder.name => [tags::Label::LabelBuilder, %i[initialize translation to_s]],
        tags::Translator.name => [tags::Translator, %i[initialize translate i18n_default human_attribute_name]],
        tags::TextField.name => [tags::TextField, %i[initialize render field_type]],
        tags::TextArea.name => [tags::TextArea, %i[initialize render]],
        tags::Placeholderable.name => [tags::Placeholderable, tags::Placeholderable.instance_methods(false) + tags::Placeholderable.private_instance_methods(false)],
        ActionView::Helpers::ActiveModelInstanceTag.name => [ActionView::Helpers::ActiveModelInstanceTag,
          %i[object content_tag tag error_wrapping error_message object_has_errors? select_markup_helper? tag_generate_errors?]],
        tag::TagBuilder.name => [tag::TagBuilder, %i[initialize content_tag_string tag_options tag_option]],
        ActionView::OutputBuffer.name => [ActionView::OutputBuffer, %i[capture to_s]],
        ActionView::Template.name => [ActionView::Template, %i[compile compile! encode! locals_code strict_locals!]],
        ActionView::Base.name => [ActionView::Base, %i[_run]],
        ActiveModel::Name.name => [ActiveModel::Name, %i[param_key route_key singular_route_key i18n_key]],
        ActiveModel::Errors.name => [ActiveModel::Errors, %i[empty?]],
        I18n::Backend::Simple.name => [I18n::Backend::Simple, %i[translate lookup resolve default interpolate]],
        I18n::Config.name => [I18n::Config, %i[locale default_locale backend owned_by?]],
        ActionView::I18nProxy.name => [ActionView::I18nProxy, %i[locale default_locale backend]],
        "Comment" => [Comment, %i[initialize errors persisted? to_model to_key model_name _read_attribute attribute_before_type_cast
          attribute_came_from_user? commenter body commenter_before_type_cast body_before_type_cast commenter_came_from_user? body_came_from_user?]],
        "Article" => [Article, %i[persisted? to_model to_param model_name]]
      }
      polymorphic = ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder
      methods[polymorphic.name] = [polymorphic, %i[initialize handle_list handle_model handle_class get_method_for_class get_method_for_string prefix suffix]]
      # Certify effective dispatch on each concrete tag, not only its base:
      # TextField#value overrides must not disappear behind Base#render.
      [tags::Label, tags::TextField, tags::TextArea].each do |type|
        methods.fetch(type.name).last.concat(methods.fetch(tags::Base.name).last +
          methods.fetch(ActionView::Helpers::ActiveModelInstanceTag.name).last + %i[tag_builder label_tag])
      end
      facts = {}
      compiler = ActionView::Template.instance_method(:compiled_source)
      # The link pass's generic template adapter leaves this form block live.
      # Check that adapter's body too, then certify the Rails compiler below it.
      if defined?(Templates::CompiledSource) && compiler.owner.equal?(Templates::CompiledSource)
        path, line = compiler.source_location
        expected = find(RubyVM::InstructionSequence.compile_file(File.join(__dir__, "templates.rb")), "compiled_source", line)
        return "custom Lowrail template compiler" unless expected && Sealed.signature(compiler, sequence: expected.to_a) == Sealed.signature(compiler)
        compiler = compiler.super_method
      end
      facts["template_compiler"] = stock_fact(compiler)
      return "custom template compiler" unless facts["template_compiler"]
      methods.each do |name, (type, names)|
        facts[name] = names.uniq.sort.to_h do |method_name|
          method = type.instance_method(method_name)
          fact = stock_fact(method)
          return "custom #{name}##{method_name}; keep this form original" unless fact
          [method_name.to_s, fact.merge("visibility" => Sealed.visibility(type, method_name))]
        end
      end
      {ArticlesController.view_context_class => %i[form_with capture label text_field text_area submit_tag field_name field_id],
        form => %i[label text_field text_area submit multipart?],
        tags::Label => %i[render], tags::TextField => %i[render], tags::TextArea => %i[render],
        Comment => %i[errors persisted? to_model to_key commenter body], Article => %i[persisted? to_model to_param]}.each do |type, names|
        return "non-stock public form visibility on #{type.name}" unless names.all? { type.public_method_defined?(_1) }
      end
      [form, tags::Label, tags::Label::LabelBuilder, tags::Translator, tags::TextField, tags::TextArea, tag::TagBuilder, Comment].each do |type|
        fact = stock_fact(type.method(:new))
        return "custom #{type.name}.new" unless fact && type.respond_to?(:new)
        facts["#{type.name}.new"] = fact
      end
      {Comment => %i[model_name human_attribute_name lookup_ancestors i18n_scope],
        Article => %i[model_name human_attribute_name lookup_ancestors i18n_scope],
        I18n => %i[t translate], tags::TextField => %i[field_type],
        ActionView::Base => %i[default_form_builder automatically_disable_submit_tag],
        ERB::Util => %i[unwrapped_html_escape xml_name_escape],
        polymorphic => %i[polymorphic_method get build plural new]}.each do |type, names|
        names.each do |method_name|
          method = type.method(method_name)
          fact = stock_fact(method)
          return "custom #{type.name}.#{method_name}" unless fact
          (facts["#{type.name}.singleton"] ||= {})[method_name.to_s] = fact
        end
      end
      return "custom text-field type cache" unless tags::TextField.field_type == "text"
      cached = polymorphic.get(nil, :path)
      fresh = polymorphic.build(nil, "path")
      key = cached.instance_variable_get(:@key_strategy)
      canonical_key = fresh.instance_variable_get(:@key_strategy)
      return "custom polymorphic path cache" unless holder.call(cached).equal?(polymorphic) &&
        cached.prefix == "" && cached.suffix == "path" && holder.call(key).equal?(Proc) &&
        RubyVM::InstructionSequence.of(key)&.to_a == RubyVM::InstructionSequence.of(canonical_key)&.to_a
      primitives = {Array => %i[each each_with_index map last first size == empty? join], Hash => %i[[] []= == each_pair fetch default default_proc stringify_keys transform_keys
        stringify_keys! deep_stringify_keys slice except merge merge! delete empty?], String => %i[to_s == html_safe html_safe? empty? gsub sub sub! end_with? humanize delete_suffix],
        Symbol => %i[to_s name], Object => %i[class instance_of? instance_variable_get respond_to?], Class => %i[new],
        Module => %i[class_variable_get], Proc => %i[source_location]}
      primitives.each do |type, names|
        facts[type.name] = names.to_h do |method_name|
          method = type.instance_method(method_name)
          fact = stock_fact(method)
          return "custom primitive #{type.name}##{method_name}" unless fact
          [method_name.to_s, fact]
        end
      end
      {"application_class" => Rails.application.class.name,
        "methods" => facts, "form_config" => {"ids" => true, "remote" => false, "utf8" => false},
        "columns" => %w[commenter body].to_h { [_1, [Comment.columns_hash.fetch(_1).sql_type, Comment.column_defaults.fetch(_1)]] }}
    rescue StandardError, ScriptError => error
      "inventory: #{error.class}: #{error.message.lines.first&.strip}"
    end

    # Only the completed activation may close this compiler. Requests use
    # the certified facts, never these temporary source trees. A later setup
    # must refuse rather than recertify by lazily compiling source again.
    def release
      @compiled = nil
      @released = true
    end

    def template(path)
      raise ArgumentError, "source inventory released; restart to recertify" if @released
      resolver = ArticlesController.view_paths.paths.find { _1.instance_of?(ActionView::FileSystemResolver) && path.start_with?("#{_1.path}/") }
      raise ArgumentError, "custom template resolver" unless resolver
      template = resolver.send(:build_unbound_template, path).bind_locals([])
      raise ArgumentError, "unknown strict locals" unless template.locals == [] && !template.strict_locals?
      handler = template.handler
      raise ArgumentError, "custom ERB handler" unless ObjectSpace.internal_class_of(handler).equal?(ActionView::Template::Handlers::ERB) && stock_fact(handler.method(:call))
      handler.call(template, template.send(:encode!))
    end

    def stock_fact(method)
      return nil if @released
      path, line = method.source_location
      sequence = RubyVM::InstructionSequence.of(method)
      if !path || path.start_with?("<internal:")
        return Sealed.signature(method) if !sequence && method.owner.equal?(ActionView::Helpers::FormHelper) &&
          method.original_name == :_default_form_builder
        return nil unless [Array, Hash, String, Symbol, Class, Module, Proc, Enumerable, Kernel, BasicObject, Object].include?(method.owner)
        # VM builtins serialize an ASLR-dependent C address. The pinned Ruby
        # executable owns these internal bodies; retain builtin name/index/
        # arity and all instructions, but not the process-local address.
        return runtime_fact(method)
      end
      return nil unless @roots.values.any? { path.start_with?(_1 + "/lib/") }
      unless sequence
        # The only folded Ruby-source C accessors in this inventory.
        return Sealed.signature(method) if ["ActionView::Helpers::FormBuilder", "ActionView::Helpers::Tags::Base"].include?(method.owner.name) &&
          %i[multipart object].include?(method.original_name)
        return Sealed.signature(method) if method.owner.equal?(ActiveModel::Name) &&
          %i[param_key route_key singular_route_key i18n_key].include?(method.original_name) && line == 11
        return Sealed.signature(method) if method.owner.equal?(ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder) &&
          %i[prefix suffix].include?(method.original_name) && line == 246
        return nil
      end
      root = (@compiled[path] ||= RubyVM::InstructionSequence.compile_file(path))
      expected = find(root, sequence.label, line)
      expected_array = expected&.to_a
      if expected_array && method.original_name == :tag_builder && method.owner.equal?(ActionView::Helpers::TagHelper) && Sealed::ACTIVE[0]
        # The separately certified link factory adds only its builder witness.
        # Sealed activation has already checked cold delivery; do not broadly
        # ignore non-stock factory bodies or learn them from this boot.
        delivery = Lowrail.manifest.units.find { _1["pass"] == Sealed::PASS }&.dig("sealed", "delivery", path)
        return Sealed.signature(method, sequence: expected_array) if delivery && Loader.served?(path) &&
          Sealed.signature(method) == delivery.fetch("signature")
      end
      unless expected
        source = generated_source(method)
        expected = find(RubyVM::InstructionSequence.compile("# frozen_string_literal: true\n#{source}", path, nil, line - 1), sequence.label, line) if source
        # CodeGenerator uses module_eval, whose ISeq has no absolute_path.
        # compile cannot produce that metadata; retain every instruction,
        # operand and source event while reproducing only this eval field.
        eval_paths = ->(value) do
          return value unless Array === value
          value = value.map { eval_paths.call(_1) }
          value[7] = nil if value.first == "YARVInstructionSequence/SimpleDataFormat"
          value
        end
        expected_array = eval_paths.call(expected.to_a) if expected
      end
      return nil unless expected_array && Sealed.signature(method, sequence: expected_array) == Sealed.signature(method)
      Sealed.signature(method)
    end

    # Compare an existing body to the independently audited build fact. This
    # never compiles or reads source. Builtin addresses vary with ASLR; retain
    # the same name/index/arity/instructions used by the build-only audit.
    def runtime_fact(method)
      builtin = ->(value) do
        case value
        when Array then value.map { builtin.call(_1) }
        when Hash then value.reject { |key, _| key == :func_ptr }.transform_values { builtin.call(_1) }
        else value
        end
      end
      Sealed.signature(method, sequence: builtin.call(RubyVM::InstructionSequence.of(method)&.to_a))
    end

    def find(sequence, label, line)
      return sequence if sequence.label == label && sequence.first_lineno == line
      result = nil
      sequence.each_child { result ||= find(_1, label, line) }
      result
    end

    def generated_source(method)
      name = method.original_name.to_s
      if [ActionView::Helpers::FormHelper, ActionView::Helpers::FormTagHelper,
          ActionView::Helpers::ContentExfiltrationPreventionHelper].include?(method.owner) &&
          %w[form_with_generates_ids form_with_generates_remote_forms default_enforce_utf8 prepend_content_exfiltration_prevention].include?(name)
        return "def #{name}; @@#{name}; end"
      end
      if Method === method && method.receiver.equal?(ActionView::Base) && %w[default_form_builder automatically_disable_submit_tag].include?(name)
        return "def self.#{name}; @@#{name}; end"
      end
      if method.owner.equal?(ActiveRecord::Base) && name == "model_name"
        return "def model_name(&); (self.class).model_name(&); end"
      end
      if method.owner.equal?(ActiveModel::Errors) && name == "empty?"
        return "def empty?(...); _ = @errors; _.empty?(...);rescue ::NoMethodError => e; if _.nil? && e.name == :empty?; ::Kernel.raise ::ActiveSupport::DelegationError.nil_target(:empty?, :'@errors'); else; ::Kernel.raise; end; end"
      end
      if method.owner.equal?(ActionView::Helpers::FormBuilder) && %w[text_field textarea].include?(name)
        return "def #{name}(method, options = {}); @template.#{name}(@object_name, method, objectify_options(options)); end"
      end
      return unless method.owner.equal?(Comment.send(:generated_attribute_methods))
      field, suffix = name.match(/\A(commenter|body)(_before_type_cast|_came_from_user\?)?\z/)&.captures
      return unless field
      expression = case suffix
      when nil then "_read_attribute(#{field.inspect}) { |n| missing_attribute(n, caller) }"
      when "_before_type_cast" then "attribute_before_type_cast(#{field.inspect})"
      when "_came_from_user?" then "attribute_came_from_user?(#{field.inspect})"
      end
      "def #{name}; #{expression}; end"
    end
  end
end
