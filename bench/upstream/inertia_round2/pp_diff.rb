# frozen_string_literal: true

# Differential for the prop-type flag lead: resolves generated props under many visits and prints one line per
# case (props and metadata, or the error), so two trees' outputs can be diffed.
#   INR_TREE=TREE bundle exec ruby pp_diff.rb > out.txt   (Gemfile of ~/w/inr-bench)
require_relative "app"

srand(1729)
Time.singleton_class.prepend(Module.new { def now(*) = at(1_800_000_000) })

CONTROLLER = Object.new
EVALUATOR = InertiaRails::PropEvaluator.new(CONTROLLER)

# A plain value that answers some flag questions, and a custom prop type without any of them.
Flagged = Struct.new(:deferred?, :once?, :merge?, :rescue?, :live?, :fresh?) do
  def as_json(*) = { flagged: to_a }
end
class CustomProp < InertiaRails::BaseProp; end
class FlaggedProp < InertiaRails::BaseProp
  def deferred? = false
  def once? = nil
  def merge? = false
end

def value(depth = 0)
  case rand(depth > 1 ? 4 : 6)
  when 0 then rand(100)
  when 1 then "s#{rand(10)}"
  when 2 then [1, nil, { x: rand(3) }]
  when 3 then Flagged.new(*Array.new(6) { [true, false, nil].sample })
  when 4 then { a: value(depth + 1), b: value(depth + 1) }
  else -> { value(depth + 1) }
  end
end

PROPS = [
  -> { InertiaRails.defer { value } },
  -> { InertiaRails.defer(group: %w[a b].sample) { value } },
  -> { InertiaRails.defer(rescue: true) { raise "boom" } },
  -> { InertiaRails.defer(rescue: true) { value } },
  -> { InertiaRails.defer(merge: true) { [1, 2] } },
  -> { InertiaRails.defer(once: true) { value } },
  -> { InertiaRails.defer(live: "room") { value } },
  -> { InertiaRails.optional { value } },
  -> { InertiaRails.always { value } },
  -> { InertiaRails.merge { [value] } },
  -> { InertiaRails.merge(append: "data", match_on: "id") { { data: [{ id: 1 }] } } },
  -> { InertiaRails.merge(prepend: true) { [value] } },
  -> { InertiaRails.deep_merge(match_on: "deep.id") { { deep: [{ id: 1 }] } } },
  -> { InertiaRails.once { value } },
  -> { InertiaRails.once(key: "k", expires_in: 60) { value } },
  -> { InertiaRails.once(fresh: true) { value } },
  -> { InertiaRails.scroll({ page_name: "page", previous_page: nil, next_page: 2, current_page: 1 }) { [value] } },
  -> { InertiaRails.scroll({ page_name: "page", previous_page: 1, next_page: nil, current_page: 2 }, defer: true) { [value] } },
  -> { InertiaRails.live("room") { value } },
  -> { InertiaRails.lazy { value } },
  -> { CustomProp.new { value } },
  -> { FlaggedProp.new { value } },
  -> { value },
].freeze

def props(n)
  Array.new(n) { |i| [:"p#{i}", PROPS.sample.call] }.to_h.tap do |h|
    h[:nest] = { inner: PROPS.sample.call, plain: value } if rand(2).zero?
  end
end

def visit(keys)
  pick = -> { keys.sample(rand(1..2)).map(&:to_s) + (rand(3).zero? ? ["nest.inner"] : []) }
  case rand(6)
  when 0 then {}
  when 1 then { component: true, only: pick.() }
  when 2 then { component: true, except: pick.() }
  when 3 then { component: true, only: pick.(), reset: pick.() }
  when 4 then { except_once: %w[k p0 p1 p2] }
  else { component: true, only: pick.(), except_once: %w[k p1], scroll_intent: %w[append prepend].sample }
  end
end

4000.times do |i|
  srand(1729 + i)
  p = props(rand(1..6))
  v = visit(p.keys)
  out = begin
    resolved, metadata = InertiaRails::PropsResolver.new(p, evaluator: EVALUATOR, visit: v).resolve
    JSON.generate([resolved.as_json, metadata.as_json])
  rescue StandardError => e
    "#{e.class}: #{e.message}"
  end
  puts "#{i}\t#{v.to_json}\t#{out}"
end
