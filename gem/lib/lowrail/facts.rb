# frozen_string_literal: true

require "json"

module Lowrail
  # Boot fact dumper. Walks every module in ObjectSpace and, when Rails is
  # loaded, the models, controllers and routes, and writes facts.json
  # (docs/FORMATS.md). Raw observations only: classification happens in Rust.
  #
  # Robustness rules: never call a method on an app object that the app may
  # have overridden (`name`, `respond_to?`, `method`, `inspect`, ...); bind the
  # core implementation instead. Every per-module, per-method, per-model and
  # per-controller step rescues and records the failure under "errors".
  module Facts
    FORMAT = 1

    MOD_NAME = Module.instance_method(:name)
    MOD_INSPECT = Module.instance_method(:to_s)
    MOD_ANCESTORS = Module.instance_method(:ancestors)
    MOD_SINGLETON_P = Module.instance_method(:singleton_class?)
    MOD_PUBLIC_IMS = Module.instance_method(:public_instance_methods)
    MOD_PROTECTED_IMS = Module.instance_method(:protected_instance_methods)
    MOD_PRIVATE_IMS = Module.instance_method(:private_instance_methods)
    MOD_INSTANCE_METHOD = Module.instance_method(:instance_method)
    MOD_CONST_SOURCE_LOCATION = Module.instance_method(:const_source_location)
    CLASS_SUPERCLASS = Class.instance_method(:superclass)
    CLASS_ATTACHED_OBJECT = Class.instance_method(:attached_object)
    KERNEL_SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
    KERNEL_IS_A = Kernel.instance_method(:is_a?)
    KERNEL_CLASS = Kernel.instance_method(:class)

    CALLBACK_KINDS = %w[initialize find touch validation validate save create update destroy commit rollback].freeze
    BLOCK_LABEL = /\A(?:rescue in |ensure in )*block(?: \(\d+ levels\))? in /

    class << self
      # ISeq => ScriptCapture::Script map used by method_entry ("script").
      attr_writer :script_index

      # Writes facts.json to +io_or_path+ (an IO or a file path; a path is
      # written atomically). Returns the facts hash.
      def dump(io_or_path, app_root: nil, timings: {}, generated_dir: nil)
        started = clock
        facts = collect(app_root: app_root, generated_dir: generated_dir)
        facts["timings"] = timings.transform_keys(&:to_s).merge("dump_seconds" => (clock - started).round(3)).sort.to_h
        json = JSON.generate(facts)
        if io_or_path.respond_to?(:write)
          io_or_path.write(json)
        else
          tmp = "#{io_or_path}.tmp#{Process.pid}"
          File.binwrite(tmp, json)
          File.rename(tmp, io_or_path)
        end
        facts
      end

      # Builds the facts hash (without timings).
      # Errors recorded before the call (e.g. by the executable) are kept.
      #
      # With Lowrail::ScriptCapture running, generated scripts are written to
      # +generated_dir+ (default: none written, index only) and methods
      # compiled inside one carry its digest ("script").
      def collect(app_root: nil, generated_dir: nil)
        @errors ||= []
        out = {}
        out["format"] = FORMAT
        out["ruby_description"] = RUBY_DESCRIPTION
        out["rails_version"] = defined?(::Rails.version) ? ::Rails.version.to_s : nil
        out["app_root"] = (app_root || rails_root || Dir.pwd).to_s
        out["yjit"] = yjit_enabled?
        out["gems"] = guard("gems") { gems } || []
        out["load_path_features"] = $LOADED_FEATURES.map { |f| str(f) }.sort
        # Models first: loading the schema and defining attribute methods
        # materializes the methods every test run sees after first use.
        out["models"] = guard("models") { models } || []
        out["controllers"] = guard("controllers") { controllers } || []
        out["routes"] = guard("routes") { routes } || []
        # Modules before templates: compiling templates autoloads handler
        # code (Erubi, Jbuilder, ...) that the boot itself did not load.
        @script_index = capture? ? ScriptCapture.iseq_index : nil
        mods, stats = modules
        out["template_config"] = guard("template_config") { template_config }
        out["templates"] = guard("templates") { templates(out["app_root"]) } || []
        out["module_stats"] = stats
        out["modules"] = mods
        if defined?(Materialize) && Materialize.results
          out["materialize"] = Materialize.results
          out["census_boot"] = Materialize.baseline if Materialize.baseline
          out["compiled_templates"] = Materialize.compiled_templates.sort_by { |t| t["identifier"] }
        end
        if capture?
          out["generated_scripts"] = guard("generated_scripts") { generated_scripts(generated_dir) } || []
          out["generated_stats"] = {
            "scripts" => ScriptCapture.count,
            "compilations" => ScriptCapture.compilations,
            "bytes" => ScriptCapture.compiled_bytes,
            "hook_seconds" => ScriptCapture.hook_seconds.round(3),
          }
        end
        @script_index = nil
        out["errors"] = @errors.sort_by { |e| [e["where"], e["error"]] }
        @errors = nil
        out
      end

      # -- modules and methods -------------------------------------------

      def modules
        stats = {"named" => 0, "anonymous" => 0, "anonymous_rooted" => 0, "singleton_classes" => 0, "methods" => 0}
        list = []
        named = []
        # Snapshot first: the walk creates singleton classes.
        ObjectSpace.each_object(Module).to_a.each do |mod|
          if MOD_SINGLETON_P.bind_call(mod)
            stats["singleton_classes"] += 1
            next
          end
          name = MOD_NAME.bind_call(mod)
          unless name.is_a?(String)
            stats["anonymous"] += 1
            next
          end
          if name.include?("#<") # e.g. "#<Class:0x...>::Config": nested in an anonymous module
            stats["anonymous_rooted"] += 1
            next
          end
          stats["named"] += 1
          named << [name, mod]
          entry = guard("module #{name}") { module_entry(mod, name) }
          next unless entry
          stats["methods"] += entry["methods"].size
          list << entry
        end
        synthetic_names(named).each do |name, mod|
          entry = guard("module #{name}") { module_entry(mod, name) }
          next unless entry
          entry["synthetic"] = true
          stats["methods"] += entry["methods"].size
          list << entry
        end
        list.sort_by! { |m| [m["name"], m["kind"], m["const_source_location"].to_s] }
        [list, stats]
      end

      # [[name, module]] for every anonymous module dumped under a synthetic
      # name. +named+: [[name, module]] of the named modules.
      def synthetic_names(named)
        synthetic = synthetic_modules
        synthetic + anonymous_ancestors(named, synthetic.map(&:last))
      end

      # Anonymous modules included into named ones hold generated methods
      # (enum methods, store accessors, has_secure_password's
      # InstanceMethodsOnActivation, Rails' own builders). Each is listed
      # once, under the first named module (by name) that includes it:
      # "Widget._enum_methods_module" for known Active Record holders, else
      # "Widget.ancestors[3]".
      KNOWN_HOLDERS = %i[_enum_methods_module _store_accessors_module].freeze

      def anonymous_ancestors(named, already = [])
        seen = {}.compare_by_identity
        already.each { |m| seen[m] = true }
        out = []
        named.sort_by!(&:first).each do |name, mod|
          ancestors = guard("#{name} ancestors") { MOD_ANCESTORS.bind_call(mod) } || []
          holders = nil
          ancestors.each_with_index do |anc, i|
            next if seen.key?(anc) || MOD_NAME.bind_call(anc).is_a?(String) || MOD_SINGLETON_P.bind_call(anc)
            seen[anc] = true
            holders ||= known_holders(mod)
            label = holders.find { |_, h| h.equal?(anc) }&.first
            out << [label ? "#{name}.#{label}" : "#{name}.ancestors[#{i}]", anc]
          end
        end
        out
      end

      def known_holders(mod)
        return [] unless defined?(::ActiveRecord::Base) && KERNEL_IS_A.bind_call(mod, Class) && mod < ::ActiveRecord::Base
        KNOWN_HOLDERS.filter_map do |h|
          ivar = :"@#{h}"
          [h.to_s, mod.instance_variable_get(ivar)] if mod.instance_variable_defined?(ivar)
        end
      rescue Exception # rubocop:disable Lint/RescueException
        []
      end

      # Anonymous modules that hold app-relevant generated methods, under
      # descriptive names: compiled templates and route helpers.
      def synthetic_modules
        out = []
        if defined?(::ActionView::LookupContext)
          require_relative "materialize"
          guard("synthetic view_context_class") do
            container = Materialize.view_container
            out << container if container
          end
        end
        if defined?(::Rails.application) && ::Rails.application
          guard("synthetic route helper modules") do
            named = ::Rails.application.routes.named_routes
            out << ["Rails.application.routes.named_routes.path_helpers_module", named.path_helpers_module]
            out << ["Rails.application.routes.named_routes.url_helpers_module", named.url_helpers_module]
          end
        end
        out.reject { |_, mod| MOD_NAME.bind_call(mod).is_a?(String) }
      end

      def module_entry(mod, name)
        name = str(name)
        is_class = KERNEL_IS_A.bind_call(mod, Class)
        entry = {"name" => name, "kind" => is_class ? "class" : "module"}
        entry["superclass"] = is_class ? mod_label(CLASS_SUPERCLASS.bind_call(mod)) : nil
        entry["ancestors"] = MOD_ANCESTORS.bind_call(mod).map { |a| mod_label(a) }
        sc = KERNEL_SINGLETON_CLASS.bind_call(mod)
        entry["singleton_ancestors"] = MOD_ANCESTORS.bind_call(sc).map { |a| mod_label(a) }
        entry["const_source_location"] = const_location(name)
        methods = own_methods(mod, name, false) + own_methods(sc, name, true)
        entry["methods"] = methods.sort_by { |m| [m["singleton"] ? 1 : 0, m["name"]] }
        entry
      end

      def own_methods(mod, mod_name, singleton)
        list = []
        {"public" => MOD_PUBLIC_IMS, "protected" => MOD_PROTECTED_IMS, "private" => MOD_PRIVATE_IMS}.each do |vis, um|
          names = guard("#{mod_name} #{singleton ? "." : "#"}#{vis}_instance_methods") { um.bind_call(mod, false) } || []
          names.each do |meth|
            m = guard("#{mod_name}#{singleton ? "." : "#"}#{meth}") { method_entry(mod, meth, vis, singleton) }
            list << m if m
          end
        end
        list
      end

      def method_entry(mod, meth, visibility, singleton)
        um = MOD_INSTANCE_METHOD.bind_call(mod, meth)
        loc = um.source_location
        iseq = RubyVM::InstructionSequence.of(um)
        entry = {
          "name" => str(meth),
          "singleton" => singleton,
          "visibility" => visibility,
          "owner" => mod_label(um.owner),
          "source_location" => loc ? "#{str(loc[0])}:#{loc[1]}" : nil,
          "parameters" => um.parameters.map { |p| p.map { |x| str(x) } },
          "iseq_kind" => iseq_kind(um, loc, iseq),
        }
        orig = um.original_name
        entry["original_name"] = str(orig) if orig != meth
        if iseq && @script_index && (script = @script_index[iseq])
          entry["script"] = ScriptCapture.digest(script)
        end
        entry
      end

      # method | block (define_method) | eval | cfunc | attr_reader | attr_writer | none
      def iseq_kind(um, loc, iseq = RubyVM::InstructionSequence.of(um))
        if iseq.nil?
          return "cfunc" if loc.nil?
          params = um.parameters
          return "attr_reader" if params.empty?
          return "attr_writer" if params.size == 1 && params[0][0] == :req
          return "none"
        end
        return "eval" if loc && loc[0].start_with?("(eval")
        label = iseq.label
        type =
          if label == um.original_name.to_s
            :method
          elsif BLOCK_LABEL.match?(label)
            :block
          else
            iseq.to_a[9]
          end
        case type
        when :method then "method"
        when :block then "block"
        when :eval then "eval"
        else type.to_s
        end
      end

      def const_location(name)
        return nil if name.start_with?("#")
        loc = MOD_CONST_SOURCE_LOCATION.bind_call(Object, name)
        loc && !loc.empty? ? "#{str(loc[0])}:#{loc[1]}" : nil
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      def mod_label(mod)
        return nil if nil.equal?(mod) # mod may be a BasicObject-like proxy
        name = MOD_NAME.bind_call(mod)
        return str(name).gsub(/0x\h+/, "0x") if name.is_a?(String)
        # Singleton classes print as #<Class:Article> (never via the attached
        # object's own #inspect); anonymous modules get their address
        # stripped so output stays deterministic.
        if MOD_SINGLETON_P.bind_call(mod)
          attached = CLASS_ATTACHED_OBJECT.bind_call(mod)
          inner = KERNEL_IS_A.bind_call(attached, Module) ? mod_label(attached) : "#<#{mod_label(KERNEL_CLASS.bind_call(attached))}>"
          return "#<Class:#{inner}>"
        end
        str(MOD_INSPECT.bind_call(mod)).gsub(/0x\h+/, "0x")
      end

      # -- Rails ----------------------------------------------------------

      def gems
        Gem.loaded_specs.values.map { |s| {"name" => s.name, "version" => s.version.to_s, "path" => str(s.full_gem_path)} }
          .sort_by { |g| g["name"] }
      end

      def models
        return [] unless defined?(::ActiveRecord::Base)
        list = []
        ::ActiveRecord::Base.descendants.each do |model|
          name = MOD_NAME.bind_call(model)
          next unless name.is_a?(String)
          entry = guard("model #{name}") { model_entry(model, name) }
          list << entry if entry
        end
        list.sort_by { |m| m["name"] }
      end

      def model_entry(model, name)
        return nil if model.abstract_class?
        table = model.table_name
        exists = begin
          model.table_exists?
        rescue Exception => e # rubocop:disable Lint/RescueException
          record("model #{name} table_exists?", e)
          false
        end
        unless exists
          record("model #{name}", "table #{table.inspect} does not exist", "skipped")
          return nil
        end
        model.load_schema
        defined_attrs = guard("model #{name} define_attribute_methods") { model.define_attribute_methods; true } || false
        column_names = model.columns.map(&:name)
        {
          "name" => str(name),
          "table" => str(table),
          "primary_key" => json_safe(model.primary_key),
          "attribute_methods_defined" => defined_attrs,
          "columns" => model.columns.map do |c|
            {"name" => c.name, "type" => c.type&.to_s, "sql_type" => c.sql_type, "null" => c.null, "default" => json_safe(c.default)}
          end,
          "attributes" => model.attribute_types.filter_map do |attr, type|
            next if column_names.include?(attr)
            {"name" => str(attr), "type" => json_safe(type.type)}
          end.sort_by { |a| a["name"] },
          "attribute_aliases" => json_safe(model.attribute_aliases),
          "associations" => model.reflect_on_all_associations.map { |r| association_entry(name, r) }.compact,
          "callbacks" => callbacks(model, "model #{name}"),
        }
      end

      def association_entry(model_name, r)
        guard("model #{model_name} association #{r.name}") do
          {
            "macro" => r.macro.to_s,
            "name" => r.name.to_s,
            "class_name" => (begin; r.class_name.to_s; rescue Exception; nil; end), # rubocop:disable Lint/RescueException
            "foreign_key" => (begin; json_safe(r.foreign_key); rescue Exception; nil; end), # rubocop:disable Lint/RescueException
            "options" => json_safe(r.options),
          }
        end
      end

      def callbacks(klass, where)
        out = {}
        CALLBACK_KINDS.each do |kind|
          reader = :"_#{kind}_callbacks"
          next unless klass.respond_to?(reader)
          chain = guard("#{where} #{reader}") { klass.public_send(reader) }
          next if chain.nil? || chain.empty?
          out[kind] = chain.map { |cb| callback_entry(cb) }
        end
        out
      end

      def callback_entry(cb)
        filter = cb.filter
        entry = {"kind" => cb.kind.to_s}
        case filter
        when Symbol, String
          entry["filter"] = filter.to_s
          entry["filter_type"] = "method"
        when Proc
          loc = filter.source_location
          entry["filter"] = loc ? "#{str(loc[0])}:#{loc[1]}" : "proc"
          entry["filter_type"] = "proc"
        else
          entry["filter"] = mod_label(KERNEL_CLASS.bind_call(filter))
          entry["filter_type"] = "object"
        end
        ifs = cb.instance_variable_get(:@if)
        unl = cb.instance_variable_get(:@unless)
        entry["conditions"] = (ifs.respond_to?(:empty?) && !ifs.empty?) || (unl.respond_to?(:empty?) && !unl.empty?)
        entry
      end

      def controllers
        return [] unless defined?(::ActionController::Base)
        roots = [::ActionController::Base]
        roots << ::ActionController::API if defined?(::ActionController::API)
        list = []
        roots.flat_map(&:descendants).uniq.each do |c|
          name = MOD_NAME.bind_call(c)
          next unless name.is_a?(String)
          entry = guard("controller #{name}") do
            abstract = c.abstract?
            {
              "name" => str(name),
              "abstract" => abstract,
              "actions" => abstract ? [] : c.action_methods.map(&:to_s).sort,
              "callbacks" => c._process_action_callbacks.map { |cb| callback_entry(cb) },
            }
          end
          list << entry if entry
        end
        list.sort_by { |c| c["name"] }
      end

      # Kept in route-set order: order is matching semantics.
      def routes
        return [] unless defined?(::Rails.application) && ::Rails.application
        ::Rails.application.routes.routes.map do |r|
          guard("route #{r.path.spec rescue "?"}") do
            app = r.app
            app = app.app if defined?(::ActionDispatch::Routing::Mapper::Constraints) && KERNEL_IS_A.bind_call(app, ::ActionDispatch::Routing::Mapper::Constraints)
            entry = {
              "verb" => r.verb.to_s,
              "path" => r.path.spec.to_s,
              "name" => r.name&.to_s,
              "controller" => r.defaults[:controller]&.to_s,
              "action" => r.defaults[:action]&.to_s,
            }
            unless defined?(::ActionDispatch::Routing::RouteSet::Dispatcher) && KERNEL_IS_A.bind_call(app, ::ActionDispatch::Routing::RouteSet::Dispatcher)
              klass = KERNEL_IS_A.bind_call(app, Module) ? app : KERNEL_CLASS.bind_call(app)
              entry["app"] = mod_label(klass)
              entry["engine"] = defined?(::Rails::Engine) && KERNEL_IS_A.bind_call(app, Class) && app < ::Rails::Engine ? true : false
            end
            entry["internal"] = true if r.respond_to?(:internal) && r.internal
            entry
          end
        end.compact
      end

      def template_config
        return nil unless defined?(::ActionView::Template)
        {
          "frozen_string_literal" => ::ActionView::Template.frozen_string_literal ? true : false,
          "annotate_rendered_view_with_filenames" => ::ActionView::Base.annotate_rendered_view_with_filenames ? true : false,
        }
      end

      # Every template file under the app's view paths (only paths under the
      # app root), with the handler output that ActionView::Template#compiled_source
      # wraps into a method (`code = @handler.call(self, source)`).
      def templates(app_root)
        return [] unless defined?(::ActionController::Base) && defined?(::ActionView::Template)
        root = File.join(File.expand_path(app_root), "")
        list = []
        ::ActionController::Base.view_paths.paths.each do |resolver|
          dir = resolver.respond_to?(:path) ? resolver.path.to_s : nil
          next unless dir && File.join(File.expand_path(dir), "").start_with?(root)
          Dir.glob("**/*", base: dir).sort.each do |rel|
            abs = File.join(dir, rel)
            next unless File.file?(abs)
            entry = guard("template #{abs}") { template_entry(resolver, abs) }
            list << entry if entry
          end
        end
        list.uniq { |t| t["identifier"] }.sort_by { |t| t["identifier"] }
      end

      def template_entry(resolver, abs)
        require "digest"
        template = resolver.send(:build_unbound_template, abs).bind_locals([])
        strict = template.send(:strict_locals!)
        source = template.send(:encode!)
        handler = template.handler
        code = handler.call(template, source)
        {
          "identifier" => str(template.identifier),
          "virtual_path" => template.virtual_path&.to_s,
          "format" => template.format&.to_s,
          "variant" => template.variant&.to_s,
          "handler" => KERNEL_IS_A.bind_call(handler, Module) ? mod_label(handler) : mod_label(KERNEL_CLASS.bind_call(handler)),
          "source_sha256" => Digest::SHA256.file(abs).hexdigest,
          "code" => str(code),
          "strict_locals" => strict&.to_s,
        }
      end

      # -- generated scripts ----------------------------------------------

      def capture?
        defined?(ScriptCapture) && ScriptCapture.started?
      end

      def generated_scripts(dir)
        label = ->(mod) { mod_label(mod) }
        entries =
          if dir
            ScriptCapture.write(dir, label: label)
          else
            ScriptCapture.list.map { |s| ScriptCapture.entry(s, ScriptCapture.digest(s), label) }
          end
        entries.each { |e| e.transform_values! { |v| v.is_a?(String) ? str(v) : v } }
        entries.sort_by { |e| [e["path"], e["lineno"], e["sha256"], e["module"].to_s, e["caller"].to_s] }
      end

      # -- helpers --------------------------------------------------------

      def rails_root
        ::Rails.root if defined?(::Rails.root)
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      def yjit_enabled?
        defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enabled?) ? RubyVM::YJIT.enabled? : false
      end

      def guard(where)
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise if e.is_a?(Interrupt) || e.is_a?(SystemExit) || e.is_a?(NoMemoryError)
        record(where, e)
        nil
      end

      def record(where, err, kind = "error")
        msg = err.is_a?(Exception) ? "#{KERNEL_CLASS.bind_call(err)}: #{err.message rescue "?"}".lines.first.to_s.chomp : err.to_s
        (@errors ||= []) << {"where" => str(where), "kind" => kind, "error" => str(msg)}
      end

      def str(x)
        s = x.to_s
        s = s.dup.force_encoding(Encoding::UTF_8) unless s.encoding == Encoding::UTF_8
        s.valid_encoding? ? s : s.scrub("?")
      end

      def json_safe(v)
        case v
        when nil, true, false, Integer then v
        when Float then v.finite? ? v : v.to_s
        when String, Symbol then str(v)
        when Array then v.map { |x| json_safe(x) }
        when Hash then v.to_h { |k, x| [str(k), json_safe(x)] }.sort.to_h
        when Proc
          loc = v.source_location
          loc ? "proc@#{str(loc[0])}:#{loc[1]}" : "proc"
        when Module then mod_label(v)
        else "#<#{mod_label(KERNEL_CLASS.bind_call(v))}>"
        end
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
