# frozen_string_literal: true
# Prototype candidates, loaded after Rails when PATCH includes their letter.
patches = ENV.fetch("PATCH", "")

if patches.include?("A")
  # Errors#where: no errors, no type, plain attribute -> nothing to normalize or match.
  ActiveModel::Errors.prepend(Module.new do
    def where(attribute, type = nil, **options)
      return [] if type.nil? && @errors.empty? && (Symbol === attribute || attribute.instance_of?(String))
      super
    end
  end)
end

if patches.include?("B")
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

if patches.include?("C")
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

if patches.include?("D")
  ActionView::Helpers::Tags::Base.class_eval do
    private def sanitized_method_name
      @sanitized_method_name ||= @method_name.end_with?("?") ? @method_name.delete_suffix("?") : @method_name
    end
  end
end

if patches.include?("E")
  ActionView::Helpers::FormTagHelper.module_eval do
    def text_field_tag(name, value = nil, options = {})
      skip = ENV.fetch("PATCH", "").include?("S")
      html_options = { "type" => "text", "name" => name, "id" => (sanitize_to_id(name) unless skip), "value" => value }
      id_given = false
      options.each_pair do |key, val|
        key = Symbol === key ? key.name : key.to_s
        id_given = true if key == "id"
        html_options[key] = val
      end
      html_options["id"] = sanitize_to_id(name) if skip && !id_given
      tag :input, html_options
    end

    def hidden_field_tag(name, value = nil, options = {})
      html_options = options.dup
      html_options[:type] = :hidden
      unless ActionView::Base.remove_hidden_field_autocomplete
        html_options[:autocomplete] = "off" unless html_options.key?(:autocomplete)
      end
      text_field_tag(name, value, html_options)
    end

    private def sanitize_to_id(name)
      id = name.to_s.delete("]")
      id.tr!("^-a-zA-Z0-9:.", "_")
      id
    end
  end
end

if patches.include?("L")
  # Tags::Translator: drop the default key when it is the key already looked up.
  ActionView::Helpers::Tags::Translator.class_eval do
    private def i18n_default
      if model
        key = model.model_name.i18n_key
        key.name == object_name ? "" : ["#{key}.#{method_and_value}".to_sym, ""]
      else
        ""
      end
    end
  end
end

# N: small exact rewrites in the shared helpers, so callers keep calling hidden_field_tag.
if patches.include?("T")
  # tag: freeze before html_safe, as content_tag_string and self_closing_tag_string already do.
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
if patches.include?("Z")
  ActionView::Helpers::FormTagHelper.module_eval do
    private def sanitize_to_id(name)
      id = name.to_s.delete("]")
      id.tr!("^-a-zA-Z0-9:.", "_")
      id
    end
  end
end
if patches.include?("H")
  ActionView::Helpers::FormTagHelper.module_eval do
    def hidden_field_tag(name, value = nil, options = {})
      html_options = options.merge({ type: :hidden })
      unless ActionView::Base.remove_hidden_field_autocomplete
        html_options[:autocomplete] = "off" unless html_options.key?(:autocomplete)
      end
      text_field_tag(name, value, html_options)
    end
  end
end
if patches.include?("I")
  # text_field_tag computes the id only when the caller didn't pass one (the reviewer's suggestion).
  ActionView::Helpers::FormTagHelper.module_eval do
    def text_field_tag(name, value = nil, options = {})
      options = options.stringify_keys
      tag :input, { "type" => "text", "name" => name, "id" => (sanitize_to_id(name) unless options.key?("id")), "value" => value }.update(options)
    end
  end
end
if patches.include?("K")
  ActionView::Helpers::FormTagHelper.module_eval do
    def hidden_field_tag(name, value = nil, options = {})
      html_options = { **options, type: :hidden }
      unless ActionView::Base.remove_hidden_field_autocomplete
        html_options[:autocomplete] = "off" unless html_options.key?(:autocomplete)
      end
      text_field_tag(name, value, html_options)
    end
  end
end
if patches.include?("6")
  ActionView::Helpers::UrlHelper.module_eval do
    alias_method :__orig_hft, :hidden_field_tag
  end
end
