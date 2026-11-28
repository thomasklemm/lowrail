# frozen_string_literal: true

# Ruby method calls per request for the strict Accept header lead: one census
# workload with Chrome's Accept header, strict_accept_header on or off.
#   bundle exec ruby accept_calls.rb APP WORKLOAD STRICT N   (via run_in_app.rb)
require_relative "../census/harness"

name, workload, strict, n = ARGV
CHROME = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
RailsCensus.boot(name)
ActionDispatch::Request.strict_accept_header = strict == "true"
RailsMainCensus4::Client.prepend(Module.new do
  def initialize(headers = {}) = super(headers.merge("HTTP_ACCEPT" => CHROME))
end)
op = RailsCensus.workloads(name).find { _1.name == workload } or abort "no workload #{workload}"
run = -> { op.call.call; RailsCensus.reset_side_effects }
200.times { run.call }
counts = Hash.new(0)
tp = TracePoint.new(:call, :c_call) { |t| counts["#{t.defined_class}##{t.method_id} #{t.path.sub(%r{.*/gems/}, '')}:#{t.lineno}"] += 1 }
tp.enable { Integer(n).times { run.call } }
counts.each { |k, v| puts "#{v}\t#{k}" }
