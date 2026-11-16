# frozen_string_literal: true
# Sweep candidates as prototypes, loaded after Rails; PATCH lists the names to switch on (comma-separated),
# PATCH=all switches on every candidate. Each one copies the method from Rails main a5203b3d4d and changes only
# what the README's table describes.
ALL_PATCHES = %w[O PH AMT B C D V SV CB HFT LT CBT ST OS LB TR DA T2 TB A AM]
# T is #59804's tag change (freeze before html_safe), for reference only: it ships elsewhere.
PATCHES = ENV.fetch("PATCH", "").split(",").flat_map { |p| p == "all" ? ALL_PATCHES : [p] }
unknown = PATCHES - ALL_PATCHES - %w[T]
raise "unknown candidates: #{unknown.join(", ")}" if unknown.any?
def patch?(name) = PATCHES.include?(name)

if patch?("O")
  # O: tag() and void elements write their attributes into the tag's own String, not a second one.
  ActionView::Helpers::TagHelper::TagBuilder.class_eval do
    def tag_options(options, escape = true) # :nodoc:
      return if options.blank?
      output = +""
      append_tag_options(output, options, escape)
      output unless output.empty?
    end

    def append_tag_options(output, options, escape) # :nodoc:
      sep    = " "
      options.each_pair do |key, value|
        next if key.blank?

        name = Symbol === key ? key.name : key.to_s
        next if name.blank?

        type = ActionView::Helpers::TagHelper::TAG_TYPES[key]
        if type != :aria && type != :class && value.is_a?(Hash)
          value.each_pair do |k, v|
            next if k.blank? || v.nil?

            nested_name = Symbol === k ? k.name : k.to_s
            next if nested_name.blank?

            output << sep
            append_prefix_tag_option(output, name, nested_name, v, escape)
          end
        elsif type == :aria && value.is_a?(Hash)
          value.each_pair do |k, v|
            next if k.blank? || v.nil?

            nested_name = Symbol === k ? k.name : k.to_s
            next if nested_name.blank?

            case v
            when Array, Hash
              tokens = ActionView::Helpers::TagHelper.build_tag_values(v)
              next if tokens.none?

              v = @view_context.safe_join(tokens, " ")
            else
              v = v.is_a?(Symbol) ? v.name : v.to_s
            end

            output << sep
            append_prefix_tag_option(output, name, nested_name, v, escape)
          end
        elsif type == :boolean
          if value
            output << sep
            if (String === value || Symbol === value) && (key == :hidden || key == "hidden")
              append_tag_option(output, name, value, escape)
            else
              append_boolean_tag_option(output, name)
            end
          end
        elsif !value.nil?
          output << sep
          append_tag_option(output, name, value, escape)
        end
      end
      output
    end

    private def self_closing_tag_string(name, options, escape = true, tag_suffix = " />")
      output = +"<#{name}"
      append_tag_options(output, options, escape) unless options.blank?
      output << tag_suffix
      output.freeze.html_safe
    end
  end
  ActionView::Helpers::TagHelper.module_eval do
    def tag(name = nil, options = nil, open = false, escape = true)
      if name.nil?
        tag_builder
      else
        ensure_valid_html5_tag_name(name)
        output = +"<#{name}"
        tag_builder.append_tag_options(output, options, escape) unless options.blank?
        output << (open ? ">" : " />")
        patch?("T") ? output.freeze.html_safe : output.html_safe
      end
    end
  end
end

if patch?("PH")
  # PH: Placeholderable forwards with (...) instead of collecting the arguments into an Array with (*).
  ActionView::Helpers::Tags::TextField # autoloads Placeholderable
  ActionView::Helpers::Tags::Placeholderable.module_eval do
    def initialize(...)
      super(...)

      if tag_value = @options[:placeholder]
        placeholder = tag_value if tag_value.is_a?(String)
        method_and_value = tag_value.is_a?(TrueClass) ? @method_name : "#{@method_name}.#{tag_value}"

        placeholder ||= ActionView::Helpers::Tags::Translator
          .new(object, @object_name, method_and_value, scope: "helpers.placeholder")
          .translate
        placeholder ||= @method_name.humanize
        @options[:placeholder] = placeholder
      end
    end
  end
