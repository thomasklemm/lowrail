# frozen_string_literal: true

# Splits stackprof raw samples of a Rails request benchmark into the action,
# rendering, Active Record and the request scaffolding around them, then ranks
# scaffolding frames by self and total time.
#
#   ruby analyze.rb [--top N] [--json OUT] LABEL=DUMP ...
#
# A sample is in the request when its stack contains Rails::Engine#call (the
# benchmark's own env construction and cookie bookkeeping are "harness").
# Inside the request, the first matching rule wins, walking the stack:
#   render    - under a controller/view #render, #render_to_body, #default_render ...
#   action    - under BasicImplicitRender#send_action (the action body)
#   app/AR    - otherwise, the nearest library frame from the leaf (skipping
#               Ruby, Active Support and infrastructure gems) is the app,
#               Active Record/Model or an app gem (app filters, AR hooks)
#   scaffold  - everything else: middleware, routing, controller callbacks
#               and instrumentation, request/response, params, CSRF ...
# Self time folds C frames into their nearest Ruby caller ("self+C").
require "json"

top = 40
json_out = nil
args = ARGV.dup
while (a = args.first&.start_with?("--") && args.shift)
  case a
  when "--top" then top = Integer(args.shift)
  when "--json" then json_out = args.shift
  end
end

def lib_of(file)
  case file
  when %r{/(?:rails-wt/[^/]+|bundler/gems/rails-\h+)/(\w+)/lib/} then $1
  when %r{/gems/(rack|rack-session|rack-test)-[\d.]+/} then $1
  when %r{/gems/([a-z][\w-]*?)-\d[\w.]*/} then "gem:#{$1}"
  when %r{/benchmarks/[^/]+/|/\.corpus/census-[^/]+/(?!vendor/)} then "app"
  when "" then nil
  else "ruby"
  end
end

# Entry points of rendering. ActionView::Rendering#process wraps every action,
# so the actionview library alone does not mean rendering.
RENDER = /\A(AbstractController|ActionController|ActionView)::[\w:]+#(render|render_to_body|render_to_string|_render_template|default_render)\z/

APP_GEMS = %w[gem:sqlite3 gem:shipit gem:shipit-engine gem:octokit gem:commonmarker gem:redcarpet gem:kaminari].freeze

SCAFFOLD_LIBS = %w[actionpack rack rack-session activesupport railties].freeze

# Scaffold buckets: the leafmost frame whose file matches decides.
BUCKETS = [
  ["instrumentation", %r{active_support/(notifications|subscriber|log_subscriber|structured_event_subscriber|event_reporter)|action_controller/(log_subscriber|structured_event_subscriber)|action_controller/metal/instrumentation|active_support/benchmark}],
  ["params", %r{http/(parameters|param_builder|query_parser|filter_parameters)|metal/(strong_parameters|params_wrapper|parameter_encoding)|active_support/(parameter_filter|hash_with_indifferent_access)|rack/(query_parser|multipart)}],
  ["routing", %r{action_dispatch/(journey|routing)/}],
  ["csrf", %r{request_forgery_protection}],
  ["callbacks", %r{active_support/callbacks|abstract_controller/callbacks}],
  ["static files", %r{middleware/static}],
  ["etag/conditional get", %r{rack/(etag|conditional_get)|http/cache|metal/(conditional_get|etag_with)}],
  ["cookies/session/flash", %r{middleware/(cookies|session|flash)|http/session|rack/session|metal/flash|active_support/(message_|messages/|key_generator)}],
  ["request id", %r{middleware/request_id|securerandom}],
  ["logger", %r{rails/rack/logger|active_support/(tagged_logging|broadcast_logger|logger)|silence_request|/logger[\w.-]*/}],
  ["executor/reloader", %r{middleware/(executor|reloader|callbacks)|active_support/(execution_wrapper|executor|reloader|isolated_execution_state|execution_context|current_attributes)}],
  ["lookup context", %r{action_view/(lookup_context|view_paths|rendering)}],
  ["response", %r{http/response|action_controller/metal\.rb|metal/(default_headers|rendering|renderers)|rack/(response|headers|body_proxy|head)}],
  ["request", %r{http/(request|url|headers|mime_negotiation|mime_type)|rack/(request|utils|method_override)|rails/(engine|application)\.rb}],
  ["remote ip/ssl/host", %r{middleware/(remote_ip|ssl|assume_ssl|host_authorization)}],
  ["csp/permissions", %r{content_security_policy|permissions_policy}],
  ["exceptions", %r{middleware/(show_exceptions|debug_exceptions)}],
  ["controller dispatch", %r{abstract_controller/|action_controller/}],
  ["other rack", %r{/gems/rack[\w-]*-\d}],
].freeze

