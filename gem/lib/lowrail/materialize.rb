# frozen_string_literal: true

module Lowrail
  # Forces the lazily generated surface of a booted Rails app into existence
  # before the facts dump (docs/PLAN.md 9.4): everything a test run or a
  # production process would build on first use. Each step is guarded,
  # timed, and measured as a delta of modules, methods and generated scripts,
  # so the facts show what each kind of laziness hides.
  #
  # Steps only call Rails' own entry points; none change app behavior beyond
  # what a first request (or production eager loading) would do. One step is
  # speculative and says so: relation delegation generates, for every app
  # class method of a model, the Relation method that Rails would generate on
  # the first call through a relation.
  module Materialize
    MOD_SINGLETON_P = Module.instance_method(:singleton_class?)
    MOD_NAME = Module.instance_method(:name)
    MOD_PUBLIC_IMS = Module.instance_method(:public_instance_methods)
    MOD_PROTECTED_IMS = Module.instance_method(:protected_instance_methods)
    MOD_PRIVATE_IMS = Module.instance_method(:private_instance_methods)
    MOD_INSTANCE_METHOD = Module.instance_method(:instance_method)

    STEPS = %w[
      eager_load
      production_eager_load
      models
      relation_delegation
      routes
      controllers
      middleware
      i18n
      templates
    ].freeze

    class << self
      attr_reader :results, :compiled_templates, :baseline

      # Runs +steps+ (default: all) and returns per-step results:
      #   {"step", "seconds", "modules", "methods", "scripts", "errors", "note"}
      # +record+ receives (where, exception) for every failure.
      # +before_step+ is called with each step name first (the facts
      # executable switches the script capture phase there).
      def run(steps: STEPS, app_root: nil, measure: true, record: nil, before_step: nil)
        @record = record
        @app_root = app_root
        @compiled_templates = []
        @results = []
        before = measure ? census : nil
        @baseline = before&.transform_keys(&:to_s)
        steps.each do |step|
          before_step&.call(step)
          @errors = 0
          @note = nil
          t0 = clock
          begin
            send(:"step_#{step}")
          rescue Exception => e # rubocop:disable Lint/RescueException
            raise if e.is_a?(Interrupt) || e.is_a?(SystemExit) || e.is_a?(NoMemoryError)
            fail_at("materialize #{step}", e)
          end
          seconds = clock - t0
          after = measure ? census : nil
          result = {"step" => step, "seconds" => seconds.round(3)}
          if measure
            result["modules"] = after[:modules] - before[:modules]
            result["methods"] = after[:methods] - before[:methods]
            result["scripts"] = after[:scripts] - before[:scripts]
            result["census_seconds"] = (clock - t0 - seconds).round(3)
          end
          result["errors"] = @errors
          result["note"] = @note if @note
          @results << result
          before = after
        end
        @results
      end

      # Counts every module (named, anonymous and singleton classes) and every
      # method defined directly in one.
      def census
        modules = 0
        methods = 0
        ObjectSpace.each_object(Module) do |mod|
          modules += 1
          methods += MOD_PUBLIC_IMS.bind_call(mod, false).size +
                     MOD_PROTECTED_IMS.bind_call(mod, false).size +
                     MOD_PRIVATE_IMS.bind_call(mod, false).size
        rescue Exception # rubocop:disable Lint/RescueException
          next
        end
        scripts = defined?(ScriptCapture) && ScriptCapture.started? ? ScriptCapture.compilations : 0
        {modules: modules, methods: methods, scripts: scripts}
      end

      # -- steps ------------------------------------------------------------

      # What `Rails.application.eager_load!` does: every Rails autoloader.
      def step_eager_load
        return note("no Rails application") unless rails_app
        ::Rails.application.eager_load!
      end

      # The rest of production's eager load (Rails::Application::Finisher):
      # every Zeitwerk loader (gems and engines too), Rails' own, and every
      # eager_load_namespace (the frameworks' eager_autoload lists).
      def step_production_eager_load
        return note("no Rails application") unless rails_app
        attempt("run_load_hooks(:before_eager_load)") { ::ActiveSupport.run_load_hooks(:before_eager_load, ::Rails.application) }
        attempt("Zeitwerk::Loader.eager_load_all") { ::Zeitwerk::Loader.eager_load_all } if defined?(::Zeitwerk::Loader)
        attempt("Rails.eager_load!") { ::Rails.eager_load! } if ::Rails.respond_to?(:eager_load!)
        ::Rails.application.config.eager_load_namespaces.each do |ns|
          attempt("#{label(ns)}.eager_load!") { ns.eager_load! }
        end
      end

      # Schema, attribute methods (including alias_attribute, enum, store and
      # normalizes attributes), association klasses and inverses.
      def step_models
        return note("no Active Record") unless defined?(::ActiveRecord::Base)
        each_model do |model, name|
          next if model.abstract_class?
          exists = attempt("model #{name} table_exists?") { model.table_exists? }
          next unless exists
          attempt("model #{name} load_schema") { model.load_schema }
          attempt("model #{name} define_attribute_methods") { model.define_attribute_methods }
          model.reflect_on_all_associations.each do |r|
            attempt("model #{name} association #{r.name} klass") { r.klass unless r.polymorphic? }
            attempt("model #{name} association #{r.name} inverse_of") { r.inverse_of unless r.polymorphic? }
          end
          attempt("model #{name} relation_delegate_class") { model.relation_delegate_class(::ActiveRecord::Relation) }
        end
      end

      # Speculative: Rails generates `Relation#name` for a model class method
      # on its first call through a relation (Delegation::ClassSpecificRelation
      # #method_missing). Generate it for every class method defined in app
      # source, which is the superset a test run can trigger.
      def step_relation_delegation
        return note("no Active Record") unless defined?(::ActiveRecord::Base) && @app_root
        generated = 0
        root = File.join(File.expand_path(@app_root), "")
        each_model do |model, name|
          next unless model.respond_to?(:generate_relation_method, true)
          sc = model.singleton_class
          MOD_PUBLIC_IMS.bind_call(sc, false).each do |meth|
            loc = MOD_INSTANCE_METHOD.bind_call(sc, meth).source_location
            next unless loc && loc[0].start_with?(root)
            next if ::ActiveRecord::Relation.method_defined?(meth)
            attempt("model #{name} generate_relation_method #{meth}") do
              model.send(:generate_relation_method, meth)
              generated += 1
            end
          end
        end
        note("speculative: #{generated} model class methods")
      end

      # Lazy route loading (Rails 8.0+ in test and development), then the
      # route set's url helper modules.
      def step_routes
        return note("no Rails application") unless rails_app
        app = ::Rails.application
        attempt("reload_routes_unless_loaded") { app.reload_routes_unless_loaded } if app.respond_to?(:reload_routes_unless_loaded)
        routes = app.routes
        attempt("routes.finalize!") { routes.finalize! } if routes.respond_to?(:finalize!)
        attempt("routes.url_helpers") { routes.url_helpers }
        attempt("routes.mounted_helpers") { routes.mounted_helpers }
        attempt("routes.named_routes") { routes.named_routes.helper_names }
      end

      # action_methods (memoized per class) and view_context_class (an
      # anonymous ActionView::Base subclass per controller with its helpers
      # and route helpers) for every controller and mailer.
      def step_controllers
        roots = []
        roots << ::ActionController::Base if defined?(::ActionController::Base)
        roots << ::ActionController::API if defined?(::ActionController::API)
        roots << ::ActionMailer::Base if defined?(::ActionMailer::Base)
        return note("no Action Pack") if roots.empty?
        n = 0
        roots.flat_map { |r| [r, *r.descendants] }.uniq.each do |c|
          name = MOD_NAME.bind_call(c)
          next unless name.is_a?(String)
          n += 1
          attempt("controller #{name} action_methods") { c.action_methods } unless c.abstract?
          attempt("controller #{name} view_context_class") { c.view_context_class } if c.respond_to?(:view_context_class)
        end
        note("#{n} controllers and mailers")
      end

      # The Rack middleware stack (built on the first request).
      def step_middleware
        return note("no Rails application") unless rails_app
        ::Rails.application.app
      end

      def step_i18n
        return note("no I18n") unless defined?(::I18n)
        if ::I18n.respond_to?(:eager_load!)
          ::I18n.eager_load!
        elsif ::I18n.backend.respond_to?(:eager_load!)
          ::I18n.backend.eager_load!
        end
      end

      # Compiles every template of every view path (the app's and engines')
      # into ActionView's real method container
      # (LookupContext::DetailsKey.view_context_class), so compiled template
      # methods and their generated source exist. Non-strict-locals
      # templates are compiled for an empty locals list; at runtime Rails
      # compiles one method per distinct locals set.
      def step_templates
        return note("no Action View") unless defined?(::ActionView::Template) && defined?(::ActionController::Base)
        container = view_container&.last or return note("no view_context_class")
        resolvers = ::ActionController::Base.view_paths.paths.dup
        resolvers.concat(::ActionMailer::Base.view_paths.paths) if defined?(::ActionMailer::Base)
        root = @app_root && File.join(File.expand_path(@app_root), "")
        seen = {}
        resolvers.each do |resolver|
          dir = resolver.respond_to?(:path) ? resolver.path.to_s : nil
          next unless dir && !seen[dir]
          seen[dir] = true
          Dir.glob("**/*", base: dir).sort.each do |rel|
            abs = File.join(dir, rel)
            next unless File.file?(abs)
            attempt("template #{abs}") do
              template = resolver.send(:build_unbound_template, abs).bind_locals([])
              template.send(:compile!, container)
              @compiled_templates << {"identifier" => abs, "method" => template.send(:method_name).to_s,
                                      "in_app" => root ? abs.start_with?(root) : nil}
            end
          end
        end
        note("#{@compiled_templates.size} templates")
      end

      # -- helpers ------------------------------------------------------------

      # [expression, class] of the anonymous ActionView::Base subclass that
      # holds compiled template methods (moved from DetailsKey to
      # LookupContext in Rails 8.2).
      def view_container
        if ::ActionView::LookupContext.respond_to?(:view_context_class)
          ["ActionView::LookupContext.view_context_class", ::ActionView::LookupContext.view_context_class]
        elsif defined?(::ActionView::LookupContext::DetailsKey) && ::ActionView::LookupContext::DetailsKey.respond_to?(:view_context_class)
          ["ActionView::LookupContext::DetailsKey.view_context_class", ::ActionView::LookupContext::DetailsKey.view_context_class]
        end
      end

      def each_model
        ::ActiveRecord::Base.descendants.each do |model|
          name = MOD_NAME.bind_call(model)
          next unless name.is_a?(String)
          yield model, name
        end
      end

      def rails_app
        defined?(::Rails.application) && ::Rails.application
      end

      def attempt(where)
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        raise if e.is_a?(Interrupt) || e.is_a?(SystemExit) || e.is_a?(NoMemoryError)
        fail_at(where, e)
        nil
      end

      def fail_at(where, err)
        @errors += 1
        @record&.call(where, err)
      end

      def note(msg)
        @note = msg
        nil
      end

      def label(mod)
        name = MOD_NAME.bind_call(mod)
        name.is_a?(String) ? name : mod.to_s
      rescue Exception # rubocop:disable Lint/RescueException
        "?"
      end

      def clock
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