end

if patch?("AMT")
  # AMT: ActiveModelInstanceTag#content_tag names content_tag's parameters instead of collecting them with *.
  ActionView::Helpers::ActiveModelInstanceTag.module_eval do
    def content_tag(type, content_or_options_with_block, options = nil, escape = true)
      select_markup_helper?(type) ? super : error_wrapping(super)
    end
  end
end

if patch?("B")
  # B: field_id leaves names that have nothing to replace as they are.
  ActionView::Helpers::FormTagHelper.module_eval do
    def field_id(object_name, method_name, *suffixes, index: nil, namespace: nil)
      if object_name.respond_to?(:model_name)
        object_name = object_name.model_name.singular
      end

      sanitized_object_name = object_name.to_s
      sanitized_object_name = sanitized_object_name.gsub(/\]\[|[^-a-zA-Z0-9:.]/, "_") if sanitized_object_name.match?(/[^-a-zA-Z0-9:._]/)
      sanitized_object_name = sanitized_object_name.delete_suffix("_") if sanitized_object_name.end_with?("_")

      sanitized_method_name = method_name.to_s
      sanitized_method_name = sanitized_method_name.delete_suffix("?") if sanitized_method_name.end_with?("?")

      [
        namespace,
        sanitized_object_name.presence,
        (index unless sanitized_object_name.empty?),
        sanitized_method_name,
        *suffixes,
      ].tap(&:compact!).join("_")
    end
  end
end

if patch?("C")
  # C: field_name skips map!.join when there are no extra names.
  ActionView::Helpers::FormTagHelper.module_eval do
    def field_name(object_name, method_name, *method_names, multiple: false, index: nil)
      names = method_names.empty? ? "" : method_names.map! { |name| "[#{name}]" }.join

      case
      when object_name.blank?
        "#{method_name}#{names}#{multiple ? "[]" : ""}"
      when index
        "#{object_name}[#{index}][#{method_name}]#{names}#{multiple ? "[]" : ""}"
      else
        "#{object_name}[#{method_name}]#{names}#{multiple ? "[]" : ""}"
      end
    end
  end
end

if patch?("D")
  # D: Tags::Base#sanitized_method_name copies the name only when it ends in "?".
  ActionView::Helpers::Tags::Base.class_eval do
    private def sanitized_method_name
      @sanitized_method_name ||= @method_name.end_with?("?") ? @method_name.delete_suffix("?") : @method_name
    end
  end
end

if patch?("V")
  # V: value_before_type_cast builds the "_before_type_cast" name only when the value came from the user.
  ActionView::Helpers::Tags::Base.class_eval do
    private def value_before_type_cast
      return unless object

      if value_came_from_user?
        method_before_type_cast = @method_name + "_before_type_cast"
        return object.public_send(method_before_type_cast) if object.respond_to?(method_before_type_cast)
      end

      value
    end
  end
end

if patch?("SV")
  # SV: sanitized_value edits its own copy in place instead of copying it three times.
  ActionView::Helpers::Tags::Base.class_eval do
    private def sanitized_value(value)
      sanitized = value.to_s.gsub(/[\s.]/, "_")
      sanitized.gsub!(/[^-[[:word:]]]/, "")
      sanitized.downcase!
      sanitized
    end
  end
end

if patch?("CB")
  # CB: CheckBox's hidden field sets type and value on its slice instead of merging a second Hash.
  ActionView::Helpers::Tags::CheckBox.class_eval do
    private def hidden_field_for_checkbox(options)
      if @unchecked_value
        tag_options = options.slice("name", "disabled", "form")
        tag_options["type"] = "hidden"
        tag_options["value"] = @unchecked_value
        tag_options["autocomplete"] = "off" unless ActionView::Base.remove_hidden_field_autocomplete
        tag("input", tag_options)
      else
        "".html_safe
      end
    end
  end
end

