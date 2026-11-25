# Records what a process the suite starts sees. Loaded by test_helper / rails_helper.
require "rbconfig"
module Probe
  CHILD = <<~'RUBY'
    keys = ENV.keys.grep(/\ALOWRAIL|\A(?:SEED|SPEC_OPTS|RUBYOPT|RUBYLIB|TESTOPTS|BUNDLER_ORIG_RUBYOPT|BUNDLER_ORIG_RUBYLIB|BUNDLER_ORIG_SEED)\z/).sort
    puts keys.map { "#{_1}=#{ENV[_1]}" }
    puts "profiler=#{defined?(Lowrail::Profile).inspect}"
    puts "features=#{$LOADED_FEATURES.grep(/lowrail/).size}"
    puts "pgrp_is_own=#{Process.getpgrp == Process.pid}"
  RUBY
  def self.out = (ENV["PROBE_OUT"] unless ENV["PROBE_NESTED"])
  def self.child(name)
    return unless out
    File.write(File.join(out, "#{name}.txt"), IO.popen([RbConfig.ruby, "-e", CHILD], &:read))
  end
  KEYS = /\ALOWRAIL|\A(?:SEED|SPEC_OPTS|RUBYOPT|RUBYLIB|TESTOPTS|BUNDLER_ORIG_RUBYOPT|BUNDLER_ORIG_RUBYLIB)\z/
  # The environment a non-Ruby child gets (no bundler/setup in between).
  def self.env(name)
    return unless out
    File.write(File.join(out, "#{name}.txt"), IO.popen(["env"], &:read).lines.select { _1.split("=", 2).first.match?(KEYS) }.sort.join)
  end
  # As tools start their own commands: Bundler.with_original_env / with_unbundled_env.
  def self.bundler(name)
    return unless out && defined?(Bundler)
    Bundler.with_original_env { env("#{name}_original_env"); child("#{name}_original_env_ruby") }
    Bundler.with_unbundled_env { env("#{name}_unbundled_env"); child("#{name}_unbundled_env_ruby") }
  end
  # A command the suite runs; its output is kept.
  def self.run(name, *command)
    return unless out
    extra = command.first.is_a?(Hash) ? command.shift : {}
    File.write(File.join(out, "#{name}.txt"), IO.popen({ "PROBE_NESTED" => "1" }.merge(extra), command, err: [:child, :out], &:read) + "exit=#{$?.exitstatus}\n")
  end
end
