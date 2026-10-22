# frozen_string_literal: true

# Diagnostic construction census, not a removable budget or a speed price.
# Observe only naturally executed calls; never replay an application scope.
require "json"
require "fileutils"
require "digest"
require_relative "../../fixtures/corpus/blog_production"

module DirectSiteBreadthCensus
  BUILDERS = %i[where where! order reorder limit offset includes preload joins
    left_outer_joins merge or select distinct reverse_order build_arel scope].freeze

  def self.capture(app)
    rows, stack, overhead = Hash.new { |hash, key| hash[key] = [0, 0, 0] }, [], 0
    sql_count = 0
    thread = Thread.current
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do
      sql_count += 1 if Thread.current.equal?(thread)
    end
    trace = TracePoint.new(:call, :return) do |event|
      next unless Thread.current.equal?(thread)
      before = GC.stat(:total_allocated_objects)
      begin
        path = event.path
        selected = path.include?("/active_record/") &&
          (BUILDERS.include?(event.method_id) || path.end_with?("/scoping/named.rb"))
        selected ||= event.defined_class.to_s.end_with?("::GeneratedAssociationMethods")
        next unless selected
        if event.event == :call
          if stack.empty?
            caller = caller_locations.find { _1.path.start_with?(app + "/app/") }
            site = caller && "#{caller.path.delete_prefix(app + '/')}:#{caller.lineno}"
            root = [site || "<framework>", event.method_id.to_s]
            start = before - overhead
          end
          stack << [event.defined_class, event.method_id, root, start, sql_count]
        else
          entry = stack.pop
          raise "unbalanced construction trace" unless entry && entry.first(2) == [event.defined_class, event.method_id]
          next unless stack.empty?
          row = rows[entry.fetch(2) + [event.return_value.class.name]]
          row[0] += 1
          row[1] += before - overhead - entry.fetch(3)
          row[2] += sql_count - entry.fetch(4)
        end
      ensure
        overhead += GC.stat(:total_allocated_objects) - before
      end
    end
    trace.enable { yield }
    raise "unfinished construction trace" unless stack.empty?
    rows.sort_by { |_, (_, objects)| -objects }.map do |(site, method, result), (calls, objects, queries)|
      {site: site, method: method, result: result, calls: calls, objects: objects, sql_events_inside: queries}
    end
  ensure
    trace&.disable
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  def self.run(app, seed, workload, destination)
    app, seed = [app, seed].map { File.realpath(_1) }
    state = destination + ".state"
    raise "new private output required" if File.exist?(destination) || File.exist?(state)
    owned_state = state
    FileUtils.cp_r(seed, state)
    case workload
    when "fizzy"
      require_relative "fizzy_link_vector"
      FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      FizzyLinkFixture.boot(app)
      driver = FizzyLinkVector::Driver.new(state, record: false)
      driver.login
      requests = JSON.parse(File.read(File.join(state, "vector.json"))).to_h do |path|
        [path, -> { driver.request("GET", path) }]
      end
    when "campfire"
      require_relative "campfire_scenario"
      CampfireScenario.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
      CampfireScenario.boot(app)
      driver = CampfireScenario::Driver.new(state, record: false)
      driver.login
      requests = %w[room pagination sidebar search].to_h { |id| [id, -> { driver.run(id) }] }
    else
      raise "unsupported workload"
    end
    raise "wrong toolchain" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" && !RubyVM::YJIT.enabled?
    requests.each_value { |call| 20.times { raise "warm GET failed" unless call.call.status == 200 } }
    result = requests.to_h do |route, call|
      sql = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sql << payload[:sql] }
      constructions = capture(app) { raise "census GET failed" unless call.call.status == 200 }
      ActiveSupport::Notifications.unsubscribe(subscriber)
      [route, {constructions: constructions, ordered_sql: sql}]
    end
    File.write(destination, JSON.pretty_generate(ruby: RUBY_DESCRIPTION, rails: Rails.version,
      census_sha256: Digest::SHA256.file(__FILE__).hexdigest,
      app_revision: IO.popen(["git", "-C", app, "rev-parse", "HEAD"], &:read).strip,
      app_source: BlogProduction::Entropy.source_pin(app),
      lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
      scope: "One warmed natural GET per route; outermost observed calls only, observer allocations subtracted. Inclusive diagnostic pools, not removable savings. Named scopes/readers may execute SQL and load rows: sql_events_inside and result retain that distinction, never credit those totals as construction savings.",
      routes: result), perm: 0o600)
  ensure
    FileUtils.remove_entry(owned_state) if owned_state && File.directory?(owned_state)
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: directsite_breadth_census.rb APP SEED fizzy|campfire NEW_JSON" unless ARGV.size == 4
  DirectSiteBreadthCensus.run(*ARGV)
end