if patch?("HFT")
  # HFT: hidden_field_tag copies the options and sets type, instead of merging a second Hash.
  ActionView::Helpers::FormTagHelper.module_eval do
    def hidden_field_tag(name, value = nil, options = {})
      html_options = options.dup
      html_options[:type] = :hidden
      unless ActionView::Base.remove_hidden_field_autocomplete
        html_options[:autocomplete] = "off" unless html_options.key?(:autocomplete)
      end
      text_field_tag(name, value, html_options)
    end
  end
end

if patch?("LT")
  # LT: label_tag without options stringifies nothing.
  ActionView::Helpers::FormTagHelper.module_eval do
    def label_tag(name = nil, content_or_options = nil, options = nil, &block)
      if block_given? && content_or_options.is_a?(Hash)
        options = content_or_options = content_or_options.stringify_keys
      else
        options = options ? options.stringify_keys : {}
      end
      options["for"] = sanitize_to_id(name) unless name.blank? || options.has_key?("for")
      content_tag :label, content_or_options || name.to_s.humanize, options, &block
    end
  end
end

if patch?("CBT")
  # CBT: checkbox_tag destructures args instead of copying them into a new Array.
  ActionView::Helpers::FormTagHelper.module_eval do
    def checkbox_tag(name, *args)
      if args.length >= 4
        raise ArgumentError, "wrong number of arguments (given #{args.length + 1}, expected 1..4)"
      end
      options = args.extract_options!
      value, checked = args.empty? ? ["1", false] : args
      html_options = { "type" => "checkbox", "name" => name, "id" => sanitize_to_id(name), "value" => value }.update(options.stringify_keys)
      html_options["checked"] = "checked" if checked
      tag :input, html_options
    end
    alias_method :check_box_tag, :checkbox_tag
  end
end

if patch?("ST")
  # ST: set_default_disable_with builds the empty data Hash only when there is none.
  ActionView::Helpers::FormTagHelper.module_eval do
    private def set_default_disable_with(value, tag_options)
      data = tag_options.fetch("data") { {} }

      if tag_options["data-disable-with"] == false || data["disable_with"] == false
        data.delete("disable_with")
      elsif ActionView::Base.automatically_disable_submit_tag
        disable_with_text = tag_options["data-disable-with"]
        disable_with_text ||= data["disable_with"]
        disable_with_text ||= value.to_s.clone
        tag_options.deep_merge!("data" => { "disable_with" => disable_with_text })
      end

      tag_options.delete("data-disable-with")
    end
  end
end

if patch?("OS")
  # OS: options_for_select maps the fresh [selected, disabled] pair in place.
  ActionView::Helpers::FormOptionsHelper.module_eval do
    def options_for_select(container, selected = nil)
      return container if String === container

      selected, disabled = extract_selected_and_disabled(selected).map! do |r|
        Array(r).map(&:to_s)
      end

      output = +""
      container.each do |element|
        output << "\n" unless output.empty?

        if Array === element && element.any?(Hash)
          html_attributes = option_html_attributes(element)
          text, value = option_text_and_value(element).map(&:to_s)

          html_attributes[:selected] ||= option_value_selected?(value, selected)
          html_attributes[:disabled] ||= disabled && option_value_selected?(value, disabled)
          html_attributes[:value] = value

          output << tag_builder.option(text, **html_attributes)
        else
          # Same as option_text_and_value, without a pair Array per option.
          case element
          when String then text = value = element
          when Array then text, value = element.first, element.last
          else text, value = option_text_and_value(element)
          end
          value = value.to_s
          is_selected = option_value_selected?(value, selected)
          is_disabled = disabled && option_value_selected?(value, disabled)

          append_option_tag(output, text.to_s, value, is_selected, is_disabled)
        end
      end
      output.html_safe
    end
  end
end

