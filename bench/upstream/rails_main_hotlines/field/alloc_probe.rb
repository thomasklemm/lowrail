# Objects per call for the field test's candidates: ruby -I RAILS/activesupport/lib -I RAILS/actionpack/lib alloc_probe.rb
# Each figure is the median of 5 batches of 1,000 calls after warm-up (GC.stat total_allocated_objects).
require "active_support"
require "active_support/core_ext/time"
require "action_dispatch"
require "action_dispatch/http/content_security_policy"

def per_call(n = 1000)
  3.times { yield }
  5.times.map do
    before = GC.stat(:total_allocated_objects)
    n.times { yield }
    (GC.stat(:total_allocated_objects) - before) / n.to_f
  end.sort[2]
end

# The policy `rails new` generates, uncommented, plus a nonce for script-src and style-src.
policy = ActionDispatch::ContentSecurityPolicy.new do |p|
  p.default_src :self, :https
  p.font_src    :self, :https, :data
  p.img_src     :self, :https, :data
  p.object_src  :none
  p.script_src  :self, :https
  p.style_src   :self, :https
end
context = Object.new
utc = Time.utc(2026, 11, 27, 12, 34, 56)
zone = ActiveSupport::TimeZone["Berlin"].now.change(hour: 10)

puts "rails #{ActionPack::VERSION::STRING} ruby #{RUBY_VERSION}"
puts format("csp build with nonce        %.1f", per_call { policy.build(context, "abc123", %w[script-src style-src]) })
puts format("Time#change(hour: 0) utc    %.1f", per_call { utc.change(hour: 0) })
puts format("Time#change(day: 1) utc     %.1f", per_call { utc.change(day: 1) })
puts format("TWZ#change(hour: 0)         %.1f", per_call { zone.change(hour: 0) })
puts format("beginning_of_day utc        %.1f", per_call { utc.beginning_of_day })
