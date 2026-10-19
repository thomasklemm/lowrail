# frozen_string_literal: true

require "json"
require_relative "routes"

module Lowrail
  # Build-time half of the route-helper pass, loaded only by
  # gem/exe/lowrail-oracle (a booted app). The Rust pass asks two things:
  #
  #   info(view, helper)  what Rails defined `helper` as, and the path it
  #                       produces for marker arguments (the template);
  #   probe(...)          whether the specialized expression the pass is about
  #                       to emit returns exactly what the real helper returns
  #                       (class, bytes, encoding, frozen?, or the same
  #                       exception) for a set of awkward arguments, in several
  #                       contexts (view and controller, with and without a
  #                       request, with a script name).
  #
  # Nothing here re-implements Journey: the template comes from calling the
  # helper, and every claim about escaping and argument handling is checked by
  # running the emitted code next to the original.
  module OracleRoutes
    MARKER = "LRHP%dQ"
    # Keys of route defaults that would change what path_for does after the
    # merge with url_options (see Lowrail::Routes.prefix).
    OPTION_KEYS = %i[trailing_slash original_script_name script_name params anchor path only_path].freeze

    class << self
      def info(view, helper)
        helper = helper.to_s
        named = Rails.application.routes.named_routes
        unless named.route_defined?(helper)
          return { kind: "none" }
        end
        kind = helper.end_with?("_url") ? "url" : "path"
        name = helper.delete_suffix("_#{kind}")
        route = named.get(name)
        return { kind: "custom", reason: "#{helper} is a direct/resolve helper (CustomUrlHelper)" } unless route
        meth = begin
          view.class.instance_method(helper)
        rescue NameError
          nil
        end
        owner_ok = meth && meth.owner.equal?(named.path_helpers_module)
        out = {
          kind: kind, name: name.to_s,
          spec: route.path.spec.to_s,
          parts: route.required_parts.map(&:to_s),
          defaults: route.defaults.inspect,
          option_defaults: (route.defaults.keys & OPTION_KEYS).map(&:to_s),
          optimized: route.path.requirements.empty? && !route.glob?,
          owner_ok: kind == "path" ? !!owner_ok : nil,
          source_location: meth&.source_location&.join(":"),
          visibility: visibility(view.class, helper)
        }
        if kind == "path" && out[:optimized] && owner_ok
          markers = route.required_parts.each_index.map { |i| format(MARKER, i) }
          prefix = Routes.prefix(view.url_options, view)
          full = view.public_send(helper, *markers)
          if prefix && full.start_with?(prefix)
            out[:template] = full.delete_prefix(prefix)
          else
            out[:template_error] = "could not split #{full.inspect} at the script name #{prefix.inspect}"
          end
        end
        out
      rescue StandardError => e
        { kind: "error", reason: "#{e.class}: #{e.message.lines.first&.chomp}" }
      end

      # temps: local names the expressions read; fast/original: Ruby source.
      # Returns {ok: true, runs: N} or {ok: false, reason: "..."}.
      def probe(contexts, temps, fast, original)
        runs = 0
        values = probe_values
        rows = []
        values.each { |v| temps.each_index { |i| rows << temps.each_index.map { |j| j == i ? v : "x" } } }
        values.each { |v| rows << temps.map { v } } if temps.size > 1
        rows << [] if temps.empty?
        contexts.each do |label, ctx|
          rows.each do |vals|
            want = run(ctx, temps, vals, original)
            have = run(ctx, temps, vals, fast)
            runs += 1
            next if want == have
            return { ok: false, reason: "#{label}, args #{vals.map { short(_1) }.join(", ")}: helper #{want.inspect[0, 160]} vs specialized #{have.inspect[0, 160]}" }
          end
        end
        { ok: true, runs: runs }
      end

      # [label, self] pairs: the oracle's default view (a TestRequest without
      # a route set, so url_options carry no script_name and
      # relative_url_root decides), and views and controllers of requests
      # routed through the app's route set, mounted at "" and at "/sub/".
      def contexts(controller_class)
        @contexts ||= {}
        @contexts[controller_class] ||= begin
          base = yield
          list = [["oracle view", base]]
          ["", "/sub/"].each do |script|
            next unless controller_class.method_defined?(:view_context)
            env = Rack::MockRequest.env_for("http://example.org/probe", "SCRIPT_NAME" => script)
            env["action_dispatch.routes"] = Rails.application.routes
            req = ActionDispatch::Request.new(env)
            c = controller_class.new
            c.set_request!(req)
            c.set_response!(controller_class.make_response!(req))
            list << ["view (script #{script.inspect})", c.view_context]
            list << ["controller (script #{script.inspect})", c]
          end
          list
        end
      end

      private

      def run(ctx, temps, vals, src)
        b = ctx.instance_eval { binding }
        temps.each_with_index { |t, i| b.local_variable_set(t.to_sym, vals[i]) }
        r = b.eval(src)
        [:ok, r.class.name, r.to_s.b, r.respond_to?(:encoding) ? r.encoding.name : nil, r.frozen?, r.respond_to?(:html_safe?) && r.html_safe?]
      rescue StandardError => e
        [:raise, e.class.name, e.message.gsub(/0x\h+/, "0x")]
      end

      def short(v)
        v.inspect[0, 40]
      rescue NoMethodError
        "#<BasicObject>"
      end

      def probe_values
        @probe_values ||= begin
          vals = [
            "LRHP0Q", "7", "a b/c?d#e%f.g&h=i+j;k,l:m@n~o!p$q'r(s)t*u<v>w\"x\\y|z[]{}^`",
            "café", "日本", "\xFF".b, (+"\xFF").force_encoding(Encoding::UTF_8), "a".encode(Encoding::US_ASCII),
            "x".encode(Encoding::UTF_16LE), "", " ", "-_.~", "..", "%2F", "x<y".html_safe, "frozen".freeze,
            42, 0, -1, 2**70, 1.5, nil, true, false, :sym, :"a/b", [1, "a/b"], [], {}, { format: :json },
            Object.new, BasicObject.new
          ]
          vals << ActionController::Parameters.new(a: 1) if defined?(ActionController::Parameters)
          vals.concat(records)
          vals
        end
      end

      # Instances of a few application models: persisted-looking (id 7, and a
      # string id), new (nil id: the helper raises).
      def records
        models = ActiveRecord::Base.descendants.reject(&:abstract_class?).select do |m|
          m.name && !m.name.start_with?("ActiveRecord::", "ActiveStorage::", "ActionText::", "ActionMailbox::", "SolidQueue::", "SolidCache::", "SolidCable::") &&
            m.primary_key.is_a?(String) && m.table_exists?
        rescue StandardError
          false
        end
        models.sort_by(&:name).first(3).flat_map do |m|
          [m.instantiate(m.primary_key => 7), m.new]
        rescue StandardError
          []
        end
      end

      def visibility(klass, name)
        if klass.public_method_defined?(name) then "public"
        elsif klass.protected_method_defined?(name) then "protected"
        elsif klass.private_method_defined?(name) then "private"
        end
      end
    end
  end
end
