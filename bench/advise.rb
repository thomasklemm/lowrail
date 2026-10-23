# frozen_string_literal: true

# Resolve the profiler before Bundler hides tools outside the app's lock, but
# activate default gems only after the app selects its own locked versions.
$LOAD_PATH.unshift(*Gem::Specification.find_by_name("stackprof").full_require_paths)
if $PROGRAM_NAME == __FILE__ && ARGV.first && !ARGV.first.start_with?("-")
  ENV["RAILS_ENV"] ||= "production"
  ENV["RACK_ENV"] ||= ENV.fetch("RAILS_ENV")
  require File.expand_path("config/boot", ARGV.first)
end

require "optparse"
require "json"
require "digest"
require_relative "profile_summary"
require_relative "allocation_census"
require_relative "jit_stability"
require_relative "../gem/lib/lowrail/observe"

# Advice is discovery, not a purity proof, a removable budget or a speed claim.
module Advise
  CLASS = Kernel.instance_method(:class)
  Sample = Struct.new(:record, :input, :tainted)

  # Only copy bounded, exact core scalars; never call app hash/inspect/==.
  # Do not serialize the values, receiver identities, cookies or job arguments.
  def self.scalar(value)
    klass = CLASS.bind_call(value)
    return [klass.name, value] if [NilClass, TrueClass, FalseClass, Integer, Symbol].include?(klass)
    return ["String", String.new(value).freeze] if klass == String && value.bytesize <= 128
    nil
  end

  # Discovery only: exact statement/bind identity within one operation and
  # connection. Any non-SELECT is a barrier, not a guessed-safe intervening
  # write. These are leads, not SQL purity proofs or permission to drop reads.
  def self.sql(n, root:, &work)
    return nil unless defined?(ActiveSupport::Notifications)
    rows = {}
    seen = {}
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      event = args.last
      statement = event.fetch(:sql)
      binds = event[:binds]&.map { [_1.name, _1.value_for_database] }
      signature = Digest::SHA256.hexdigest(Marshal.dump([statement, binds]))
      connection = event[:connection]&.object_id
      prior = (seen[connection] ||= {})
      read = statement.match?(/\ASELECT\b/i) && !statement.match?(/\b(?:FOR\s+(?:UPDATE|SHARE|NO\s+KEY|KEY\s+SHARE)|LOCK)\b/i)
      duplicate = read && prior.key?(signature)
      read ? prior[signature] = true : seen.clear
      row = rows[signature] ||= { statement: statement,
        binds_sha256: Digest::SHA256.hexdigest(Marshal.dump(binds)),
        calls: 0, cached_hits: 0, round_trips: 0, duplicate_round_trips: 0, duplicate_cached_hits: 0,
        callsite: caller_locations.find { Lowrail::Observe.source_path?(_1.path, root: root) }&.then {
          { file: _1.path.delete_prefix(root), line: _1.lineno } } }
      row[:calls] += 1
      row[event[:cached] ? :cached_hits : :round_trips] += 1
      row[event[:cached] ? :duplicate_cached_hits : :duplicate_round_trips] += 1 if duplicate
    end
    n.times { seen.clear; work.call }
    { operations: n, ranking: "duplicate real round trips only; CACHE hits never contribute",
      events: rows.values.sort_by { [-_1[:duplicate_round_trips], -_1[:round_trips], _1[:statement]] } }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def self.calls(n, root:, &work)
    records = {}
    active = {}
    trace = TracePoint.new(:call, :return, :raise) do |event|
      fiber = Fiber.current
      if event.event == :raise
        active[fiber]&.each { _1.tainted = true }
        next
      end
      next unless Lowrail::Observe.source_path?(event.path, root: root)
      key = [event.path, event.defined_class, event.method_id]
      if event.event == :call
        rec = records[key] ||= { file: event.path, line: event.lineno,
          method: "#{Lowrail::Observe.label(event.defined_class)}##{event.method_id}", calls: 0,
          sampled: 0, comparable: 0, repeated: 0, changed: 0, tainted: 0,
          receivers: {}.compare_by_identity }
        rec[:calls] += 1
        input = nil
        if rec[:sampled] < 32
          rec[:sampled] += 1
          params = event.parameters
          if params.all? { |kind, name| name && %i[req opt key keyreq].include?(kind) }
            values = params.map { |_, name| scalar(event.binding.local_variable_get(name)) }
            input = values if values.all?
          end
        end
        (active[fiber] ||= []) << Sample.new(rec, input, false)
      else
        frames = active[fiber]
        rec = records[key]
        index = frames&.rindex { _1.record.equal?(rec) }
        next unless index
        frame = frames.delete_at(index)
        active.delete(fiber) if frames.empty?
        if frame.tainted
          rec[:tainted] += 1
        elsif frame.input && (result = scalar(event.return_value))
          rec[:comparable] += 1
          seen = rec[:receivers][event.self] ||= {}
          if seen.key?(frame.input)
            rec[seen[frame.input] == result ? :repeated : :changed] += 1
          end
          seen[frame.input] = result
        end
      end
    end
    trace.enable { n.times { work.call } }
    records.values.map { _1.reject { |key, _| key == :receivers } }
  ensure
    trace&.disable
  end

  def self.capture(work, root:, warmup: 50, requests: 200, census: 5)
    root = File.join(File.expand_path(root), "")
    RubyVM::YJIT.enable unless RubyVM::YJIT.enabled?
    warmup.times { work.call }
    require "stackprof"
    jit_before = JitStability.snapshot
    profile = JSON.parse(JSON.generate(StackProf.run(mode: :cpu, interval: 100, raw: true) {
      requests.times { work.call }
    }))
    jit_after = JitStability.snapshot
    # Global TracePoint can permanently change YJIT execution. Collect CPU and
    # allocations first, and CLI workloads each get their own untraced child.
    queries = sql(census, root: root, &work)
    allocations = AllocationCensus.capture(census, &work)
    counts = calls(census, root: root, &work)
    summary = ProfileSummary.counts(profile, root)
    files = {}
    row = ->(file) { files[file] ||= { file: file.delete_prefix(root), self_samples: 0,
      inclusive_samples: 0, allocations_per_operation: 0.0, cpu_frames: [], methods: [], allocation_sites: [] } }
    { self_by_file: :self_samples, inclusive_by_file: :inclusive_samples }.each do |metric, field|
      summary.fetch(metric).each do |file, count|
        row.call(file)[field] = count if Lowrail::Observe.source_path?(file, root: root)
      end
    end
    profile.fetch("frames").each do |id, frame|
      next unless Lowrail::Observe.source_path?(frame["file"].to_s, root: root)
      # A controller's inclusive share is not the ceiling of one small helper.
      row.call(frame["file"])[:cpu_frames] << {
        method: frame["name"], line: frame["line"], self_samples: summary[:self][id.to_i],
        inclusive_samples: summary[:inclusive][id.to_i] }
    end
    counts.each do |method|
      method[:calls_per_operation] = method.fetch(:calls).fdiv(census)
      row.call(method.fetch(:file))[:methods] << method.reject { |key, _| key == :file }
    end
    allocations.fetch(:callsites).each do |site|
      next unless Lowrail::Observe.source_path?(site.fetch(:file), root: root)
      file = row.call(site.fetch(:file))
      file[:allocations_per_operation] += site.fetch(:allocated).fdiv(census)
      file[:allocation_sites] << site.reject { |key, _| key == :file }
    end
    samples = summary.fetch(:samples)
    findings = files.values.each do |file|
      file[:self_pct] = samples.positive? ? 100.0 * file[:self_samples] / samples : 0
      file[:inclusive_pct] = samples.positive? ? 100.0 * file[:inclusive_samples] / samples : 0
      file[:cpu_frames].sort_by! { [-_1[:inclusive_samples], -_1[:self_samples]] }
      file[:methods].sort_by! { [-_1[:repeated], -_1[:calls], _1[:line]] }
      source = File.join(root, file[:file])
      lines = File.file?(source) ? File.readlines(source) : []
      file[:allocation_sites].first(5).each do |site|
        site[:source] = lines[site[:line].to_i - 1]&.strip if site[:line].to_i.positive?
      end
      # Lexicographic rank, not a fabricated common cost unit. Inclusive costs
      # overlap, allocation sites are direct only, and counts are a companion.
      file[:explanation] = explanation(file)
    end.sort_by { [-_1[:self_samples], -_1[:inclusive_samples], -_1[:allocations_per_operation], _1[:file]] }
    { format: 1, kind: "discovery_only", samples: samples, missed_samples: profile["missed_samples"],
      profile_jit: "yjit", jit_before: jit_before, jit_after: jit_after,
      profile_jit_flat: jit_before == jit_after,
      warmup: warmup, profile_operations: requests, census_operations: census,
      ranking: "self CPU samples, inclusive CPU samples, direct allocations (lexicographic; not additive)",
      repeat_policy: "first 32 entries/method; same receiver and exact scalar arguments/result; raised frames excluded; values never exported; not proof of purity",
      first_candidate_gate: "unchecked: verify the code path still exists on current upstream main before investing; record upstream SHA and fixed/present/unknown in the ledger",
      findings: findings, sql: queries, allocations: allocations, profile: profile }
  end

  def self.explanation(file)
    repeated = file[:methods].find { _1[:repeated].positive? }
    if repeated
      "#{repeated[:method]}: #{repeated[:repeated]}/#{repeated[:comparable]} comparable returns repeat for the same receiver/arguments. Inspect :#{repeated[:line]} for request-local reuse or hoist the computation outside its caller's loop; first prove effects, freshness and invalidation. Do not globally memoize from this evidence."
    elsif (site = file[:allocation_sites].find { _1[:source]&.match?(/\.map\b.*\.join\b/) })
      "At :#{site[:line]}, `#{site[:source]}` rebuilds mapped strings and a joined result. If the source table and interpolation inputs are literal, replace the loop with one precomputed descriptor string, retaining a fresh mutable return where needed; otherwise hoist only the invariant part. Verify full responses and SQL before pricing."
    elsif (site = file[:allocation_sites].find { _1[:source]&.include?(".split.size") })
      "At :#{site[:line]}, `#{site[:source]}` materializes every word only to count them. Try a non-materializing word counter, preserving String#split whitespace/encoding semantics; or compute this only in the branch that displays the count. Test blank and non-ASCII inputs before pricing."
    elsif (site = file[:allocation_sites].find { _1[:source]&.include?("params.permit(") })
      "At :#{site[:line]}, `#{site[:source]}` rebuilds permitted parameters. If called repeatedly within this action, filter once per controller request, provided neither params nor the permitted result changes between callers. Never share across requests; compare filtered/paginated responses and SQL before pricing."
    elsif (site = file[:allocation_sites].first)
      "Inspect :#{site[:line]} (#{site[:type]}, #{site[:allocated]} allocations/census): move construction into the branch that consumes it, or reuse invariant intermediates outside the row/slot loop. Preserve fresh escaping values, evaluation order and SQL; this allocation may be necessary."
    else
      "Inclusive cost includes callees: inspect the hottest method's callers for repeated/eager work, not removal of the whole file. No cheap scalar repetition evidence; effects and SQL remain live."
    end
  end

  def self.cli(args)
    options = { requests: 200, census: 5, warmup: 50, top: 12, routes: [] }
    parser = OptionParser.new do |p|
      p.banner = "usage: lowrail advise APP (--request GET:/path ... | --workload FILE) [--out NEW_DIR]"
      p.on("--request VERB:PATH") { options[:routes] << _1 }
      p.on("--workload FILE", "Ruby file returning {label => callable}, loaded after boot; also supports jobs") { options[:workload] = File.expand_path(_1) }
      p.on("--out DIR") { options[:out] = File.expand_path(_1) }
      %i[requests census warmup top].each { |key| p.on("--#{key} N", Integer) { options[key] = _1 } }
    end
    parser.parse!(args)
    raise parser.to_s unless args.one? && (options[:workload] ? options[:routes].empty? : !options[:routes].empty?)
    raise "positive sizes required (warmup may be zero)" unless options.values_at(:requests, :census, :top).all?(&:positive?) && options[:warmup] >= 0
    app = File.realpath(args.first)
    out = options[:out] || File.join(app, ".lowrail/advise-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}")
    raise "output already exists: #{out}" if File.exist?(out)
    require "fileutils"
    FileUtils.mkdir_p(out, mode: 0o700)
    Dir.chdir(app) do
      require File.join(app, "config/application")
      Rails.application.config.yjit = true
      require File.join(app, "config/environment")
      raise "expected Rails 8.1.4 / Ruby 4.0.7" unless Rails.version == "8.1.4" && RUBY_VERSION == "4.0.7"
      raise "advice ranking requires production, eager loading and caching" unless Rails.env.production? &&
        Rails.application.config.eager_load && Rails.application.config.action_controller.perform_caching &&
        !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      require "rack/mock"
      Rails.logger.level = :error
      headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
      client = Rack::MockRequest.new(Rails.application)
      workloads = if options[:workload]
        eval(File.read(options[:workload]), TOPLEVEL_BINDING, options[:workload]) # explicit user-supplied executable workload
      else
        options[:routes].to_h do |route|
          verb, path = route.split(":", 2)
          raise "expected VERB:/path" unless verb && path&.start_with?("/")
          [route, -> {
            response = client.request(verb, path, headers)
            raise "#{verb} #{path} -> #{response.status}" unless (200..299).cover?(response.status)
            nil
          }]
        end
      end
      raise "workload must return a nonempty Hash of callables" unless workloads.is_a?(Hash) && !workloads.empty? && workloads.values.all? { _1.respond_to?(:call) }
      # Never share an established PostgreSQL socket across discovery children.
      ActiveRecord::Base.connection_handler.clear_all_connections!
      workloads.each_with_index do |(label, work), index|
        $stdout.flush
        pid = fork do
          result = capture(work, root: app, **options.slice(:requests, :census, :warmup))
          result.merge!(workload: label, ruby: RUBY_DESCRIPTION, rails: Rails.version, yjit: !!RubyVM::YJIT.enabled?,
            rails_env: Rails.env.to_s, eager_load: Rails.application.config.eager_load,
            caching: Rails.application.config.action_controller.perform_caching, cache_store: Rails.cache.class.name,
            lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest,
            source_sha256: Dir.glob("{app,config,lib}/**/*").select { File.file?(_1) }.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] })
          File.write(File.join(out, "#{index}.json"), JSON.pretty_generate(result), perm: 0o600)
          puts "#{label}: #{result[:samples]} YJIT CPU samples; discovery only; JIT-flat=#{result[:profile_jit_flat]}"
          puts "First candidate gate: #{result[:first_candidate_gate]}"
          result[:findings].first(options[:top]).each_with_index do |finding, rank|
            puts format("%2d. %s self %.2f%% / inclusive %.2f%%; %.1f objects/op; %.1f calls/op", rank + 1,
              finding[:file], finding[:self_pct], finding[:inclusive_pct], finding[:allocations_per_operation],
              finding[:methods].sum { _1[:calls_per_operation] })
            finding[:cpu_frames].first(3).each do |frame|
              puts "    #{frame[:method]}: #{frame[:self_samples]} self / #{frame[:inclusive_samples]} inclusive samples (#{result[:samples]} total)"
            end
            puts "    #{finding[:explanation]}"
          end
          result[:sql]&.fetch(:events)&.first(options[:top])&.each do |query|
            puts "SQL: #{query[:round_trips]} round trips (#{query[:duplicate_round_trips]} duplicate); #{query[:cached_hits]} CACHE hits (#{query[:duplicate_cached_hits]} duplicate), over #{options[:census]} operations"
            puts "    #{query[:statement]}"
          end
        end
        _, status = Process.wait2(pid)
        raise "discovery child failed for workload #{index}; no speed claim" unless status.success?
      end
    end
    puts "Evidence: #{out} (SQL text is private; no response bodies, bind/argument values or cookies exported)"
  end
end

Advise.cli(ARGV) if $PROGRAM_NAME == __FILE__
