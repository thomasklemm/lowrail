# frozen_string_literal: true

require "prism"
require_relative "manifest"
require_relative "sealed"
require_relative "templates"

module Lowrail
  module SealedBuild
    PASS = Sealed::PASS
    VIEW = %w[link_to convert_options_to_data_attributes url_target content_tag ensure_valid_html5_tag_name tag_builder].freeze
    BUILDER = %w[initialize content_tag_string tag_options tag_option].freeze
    # Independent Rails v8.1.4 source pins, not digests learned from the app's
    # potentially modified boot. Effective bodies must match these files too.
    STOCK = {
      "action_view/helpers/tag_helper.rb" => "7bca8efe1bd2421c5e65671aabdf35c97831ab0cb2cbdcdb5dd317d22aa16c31",
      "action_view/helpers/url_helper.rb" => "ebdccd38cf87f6f83d758ba424df61d72c8033629f0e70a8ddb21b7b8ed086ee",
      "action_controller/metal.rb" => "c8559e0a0c9e40ac9a29a4ae01de7c9aab7c438e1af751368e10e3802024cb36",
      "active_support/core_ext/object/blank.rb" => "203eefc5b094f4a0f5bf68b4c34198891127f52ed7825e146c2fa089a46f8ec7",
      "active_support/core_ext/erb/util.rb" => "1e348e9c8840caa9942691a290e0424c1755256b03a90eb96a094bbf86ff368f",
      "active_support/core_ext/string/output_safety.rb" => "8d8c461dbcd14db6b894671a1ec53b03c39637a67c27222e7d22bbe3c2f411d6"
    }.freeze

    class Calls < Prism::Visitor
      attr_reader :calls
      def initialize = @calls = []
      def visit_call_node(node)
        if node.name == :link_to && node.receiver.nil?
          @calls << node
        else
          super
        end
      end
    end

    module_function

    def method_fact(holder, name)
      {"signature" => Sealed.signature(holder.instance_method(name)), "visibility" => Sealed.visibility(holder, name)}
    end

    def stock?(method)
      path = method.source_location&.first
      pin = STOCK.find { |suffix, _| path&.end_with?("/lib/#{suffix}") }&.last
      pin && Digest::SHA256.file(path).hexdigest == pin &&
        Sealed.signature(method) == edited_signature(method, File.read(path))
    end

    def build(denied: [])
      ledger = []
      refuse = ->(reason) { {units: [], files: [], ledger: [{"pass" => PASS, "method" => "ArticlesController", "outcome" => reason}]} }
      return refuse.call("sealed pilot requires production Ruby 4.0.7 / Rails 8.1.4 blog") unless
        ENV["RAILS_ENV"] == "production" && RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      return refuse.call("denylisted by verify --bisect") if denied.any? { _1["pass"] == PASS }
      native = Lowrail.loaded_constant("Lowrail::Native")
      return refuse.call("Lowrail native actual-holder primitive unavailable; run rake compile; keep original") unless native
      exact_class = native.method(:exact_class?)
      return refuse.call("custom actual-holder primitive") unless exact_class.source_location.nil? &&
        exact_class.owner.equal?(native.singleton_class) && exact_class.original_name == :exact_class?
      native_file = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") }
      return refuse.call("native actual-holder binary unavailable") unless native_file
      controller = Lowrail.loaded_constant("ArticlesController")
      return refuse.call("eager-loaded ArticlesController required; keep lazy applications original") unless
        controller.is_a?(Class) && controller < ActionController::Base
      view_class = controller.view_context_class
      tag = ActionView::Helpers::TagHelper
      builder = tag::TagBuilder
      return refuse.call("custom view helper") unless VIEW.all? do |name|
        expected = %w[link_to convert_options_to_data_attributes url_target].include?(name) ? ActionView::Helpers::UrlHelper : tag
        view_class.instance_method(name).owner.equal?(expected)
      end
      return refuse.call("custom TagBuilder") unless BUILDER.all? { builder.instance_method(_1).owner.equal?(builder) } &&
        builder.method(:new).owner.equal?(Class) && builder.method(:new).source_location.nil?
      # Visibility is not encoded in a method-body ISeq. Do not learn an
      # app's private override as though it were the stock explicit send.
      return refuse.call("non-stock helper visibility") unless VIEW.all? do |name|
        expected = %w[convert_options_to_data_attributes url_target ensure_valid_html5_tag_name tag_builder].include?(name) ? "private" : "public"
        Sealed.visibility(view_class, name) == expected
      end && BUILDER.all? do |name|
        expected = %w[initialize tag_option].include?(name) ? "private" : "public"
        Sealed.visibility(builder, name) == expected
      end
      folded = VIEW.map { view_class.instance_method(_1) } + BUILDER.map { builder.instance_method(_1) }
      return refuse.call("non-stock helper body") unless folded.all? { stock?(_1) }
      # The source literals are folded, not arbitrary strings. Reject Ruby
      # primitive overrides at boot instead of treating their effects as pure.
      primitives = {String => %i[to_s empty? size == match? include? gsub],
        Hash => %i[each_pair empty? blank? [] size], Regexp => %i[match?]}
      return refuse.call("custom native primitive") unless primitives.all? do |holder, names|
        names.all? do |name|
          method = holder.instance_method(name)
          method.owner.equal?(holder) && method.source_location.nil? && Sealed.visibility(holder, name) == "public"
        end
      end
      ruby_primitives = [String.instance_method(:blank?), String.instance_method(:present?),
        String.instance_method(:html_safe?),
        ERB::Util.method(:xml_name_escape), ERB::Util.method(:unwrapped_html_escape)]
      return refuse.call("custom literal escaping/blankness") unless ruby_primitives.all? { stock?(_1) }
      return refuse.call("custom literal tables") unless Sealed.literal_state?(exact_class: exact_class)
      primitive_methods = primitives.flat_map do |holder, names|
        names.map { {"holder" => holder.name, "method" => _1.to_s, "signature" => Sealed.signature(holder.instance_method(_1))} }
      end
      primitive_methods << {"holder" => "Lowrail::Native", "singleton" => true,
        "method" => "exact_class?", "signature" => Sealed.signature(exact_class)}
      ruby_primitives.each do |method|
        singleton = Method === method
        primitive_methods << {"holder" => singleton ? "ERB::Util" : "String", "singleton" => singleton,
          "method" => method.name.to_s, "signature" => Sealed.signature(method)}
      end
      view_methods = VIEW.to_h { [_1, method_fact(view_class, _1)] }
      builder_methods = BUILDER.to_h { [_1, method_fact(builder, _1)] }
      templates = {}
      Dir[Rails.root.join("app/views/**/*.html.erb")].sort.each do |path|
        relative = path.delete_prefix("#{Rails.root}/app/views/").delete_suffix(".html.erb")
        local = File.basename(relative).delete_prefix("_") if File.basename(relative).start_with?("_")
        locals = local ? [local, "#{local}_counter", "#{local}_iteration"] : []
        resolver = controller.view_paths.paths.find { _1.instance_of?(ActionView::FileSystemResolver) && path.start_with?("#{_1.path}/") }
        unless resolver
          ledger << {"pass" => PASS, "file" => path, "outcome" => "custom template resolver"}
          next
        end
        template = resolver.send(:build_unbound_template, path).bind_locals(locals)
        handler = template.handler.call(template, template.send(:encode!))
        lowered, sites = lower(handler)
        ledger.concat(sites.map { {"pass" => PASS, "file" => path, **_1} })
        next unless sites.any? { _1["outcome"] == "lowered" }
        templates[path] = {"source_sha256" => Digest::SHA256.file(path).hexdigest,
          "original" => handler, "code" => lowered}
      rescue StandardError, ScriptError => error
        ledger << {"pass" => PASS, "file" => path, "outcome" => "template: #{error.class}: #{error.message.lines.first&.strip}"}
      end
      return {units: [], files: [], ledger: ledger} if templates.empty?

      factory = tag.instance_method(:tag_builder)
      factory_expression = "@tag_builder ||= TagBuilder.new(self)"
      replacement = "@tag_builder ||= (begin; __lowrail_builder = TagBuilder.new(self); if ::Ractor.current.equal?(::Ractor.main) && ::Lowrail::Sealed::ACTIVE[0]; ::Lowrail::Sealed::BUILDERS[__lowrail_builder] = true; end; __lowrail_builder; end)"
      factory_file = factory.source_location.first
      factory_source = File.read(factory_file)
      return refuse.call("stock factory changed") unless factory_source.scan(factory_expression).size == 1
      factory_code = factory_source.sub(factory_expression, replacement)
      expected_factory = edited_signature(factory, factory_code)
      view_methods["tag_builder"]["signature"] = expected_factory

      dispatch = controller.instance_method(:dispatch)
      return refuse.call("custom dispatch") unless dispatch.owner.equal?(ActionController::Metal) && stock?(dispatch)
      dispatch_file, dispatch_line = dispatch.source_location
      dispatch_source = File.read(dispatch_file)
      definition = find_definition(Prism.parse(dispatch_source).value, :dispatch, dispatch_line)
      return refuse.call("stock dispatch changed") unless definition && definition.body
      original = definition.location.slice
      prefix = "__lowrail_request_"
      prefix += "_" while original.include?(prefix)
      edited = original.dup
      # Keep original line count, parameters, owner and exception frames.
      first_line = edited.lines.first
      insertion = first_line.index(" #") || edited.index("\n")
      edited.insert(insertion, "; #{prefix}previous = ::Thread.current[::Lowrail::Sealed::REQUEST]; ::Thread.current[::Lowrail::Sealed::REQUEST] = ::Lowrail::Sealed.request_allowed?; begin")
      last_end = edited.rindex("end")
      edited.insert(last_end, "ensure; ::Thread.current[::Lowrail::Sealed::REQUEST] = #{prefix}previous; end; ")
      dispatch_code = dispatch_source.b.dup
      dispatch_code[definition.location.start_offset...definition.location.end_offset] = edited
      delivery = {
        factory_file => {"holder" => tag.name, "method" => "tag_builder", "signature" => expected_factory},
        dispatch_file => {"holder" => dispatch.owner.name, "method" => "dispatch", "signature" => edited_signature(dispatch, dispatch_code)}
      }
      files = [{path: factory_file, original: factory_source, parts: [factory_code]},
        {path: dispatch_file, original: dispatch_source, parts: [dispatch_code]}]
      sources = [__FILE__, File.join(__dir__, "sealed.rb"), File.join(__dir__, "templates.rb"), native_file,
        *VIEW.map { view_class.instance_method(_1).source_location&.first },
        *BUILDER.map { builder.instance_method(_1).source_location&.first },
        *ruby_primitives.map { _1.source_location.first }, dispatch_file,
        *Dir[Rails.root.join("{app,config,lib}/**/*.rb")], Rails.root.join("Gemfile.lock").to_s].compact.uniq
      unit = {"pass" => PASS, "kind" => "runtime", "target" => "ArticlesController", "facts" => [],
        "sites" => ledger.count { _1["outcome"] == "lowered" }, "sealed" => {
          "application_class" => Rails.application.class.name, "controller" => "ArticlesController",
          "view_methods" => view_methods, "builder_methods" => builder_methods,
          "primitive_methods" => primitive_methods,
          "constructor" => Sealed.signature(builder.method(:new)), "delivery" => delivery,
          "sources" => sources.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }, "templates" => templates}}
      ledger << {"pass" => "route/path", "method" => "sealed pilot", "outcome" => "complete residual unpriced; route generation remains live"}
      {units: [unit], files: files, ledger: ledger}
    end

    def find_definition(node, name, line)
      return node if Prism::DefNode === node && node.name == name && node.location.start_line == line
      node.compact_child_nodes.each do |child|
        found = find_definition(child, name, line)
        return found if found
      end
      nil
    end

    def edited_signature(original, source)
      path, line = original.source_location
      find = ->(iseq) do
        return iseq if iseq.label == original.original_name.to_s && iseq.first_lineno == line
        found = nil
        iseq.each_child { |child| found ||= find.call(child) }
        found
      end
      root = RubyVM::InstructionSequence.compile(source, path, path, 1)
      method = find.call(root) or raise "edited method absent: #{original.name}"
      Sealed.signature(original, sequence: method.to_a)
    end

    def lower(source)
      wrapper = "def __lowrail_view__;"
      parsed = Prism.parse("#{wrapper}#{source}\nend")
      return [source, [{"helper" => "link_to", "line" => 1, "outcome" => "unsupported compiled template"}]] unless parsed.success?
      visitor = Calls.new
      parsed.value.accept(visitor)
      output, sites = source.b.dup, []
      prefix = "__lowrail_sealed_"
      prefix += "_" while source.include?(prefix)
      visitor.calls.each_with_index.to_a.reverse_each do |node, index|
        args = node.arguments&.arguments || []
        name, target, options = args
        pair = if (Prism::KeywordHashNode === options || Prism::HashNode === options) && options.elements.size == 1
          options.elements.first
        end
        accepted = args.size == 3 && !node.block && Prism::StringNode === name &&
          args.none? { Prism::SplatNode === _1 || Prism::BlockArgumentNode === _1 || Prism::ForwardingArgumentsNode === _1 } &&
          Prism::AssocNode === pair && Prism::SymbolNode === pair.key && pair.key.unescaped == "class" && Prism::StringNode === pair.value
        unless accepted
          sites << {"helper" => "link_to", "line" => node.location.start_line, "outcome" => "requires literal name and single literal class option, no block/splat"}
          next
        end
        css = pair.value.unescaped
        head = "<a class=\"#{Html.attr(css)}\" href=\""
        tail = "#{Html.content(name.unescaped)}</a>"
        n, o, h, u = %w[name options html url].map { "#{prefix}#{index}_#{_1}" }
        render = "#{head.dump[0...-1]}\#{::Lowrail::Html.attr(#{u})}\\\">\#{::ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS[\"a\".freeze]}#{tail.dump[1..]}.html_safe"
        # Arguments first, once, before authorization. Local continuation after
        # conversion never invokes the original link_to a second time.
        replacement = "(begin; #{n} = #{name.location.slice}; #{o} = #{target.location.slice}; #{h} = {class: #{pair.value.location.slice}}; " \
          "if ::Lowrail::Sealed.view?(self); #{o} ||= {}; #{h} = convert_options_to_data_attributes(#{o}, #{h}); " \
          "#{u} = url_target(#{n}, #{o}); #{h}[\"href\"] ||= #{u}; " \
          "if ::Lowrail::Sealed.link?(self, #{u}, #{h}, #{css.dump}); " \
          "#{render}; " \
          "else; content_tag(\"a\", #{n}, #{h}); end; else; ::Lowrail::Sealed.count(false); link_to(#{n}, #{o}, #{h}); end; end)"
        # Literal newlines cannot shift any following source line.
        if replacement.include?("\n")
          sites << {"helper" => "link_to", "line" => node.location.start_line, "outcome" => "multiline specialization"}
          next
        end
        start = node.location.start_offset - wrapper.bytesize
        output[start...node.location.end_offset - wrapper.bytesize] = replacement.b
        sites << {"helper" => "link_to", "line" => node.location.start_line, "outcome" => "lowered"}
      end
      [output.force_encoding(source.encoding), sites]
    end
  end
end
