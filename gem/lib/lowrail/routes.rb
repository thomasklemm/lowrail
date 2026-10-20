# frozen_string_literal: true

module Lowrail
  # Runtime pieces of specialized named-route `*_path` helpers (see
  # docs/passes/route-helpers.md). Lowered code inlines what
  # ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper::
  # OptimizedUrlHelper#call does for one route and calls these methods for
  # the parts that depend on the call:
  #
  #   finish: Rails' dynamic script-name and URL assembly after path formatting;
  #   seg:    Journey's segment escaping, skipping the gsub when nothing needs
  #           escaping.
  # The build oracle uses prefix/url_prefix only to extract the path template;
  # new emitted code does not inline script-name or URL assembly.
  #
  # Loaded at setup, so this file must not touch Rails constants at load time.
  module Routes
    class << self
      # Mirrors, for `options = t.url_options.merge(route.defaults)` (the build
      # checked the defaults carry none of the keys below):
      #   path << "/" if options[:trailing_slash] ...
      #   original_script_name = options.delete(:original_script_name)
      #   script_name = options.delete(:script_name) || t._routes.relative_url_root || ""
      #   ActionDispatch::Http::URL.path_for: script_name.to_s.chomp("/") << path,
      #     plus params/anchor when those keys are present.
      # Any hash other than a plain Hash without defaults, and any of the keys
      # trailing_slash, original_script_name, params, anchor, returns nil.
      def prefix(o, t)
        return nil unless o.instance_of?(::Hash) && o.default_proc.nil? && o.default.nil?
        return nil if o.key?(:trailing_slash) || o.key?(:original_script_name) || o.key?(:params) || o.key?(:anchor)
        (o[:script_name] || t._routes.relative_url_root || "").to_s.chomp("/")
      end

      # For `*_url` helpers: OptimizedUrlHelper#call ends in
      # `ActionDispatch::Http::URL.url_for(options)`, which is path_for with
      # :only_path, else full_url_for: `build_host_url(host, port, protocol,
      # options, path_for(options))`. Returns what that builds for an empty
      # route path (the caller appends the path), or nil to take the helper.
      # build_host_url is Rails' own (private) method, so host/port/protocol,
      # subdomain/domain/tld_length and user/password follow Rails exactly.
      # Missing or non-String hosts and invalid protocols raise in Rails; here
      # they return nil, so the helper raises after evaluating to_param as
      # Rails does.
      def url_prefix(o, t)
        script = prefix(o, t) or return nil
        return script if o[:only_path]
        host = o[:host]
        return nil unless host.instance_of?(::String)
        ::ActionDispatch::Http::URL.send(:build_host_url, host, o[:port], o[:protocol], o, script)
      rescue ::ArgumentError
        nil
      end

      # Keep Rails' dynamic finishing step after argument conversion and path
      # formatting. Engines customize find_script_name on individual route sets;
      # an override may also mutate options used by the final URL strategy.
      def finish(path, options, target, url)
        path << "/" if options[:trailing_slash] && !path.end_with?("/")
        options[:path] = path
        original_script_name = options.delete(:original_script_name)
        script_name = target._routes.find_script_name(options)
        script_name = original_script_name + script_name if original_script_name
        options[:script_name] = script_name
        if url
          ::ActionDispatch::Http::URL.url_for(options)
        else
          ::ActionDispatch::Http::URL.path_for(options)
        end
      end

      # Journey::Router::Utils.escape_segment(p) is
      # `p.to_s.gsub(SEGMENT) { percent_encode }.force_encoding(US_ASCII)`.
      # An ASCII-only string without a character SEGMENT matches comes back
      # with the same bytes; the caller appends it to the path, so only the
      # bytes matter. Everything else goes through Rails.
      def seg(p)
        if p.ascii_only? && !p.match?(::ActionDispatch::Journey::Router::Utils::UriEncoder::SEGMENT)
          p
        else
          ::ActionDispatch::Journey::Router::Utils.escape_segment(p)
        end
      end
    end
  end
end
