# frozen_string_literal: true

# P-MAP layer attribution for profile.rb's output. A sample belongs to the
# layer of its nearest Ruby frame (cfuncs and <internal:...> frames count for
# their caller), except that a leaf cfunc of a database driver, JSON, HTML
# escaping, digest/crypto or compression counts as that layer itself.
module PMapLayers
  LEAF = [
    [/\A(SQLite3|PG|Trilogy|Mysql2)::/, "AR: driver (C)"],
    [/\AJSON::/, "JSON"],
    [/\A(ERB::Escape|ERB::Util|CGI)\b|html_escape/, "AV: escaping"],
    [/\A(OpenSSL|Digest)::/, "Digest/crypto"],
    [/\AZlib::/, "Compression"],
  ].freeze

  AR = %r{/(?:activerecord|activemodel)/lib/}
  FILES = [
    [%r{/puma-\d[^/]*/}, "Puma"],
    [%r{/rack-\d[^/]*/lib/rack/(?:etag|conditional_get|head|sendfile|runtime|method_override|tempfile_reaper|static|content_length)\.rb}, "Middleware"],
    [%r{/rack-\d[^/]*/}, "Rack"],
    [%r{/(?:rack-session|rack-attack|rack-cors|rack-timeout|rack-proxy|warden|omniauth|propshaft|secure_headers|rack-protection)-\d}, "Middleware"],
    [%r{/actionpack/lib/action_dispatch/middleware/}, "Middleware"],
    [%r{/railties/lib/rails/}, "Middleware"],
    [%r{/activesupport/lib/active_support/(?:executor|reloader|execution_wrapper|current_attributes|isolated_execution_state|execution_context)}, "Middleware"],
    [%r{/actionpack/lib/action_dispatch/(?:routing|journey)}, "Routing"],
    [%r{/actionpack/lib/action_dispatch/}, "Request/response"],
    [%r{/(?:actionpack/lib/abstract_controller/callbacks|activesupport/lib/active_support/callbacks)\.rb}, "Callbacks"],
    [%r{/actionpack/lib/(?:action_controller|abstract_controller)/}, "Controller"],
    [%r{/activerecord/lib/active_record/connection_adapters/}, "AR: adapter (Ruby)"],
    [%r{/(?:sqlite3|pg|trilogy|mysql2)-\d[^/]*/}, "AR: driver (C)"],
    [%r{/activerecord/lib/(?:arel|active_record/(?:relation|associations/(?:association_scope|join_dependency|alias_tracker)|scoping|querying|sanitization|statement_cache|table_metadata|query_cache|query_logs))}, "AR: query building"],
    [%r{/activerecord/lib/active_record/(?:result|core|inheritance|model_schema|persistence|readonly_attributes)\.rb|/activemodel/lib/active_model/(?:attribute_set|attribute_set/|lazy_attribute)}, "AR: instantiate"],
    [%r{/activerecord/lib/active_record/associations}, "AR: associations"],
    [%r{/activerecord/lib/active_record/(?:transactions|callbacks|validations|autosave_association|timestamp|counter_cache|touch_later|locking|suppressor|attribute_methods/dirty|secure_token|normalization)|/activemodel/lib/active_model/(?:validations|validator|callbacks|dirty|attribute_mutation_tracker)}, "AR: write path"],
    [%r{/activemodel/lib/active_model/(?:type|attribute|attribute_methods|attribute_registration|attributes)|/activerecord/lib/active_record/(?:type|attribute_methods|attributes|enum|encryption|store)}, "AR: attributes/casting"],
    [AR, "AR: other"],
    [%r{/actionview/lib/action_view/(?:template/resolver|lookup_context|path_set|template_path|template_details|digestor|cache_expiry|unbound_template|template/types|dependency_tracker)}, "AV: lookup"],
    [%r{/actionview/lib/action_view/helpers/translation_helper}, "i18n"],
    [%r{/actionview/lib/action_view/helpers/}, "AV: helpers"],
    [%r{/activesupport/lib/active_support/core_ext/(?:string/output_safety|erb/util)}, "AV: escaping"],
    [%r{/actionview/lib/}, "AV: render"],
    [%r{/(?:jbuilder|active_model_serializers|jsonapi-renderer|jsonapi-serializer|blueprinter|alba|panko_serializer)-\d}, "Serializers (gems)"],
    [%r{/json-\d[^/]*/|/activesupport/lib/active_support/(?:json|core_ext/object/json)}, "JSON"],
    [%r{/i18n-\d|/rails-i18n-|/activesupport/lib/active_support/i18n}, "i18n"],
    [%r{/activesupport/lib/active_support/(?:notifications|log_subscriber|logger|broadcast_logger|tagged_logging|subscriber|structured_event|event_reporter)|/(?:actionpack|actionview|activerecord|activejob)/lib/[^/]+/(?:log_subscriber|structured_event_subscriber)|/(?:lograge|logger)-\d|/lib/ruby/[\d.]+/logger}, "Logging/instrumentation"],
    [%r{/activesupport/lib/active_support/cache|/(?:solid_cache|redis|redis-client|dalli|hiredis)-}, "Cache"],
    [%r{/tzinfo-|/activesupport/lib/active_support/(?:time_with_zone|values/time_zone|core_ext/(?:time|date|date_time))}, "Time/TZ"],
    [%r{/concurrent-ruby-}, "concurrent-ruby"],
    [%r{/activesupport/lib/}, "AS: other"],
    [%r{/zeitwerk-}, "AS: other"],
  ].freeze

  module_function

  # Layer of one stack (leaf first, [label, file, line] frames).
  def layer(frames, app_root)
    leaf = frames.first
    if leaf && leaf[1] == "<cfunc>"
      LEAF.each { |re, name| return name if leaf[0].match?(re) }
    end
    owner = frames.find { |_, file, _| file != "<cfunc>" && !file.start_with?("<internal:") }
    return "VM/cfunc only" unless owner
    file = owner[1]
    if file.start_with?(app_root)
      return file.include?("/app/views/") ? "App templates" : (file.include?("/vendor/") ? "Other gems" : "App code")
    end
    FILES.each do |re, name|
      next unless file.match?(re)
      return name unless name == "AR: instantiate" && file.include?("/persistence.rb") && !owner[0].include?("instantiate")
      return "AR: write path"
    end
    return "Ruby stdlib" if file.match?(%r{/lib/ruby/\d[\d.]*/}) && !file.include?("/gems/")
    "Other gems"
  end

  # Method a sample is charged to: nearest Ruby frame, plus the leaf cfunc.
  def site(frames)
    owner = frames.find { |_, file, _| file != "<cfunc>" && !file.start_with?("<internal:") }
    leaf = frames.first
    name = owner ? "#{owner[0]} (#{short(owner[1])}:#{owner[2]})" : "-"
    leaf && leaf[1] == "<cfunc>" ? "#{leaf[0]} ← #{name}" : name
  end

  def short(file) = file.sub(%r{.*/gems/rails-\h+/}, "").sub(%r{.*/gems/}, "").sub(%r{.*/\.corpus/[^/]+/}, "APP/")

  # A worker sample taken while the thread waits inside a request (database
  # wait with the GVL released) rather than for the next request.
  def in_request?(frames)
    frames.any? { |_, file, _| file.include?("/actionpack/lib/") || file.include?("/activerecord/lib/") }
  end
end
