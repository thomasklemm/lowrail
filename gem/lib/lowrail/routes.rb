# frozen_string_literal: true

module Lowrail
  # Runtime pieces of specialized named-route `*_path` helpers (see
  # docs/passes/route-helpers.md). Lowered code inlines what
  # ActionDispatch::Routing::RouteSet::NamedRouteCollection::UrlHelper::
  # OptimizedUrlHelper#call does for one route and calls these two methods for
  # the parts that depend on the call:
  #
  #   prefix: the script name `ActionDispatch::Http::URL.path_for` starts the
  #           path with, or nil when the url_options take a branch the
  #           specialization does not cover (the caller then calls the helper);
  #   seg:    Journey's segment escaping, skipping the gsub when nothing needs
  #           escaping.
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
