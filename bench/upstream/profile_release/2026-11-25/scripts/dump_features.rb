# RUBYOPT=-r this: each process writes its $LOADED_FEATURES at exit.
# The run is read at load: the profiler takes LOWRAIL_PROFILE out of the environment once the suite starts.
if (dir = ENV["LOWRAIL_FEATURES_DIR"])
  run = ENV["LOWRAIL_PROFILE"]
  at_exit { File.write(File.join(dir, "#{File.basename(run.to_s)}#{"-" if run}#{Process.pid}.txt"), $LOADED_FEATURES.join("\n") + "\n") rescue nil }
end
