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
    # For `*_url` helpers route defaults with these keys would also change the
    # host part; decline them rather than reason about the merge.
    URL_KEYS = %i[host port protocol user password subdomain domain tld_length].freeze

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
        unless route
          # Diagnostics only: never execute an arbitrary application block to
          # guess a mapping. A finite sample cannot prove its other branches,
          # purity, Current reads or argument transformations.
          blocks = ObjectSpace.each_object(ActionDispatch::Routing::RouteSet::CustomUrlHelper).select { |h| h.name.to_s == name }
          detail = if blocks.one?
            block = blocks.first.block
            sends = RubyVM::InstructionSequence.of(block)&.disasm&.scan(/\bmid:([^,\s]+)/)&.flatten&.uniq || []
            " (#{block.source_location&.join(":")}; block sends: #{sends.join(", ")})"
          else
            " (block identity is not uniquely recoverable)"
          end
          return { kind: "custom", reason: "#{helper}: block-backed direct/resolve helper; result-helper and argument/option mapping are not guarded#{detail}" }
        end
        meth = begin
          view.class.instance_method(helper)
        rescue NameError
          nil
        end
        owner_ok = meth && meth.owner.equal?(kind == "url" ? named.url_helpers_module : named.path_helpers_module)
        out = {
          kind: kind, name: name.to_s,
          spec: route.path.spec.to_s,
          parts: route.required_parts.map(&:to_s),
          defaults: route.defaults.inspect,
          option_defaults: (route.defaults.keys & (kind == "url" ? OPTION_KEYS + URL_KEYS : OPTION_KEYS)).map(&:to_s),
          optimized: route.path.requirements.empty? && !route.path.spec.to_s.include?("*"),
          owner_ok: !!owner_ok,
          source_location: meth&.source_location&.join(":"),
          visibility: visibility(view.class, helper)
        }
        if out[:optimized] && owner_ok
          markers = route.required_parts.each_index.map { |i| format(MARKER, i) }
          prefix = kind == "url" ? Routes.url_prefix(view.url_options, view) : Routes.prefix(view.url_options, view)
          full = view.public_send(helper, *markers)
          if prefix && full.start_with?(prefix)
            out[:template] = full.delete_prefix(prefix)
          else
            out[:template_error] = "could not split #{full.inspect} at the #{kind == "url" ? "URL prefix" : "script name"} #{prefix.inspect}"
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
          # Warm the same request cache, then vary inputs without allocating
          # a new context. App url_options overrides must still run per call.
          varied = ctx.clone
          options = ctx.url_options.dup
          varied.define_singleton_method(:url_options) { options }
          vals = temps.map { "x" }
          changes = [
            { host: +"one.example.org", protocol: "https://", port: 8443, script_name: +"/first/" },
            { host: "two.example.net", protocol: "http://", port: 8080, script_name: "/second/" },
            { subdomain: "api", domain: "other.co.uk", tld_length: 2 },
            { user: "a b", password: "c@d" }, { only_path: true }, { only_path: false },
            { anchor: nil }, { anchor: "part" }, { params: { q: "a b" } },
            { original_script_name: "/outer" }, { trailing_slash: false }
          ]
          changes.each do |change|
            options.replace(ctx.url_options.merge(change).transform_values { |v| v.instance_of?(String) ? v.dup : v })
            2.times do
              want = run(varied, temps, vals, original)
              have = run(varied, temps, vals, fast)
              runs += 1
              return { ok: false, reason: "#{label}, changing url_options #{change.keys}: helper #{want.inspect} vs specialized #{have.inspect}" } unless want == have
              # In-place changes must not mutate the stored cache key.
              options[:host].replace("changed.example.com") if options[:host].instance_of?(String) && !options[:host].frozen?
              options[:script_name].replace("/changed/") if options[:script_name].instance_of?(String) && !options[:script_name].frozen?
            end
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
          [["http://example.org/probe", ""], ["http://example.org/probe", "/sub/"], ["https://user.example.co.uk:8443/probe", ""]].each do |url, script|
            next unless controller_class.method_defined?(:view_context)
            env = Rack::MockRequest.env_for(url, "SCRIPT_NAME" => script)
            env["action_dispatch.routes"] = Rails.application.routes
            req = ActionDispatch::Request.new(env)
            c = controller_class.new
            c.set_request!(req)
            c.set_response!(controller_class.make_response!(req))
            list << ["view (#{url}, script #{script.inspect})", c.view_context]
            list << ["controller (#{url}, script #{script.inspect})", c]
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
