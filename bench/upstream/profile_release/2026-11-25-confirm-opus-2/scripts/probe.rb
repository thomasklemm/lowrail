if $0.end_with?("extconf.rb")
  keys = %w[CC CFLAGS MAKEFLAGS PATH RUBYOPT RUBYLIB GEM_HOME GEM_PATH BUNDLE_GEMFILE BUNDLE_BIN_PATH MY_FLAG]
  File.write(File.join(ENV.fetch("PROBE_OUT"), "extconf-#{Process.pid}.txt"), keys.map { "#{_1}=#{ENV[_1]}" }.join("\n") + "\nbundler loaded: #{defined?(Bundler).inspect}\n")
end