if patch?("LB")
  # LB: Tags::Label builds its LabelBuilder only when the block or the translation needs it.
  ActionView::Helpers::Tags::Label.class_eval do
    def render(&block)
      options = @options.stringify_keys
      tag_value = options.delete("value")

      add_default_name_and_field_for_value(tag_value, options, "for")
      options.delete("index")
      options.delete("name")
      options.delete("namespace")

      content = if block_given?
        @template_object.capture(ActionView::Helpers::Tags::Label::LabelBuilder.new(@template_object, @object_name, @method_name, @object, tag_value), &block)
      elsif @content.present?
        @content.to_s
      else
        render_component(ActionView::Helpers::Tags::Label::LabelBuilder.new(@template_object, @object_name, @method_name, @object, tag_value))
      end

      label_tag(options["for"], content, options)
    end
  end
end

if patch?("TR")
  # TR: Translator copies the object name only when it has a nested-attributes index to rewrite.
  ActionView::Helpers::Tags::Translator.class_eval do
    def initialize(object, object_name, method_and_value, scope:)
      @object_name = object_name.include?("_attributes][") ? object_name.gsub(/\[(.*)_attributes\]\[\d+\]/, '.\1') : object_name
      @method_and_value = method_and_value
      @scope = scope
      @model = object.respond_to?(:to_model) ? object.to_model : nil
    end
  end
end

if patch?("DA")
  # DA: data-/aria- names skip dasherize when there is no underscore to replace.
  ActionView::Helpers::TagHelper::TagBuilder.class_eval do
    private def append_prefix_tag_option(output, prefix, key, value, escape)
      key = Symbol === key ? key.name : key.to_s
      key = "#{prefix}-#{key.include?("_") ? key.dasherize : key}"
      unless value.is_a?(String) || value.is_a?(Symbol) || value.is_a?(BigDecimal)
        value = value.to_json
      end
      append_tag_option(output, key, value, escape)
    end
  end
end

if patch?("T2")
  # T2 (parked lead, contributions.md): Array attribute values joined without safe_join's SafeBuffer.
  ActionView::Helpers::TagHelper::TagBuilder.class_eval do
    private def append_tag_option(output, key, value, escape)
      key = Symbol === key ? key.name : key.to_s
      key = ERB::Util.xml_name_escape(key) if escape

      case value
      when String
        value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
      when Array, Hash
        value = ActionView::Helpers::TagHelper.build_tag_values(value) if key == "class"
        value = escape ? value.flatten.map! { |v| ERB::Util.unwrapped_html_escape(v) }.join(" ") : value.join(" ")
      when Regexp
        value = escape ? ERB::Util.unwrapped_html_escape(value.source) : value.source
      when Symbol
        value = escape ? ERB::Util.unwrapped_html_escape(value.name) : value.name
      else
        value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
      end
      value = value.gsub('"', "&quot;") if value.include?('"')

      output << key
      output << "=\""
      output << value
      output << "\""
    end
  end
end

if patch?("TB")
  # TB: a Tags object uses its template's TagBuilder instead of building its own.
  ActionView::Helpers::Tags::Base.class_eval do
    private def tag_builder
      @template_object.tag
    end
  end
end

if patch?("A")
  # A (revisited): Errors#where returns [] when there are no errors, no type and no options, for a Symbol or
  # plain String attribute, the only attributes whose to_sym cannot raise or run app code.
  ActiveModel::Errors.prepend(Module.new do
    def where(attribute, type = nil, **options)
      return [] if @errors.empty? && type.nil? && options.empty? && (Symbol === attribute || attribute.instance_of?(String))
      super
    end
  end)
end

if patch?("AM")
  # AM: A one level up, in messages_for, which Errors#[] calls: no where, no keyword Hashes, no map.
  ActiveModel::Errors.prepend(Module.new do
    def messages_for(attribute, type = nil)
      return [] if @errors.empty? && type.nil? && (Symbol === attribute || attribute.instance_of?(String))
      super
    end
  end)
end

if patch?("T") && !patch?("O")
  ActionView::Helpers::TagHelper.module_eval do
    def tag(name = nil, options = nil, open = false, escape = true)
      if name.nil?
        tag_builder
      else
        ensure_valid_html5_tag_name(name)
        "<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ? ">" : " />"}".freeze.html_safe
      end
    end
  end
end
