puts ENV.keys.grep(/\ALOWRAIL_PROFILE|\A(?:SEED|SPEC_OPTS|RUBYOPT|RUBYLIB|BUNDLER_ORIG_RUBYOPT)\z/).sort.map { "#{_1}=#{ENV[_1]}" }, "profiler #{defined?(Lowrail::Profile).inspect}"
