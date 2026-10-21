# frozen_string_literal: true

# Exploration only: framework-generated helper objects, never app source or
# app methods. This is NOT a Lowrail pass or a mutation/admission certificate.
module LobstersUrlProgram
  class << self
    attr_reader :helpers, :programs, :counts

    def discover
      @helpers = []
      base = ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper
      trace = TracePoint.new(:call) do |event|
        next unless event.method_id == :call && event.self.is_a?(base)
        @helpers << event.self unless @helpers.any? { _1.equal?(event.self) }
      end
      trace.enable { yield }
    ensure
      trace&.disable
    end

    def compile(coverage: false)
      @programs, @counts = [], Hash.new(0)
      generic = ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper.instance_method(:call)
      helpers.each do |helper|
        route = helper.instance_variable_get(:@route)
        path = route.path.spec.to_s.delete_suffix("(.:format)")
        # First bet: complete zero-segment path/root-URL programs. Dynamic
        # constrained tag/domain helpers remain the original Rails program.
        next unless route.required_parts.empty? && route.path.requirements.empty? && path.match?(%r{\A/[a-z_/]*\z})
        original = helper.method(:call)
        helper.instance_variable_set(:@lowrail_url_original, original)
        helper.instance_variable_set(:@lowrail_url_generic, generic)
        code = <<~RUBY
          def call(target, method_name, args, inner_options, strategy)
            unless args.empty? && (inner_options.nil? ||
                (#{helper.route_name.to_s == "root"} && inner_options.instance_of?(Hash) &&
                 (inner_options.keys - [:host, :protocol]).empty?))
              #{'LobstersUrlProgram.counts[:fallback] += 1' if coverage}
              return @lowrail_url_original.call(target, method_name, args, inner_options, strategy)
            end
            if inner_options.nil? && !target.send(:optimize_routes_generation?)
              #{'LobstersUrlProgram.counts[:fallback] += 1' if coverage}
              # Resume the original generic continuation, not the optimized
              # entry: do not evaluate the target's optimization predicate twice.
              return @lowrail_url_generic.bind_call(self, target, method_name, args, inner_options, strategy)
            end
            controller_options = target.url_options
            options = controller_options.merge(@options)
            if inner_options
              # The root URL shortcut is only for the actual empty-options
              # helper proxy. Reuse the already-evaluated options on refusal.
              unless controller_options.empty? && target._routes.default_url_options.empty?
                #{'LobstersUrlProgram.counts[:fallback] += 1' if coverage}
                return target._routes.url_for(options.merge(inner_options), @route_name, strategy, method_name)
              end
              options.merge!(inner_options)
            end
            path = +#{path.dump}
            path << "/" if options[:trailing_slash] && !path.end_with?("/")
            options[:path] = path
            original_script_name = options.delete(:original_script_name)
            script_name = target._routes.find_script_name(options)
            script_name = original_script_name + script_name if original_script_name
            options[:script_name] = script_name
            #{'LobstersUrlProgram.counts[:hit] += 1' if coverage}
            strategy.call(options)
          end
        RUBY
        helper.singleton_class.class_eval(code, __FILE__, __LINE__)
        @programs << {helper: helper, original: original, compiled: helper.method(:call),
          route: helper.route_name, path: path}
      end
    end

    def select(on)
      programs.each do |program|
        holder = program.fetch(:helper).singleton_class
        if on
          holder.define_method(:call, program.fetch(:compiled))
        elsif holder.instance_methods(false).include?(:call)
          holder.remove_method(:call)
        end
      end
    end
  end
end
