# frozen_string_literal: true

# rack-mini-profiler differential for the render-subscriber change: every census
# workload of APP, unprofiled (status and body digest) and then profiled with
# authorization_mode = :allow_all (the node names of the stored page's timer tree,
# sorted, from the second of two operations).
#   ruby inapp.rb APP rmp_diff.rb   (GEMS=rack-mini-profiler=OWNER/REPO@SHA for a branch)
require_relative "../census/harness"
RailsCensus.boot(ARGV[0])
ops = RailsCensus.workloads(ARGV[0])
digest = ->(r) { r.respond_to?(:status) ? [r.status, Digest::SHA256.hexdigest(r.body.to_s.gsub(/(?:content|value)="[A-Za-z0-9+\/=_-]{20,}"|\d{4}-\d\d-\d\dT[\d:.]+Z?|[0-9a-f]{20,}|\d{6,}/, "#"))[0, 12]] : nil }
names = ->(t) { [t[:name], *(t[:children] || []).flat_map { names.(_1) }] }
out = []
ops.each do |op|
  2.times { op.call.call; RailsCensus.reset_side_effects }
  out << [op.name, :plain, digest.(op.call.call)]
  RailsCensus.reset_side_effects
end
Rack::MiniProfiler.config.authorization_mode = :allow_all
Rack::MiniProfiler.config.enabled = true
Rack::MiniProfiler.config.storage_instance.singleton_class.prepend(Module.new { def save(page) = ($page = page; super) })
ops.each do |op|
  2.times do
    $page = nil
    op.call.call
    RailsCensus.reset_side_effects
  end
  out << [op.name, :profiled, $page && names.($page[:root]).sort]
end
puts JSON.generate(out)
