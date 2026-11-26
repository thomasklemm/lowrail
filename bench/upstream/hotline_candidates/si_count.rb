# Run in an app dir: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec ruby si_count.rb PATH
require "./config/environment"
app = Rails.application
env = -> { Rack::MockRequest.env_for(ARGV[0], "HTTP_HOST" => "localhost", "HTTPS" => "on") }
20.times { app.call(env.call) }
counts = Hash.new(0)
tp = TracePoint.new(:call) { |t| counts[t.self.to_s] += 1 if t.method_id == :new && t.defined_class == Concurrent::Synchronization::SafeInitialization }
GC.start
a = GC.stat(:total_allocated_objects)
status = nil
tp.enable { 10.times { status, = app.call(env.call) } }
b = GC.stat(:total_allocated_objects)
puts "status #{status}; SafeInitialization#new per request: #{counts.transform_values { _1 / 10.0 }}; objects/request incl. tracing #{(b - a) / 10.0}"
puts "safe_initialization.rb: #{$LOADED_FEATURES.grep(/safe_initialization/)}"
