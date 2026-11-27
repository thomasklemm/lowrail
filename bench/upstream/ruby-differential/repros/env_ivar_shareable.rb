# Sure's Provider::JevTest stubs ENV with Mocha (ENV.stubs(:[])), which keeps its state in an instance
# variable of the stubbed object. Ruby 4.0.9 allows it; master raises Ractor::IsolationError from the main Ractor.
p Ractor.shareable?(ENV)
ENV.instance_variable_set(:@stubbed, true)
puts "ok"
