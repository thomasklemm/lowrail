# frozen_string_literal: true

# Bounded native diagnostic on a real corpus model. Run in the app's cwd and
# production environment, startup --yjit. No source/config changes or Callgrind.
require File.expand_path("config/environment", Dir.pwd)
require "json"
require_relative "ar_callsite"
raise "production YJIT required" unless Rails.env.production? && RubyVM::YJIT.enabled?
model, column, association = case Rails.application.class.module_parent_name
when "Campfire" then [Message, :room_id, :creator]
when "Fizzy" then [Bubble, :creator_id, :creator]
when "Lobsters" then [Story, :user_id, :user]
else raise "unknown app"
end
ids = model.distinct.limit(2).pluck(column)
raise "two asymmetric binds required" unless ids.size == 2 && ids.uniq.size == 2
chain = ->(id) { model.where(column => id).order(id: :desc).limit(10).includes(association) }
ARCallsite.install
site = ARCallsite::DirectSite.new(model, arity: 1, &chain)

capture = ->(enabled, direct, id) do
  ARCallsite.enabled = enabled
  events = []
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    payload = args.last
    events << [payload[:sql].b, payload[:name], payload[:binds].map { Lowrail::ARShadow.bind(_1) }, !!payload[:cached]]
  end
  rows = direct ? site.call(id) : chain.call(id).to_a
  records = rows.map { [_1.attributes, _1.association(association).loaded?, _1.public_send(association)&.attributes] }
  ActiveSupport::Notifications.unsubscribe(subscriber)
  [records, events]
end
# Warm schema/association metadata before comparing warm paths. Keep every
# event in the subsequent comparison; do not filter away schema differences.
ids.each { capture.call(false, false, _1) }
ids.each do |id|
  native = capture.call(false, false, id)
  [false, true].each do |direct|
    actual = capture.call(true, direct, id)
    unless actual == native
      File.write(ENV.fetch("AR_MICRO_MISMATCH"), JSON.pretty_generate(native: native, actual: actual)) if ENV["AR_MICRO_MISMATCH"]
      raise "micro SQL/rows differ (direct=#{direct})"
    end
  end
end

ARCallsite.counting = ARCallsite.shadow = false
cases = {"off_a" => [false, false, false], "off_b" => [false, false, false],
  "sql_only" => [true, false, false], "lean_only" => [false, true, false], "direct_and_lean" => [true, true, true]}
rows = []
3.times do |round|
  cases.to_a.rotate(round % cases.size).each do |name, (sql, lean, direct)|
    ARCallsite.install(sql: sql, lean: lean)
    ARCallsite.enabled = sql || lean
    ARCallsite.counting = ARCallsite.shadow = false
    call = ->(index) { (direct ? site.call(ids[index % 2]) : chain.call(ids[index % 2]).to_a).each(&:attributes) }
    100.times { call.call(_1) }
    n = 500
    start_alloc = GC.stat(:total_allocated_objects)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { call.call(_1) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    rows << {round: round, name: name, us: elapsed * 1e6 / n,
      objects: (GC.stat(:total_allocated_objects) - start_alloc).fdiv(n)}
  end
end
puts JSON.pretty_generate(app: Rails.application.class.module_parent_name, model: model.name,
  input_rows: ids.map { chain.call(_1).count }, rounds: rows,
  scope: "native micro; same process, rotated cases; not a request price or certified app callsite")
