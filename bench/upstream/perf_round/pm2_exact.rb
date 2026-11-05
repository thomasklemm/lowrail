# PM2: keys for which skipping tag_options' second blank? call is observable (Sol, 2026-11-05).
# Prints one line per key: the rendered tag and how often the key's blank? ran.
#   RAILS_PATH=~/src/wt/m ruby pm2_exact.rb   (and again with the branch tree; diff the output)
$LOAD_PATH.unshift(*%w[activesupport actionview].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "action_view"
view = Object.new.extend(ActionView::Helpers::TagHelper)

def counting(key, &blank)
  calls = 0
  key.define_singleton_method(:blank?) { calls += 1; blank ? blank.call(calls) : super() }
  [key, -> { calls }]
end

class LyingEqual < String
  def equal?(_) = true
end

cases = {
  "plain String" => counting(+"title"),
  "stateful blank? (false, then true)" => counting(+"title") { |n| n > 1 },
  "to_s returns self, stateful blank?" => counting(+"title") { |n| n > 1 }.tap { |k, _| k.define_singleton_method(:to_s) { self } },
  "to_s returns a blank String whose equal? is always true" => counting(+"title").tap { |k, _| k.define_singleton_method(:to_s) { LyingEqual.new(" ") } },
}

cases.each do |label, (key, calls)|
  key.freeze
  out = begin
    view.tag("img", key => "x")
  rescue => e
    e.class
  end
  puts "#{label}: #{out} key.blank? calls=#{calls.call}"
end
