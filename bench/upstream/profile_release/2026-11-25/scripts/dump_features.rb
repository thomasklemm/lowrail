# RUBYOPT=-r this: each process writes its $LOADED_FEATURES at exit.
if (dir = ENV["LOWRAIL_FEATURES_DIR"])
  at_exit { File.write(File.join(dir, "#{File.basename(ENV["LOWRAIL_PROFILE"].to_s)}#{"-" if ENV["LOWRAIL_PROFILE"]}#{Process.pid}.txt"), $LOADED_FEATURES.join("\n") + "\n") rescue nil }
end
