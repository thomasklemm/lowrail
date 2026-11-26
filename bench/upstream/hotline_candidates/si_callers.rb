require "./config/environment"
app = Rails.application
env = -> { Rack::MockRequest.env_for(ARGV[0], "HTTP_HOST" => "localhost", "HTTPS" => "on") }
20.times { app.call(env.call) }
sites = Hash.new(0)
tp = TracePoint.new(:call) do |t|
  next unless t.method_id == :new && t.defined_class == Concurrent::Synchronization::SafeInitialization
  loc = caller_locations(2, 12).map(&:to_s).reject { _1.include?("concurrent-ruby") }.first(2)
  sites["#{t.self} <- #{loc.join(' <- ')}"] += 1
end
tp.enable { app.call(env.call) }
sites.each { puts "#{_2} #{_1}" }