results = {}
args.each do |spec|
  label, path = spec.split("=", 2)
  d = Marshal.load(File.binread(path))
  frames = d[:frames]
  info = frames.transform_values { |f| [f[:name], f[:file].to_s, lib_of(f[:file].to_s)] }
  raw = d[:raw]
  cats = Hash.new(0)
  self_t = Hash.new(0)
  total_t = Hash.new(0)
  file_self = Hash.new(0)
  buckets = Hash.new(0)
  bucket_self = Hash.new(0)
  scaffold_n = 0
  req_n = 0
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    n = raw[i + 1 + len]
    i += len + 2
    names = stack.map { |f| info[f][0] }
    if names.first&.start_with?("(")
      cats["gc"] += n
      next
    end
    eng = names.index("Rails::Engine#call")
    unless eng
      cats["harness"] += n
      next
    end
    req_n += n
    sub = stack[eng..]
    cat = nil
    sub.each do |f|
      name = info[f][0]
      if RENDER.match?(name)
        cat = "render"
        break
      elsif name == "ActionController::BasicImplicitRender#send_action"
        cat = "action" # rendering may still follow (default_render)
      end
    end
    unless cat
      # Outside the action: the nearest library frame from the leaf decides,
      # skipping Ruby's own and infrastructure gems (logger, uri, ...).
      # Active Support is skipped too, so Notifications under an Active
      # Record query count as Active Record. Wrappers higher up the stack
      # (Active Record's ControllerRuntime#process_action) don't decide.
      owner = sub.reverse_each.map { |f| info[f][2] }.find { |l| l && !%w[ruby activesupport].include?(l) && (!l.start_with?("gem:") || APP_GEMS.include?(l)) }
      cat = %w[app activerecord activemodel].include?(owner) || APP_GEMS.include?(owner) ? "app/AR" : "scaffold"
    end
    cats[cat] += n
    next unless cat == "scaffold"

    scaffold_n += n
    # self+C: nearest Ruby frame from the leaf
    leaf = sub.reverse.find { |f| info[f][1] != "" && !info[f][1].start_with?("<") } || sub.last
    lname, lfile, llib = info[leaf]
    self_t[[lname, llib]] += n
    file_self[[lfile.sub(%r{.*/(rails-wt/[^/]+|rails-\h{12}|gems)/}, ""), llib]] += n
    sub.map { |f| [info[f][0], info[f][2]] }.uniq.each { |k| total_t[k] += n }
    bucket = nil
    sub.reverse_each do |f|
      file = info[f][1]
      next if file.empty?
      bucket = BUCKETS.find { |_, re| re.match?(file) }&.first
      break if bucket
    end
    buckets[bucket || "other"] += n
    bucket_self[[bucket || "other", lname, lfile.sub(%r{.*/(rails-wt/[^/]+|rails-\h{12}|gems)/}, "")]] += n
  end
  total = cats.values.sum
  results[label] = {
    samples: total, interval_us: d[:interval], mode: d[:mode],
    cats: cats.sort_by { -_2 }.to_h, req: req_n, scaffold: scaffold_n,
    buckets: buckets.sort_by { -_2 }.to_h,
    bucket_self: bucket_self.group_by { |(b, _, _), _| b }.transform_values { |v| v.sort_by { -_2 }.first(25).map { |(_, m, f), c| [m, f, c] } },
    self: self_t.sort_by { -_2 }.first(200).map { |(m, l), c| [m, l, c] },
    total: total_t.sort_by { -_2 }.first(300).map { |(m, l), c| [m, l, c] },
    files: file_self.sort_by { -_2 }.first(100).map { |(m, l), c| [m, l, c] },
  }
end

def pct(a, b) = b.zero? ? "-" : format("%.1f%%", 100.0 * a / b)

results.each do |label, r|
  puts "== #{label}: #{r[:samples]} samples (#{r[:mode]}, #{r[:interval_us]} us)"
  r[:cats].each { |c, n| puts format("  %-10s %7d  %6s of all  %6s of request", c, n, pct(n, r[:samples]), c == "gc" || c == "harness" ? "" : pct(n, r[:req])) }
  puts "  -- scaffold buckets (share of request samples)"
  r[:buckets].each { |b, n| puts format("  %6s  %s", pct(n, r[:req]), b) }
  puts "  -- scaffold self+C (share of request samples)"
  r[:self].first(top).each { |m, l, c| puts format("  %6s  %-12s %s", pct(c, r[:req]), l, m) }
  puts "  -- scaffold total (share of request samples), framework frames only"
  r[:total].select { |_, l, _| SCAFFOLD_LIBS.include?(l) }.first(top).each { |m, l, c| puts format("  %6s  %-12s %s", pct(c, r[:req]), l, m) }
end
File.write(json_out, JSON.pretty_generate(results)) if json_out
