# Run from a Rails checkout's actionmailer dir: bundle exec ruby nested_probe.rb
# Active Job is available but one of its own dependencies (globalid) is not: the LoadError must surface.
require "action_mailer"
$LOAD_PATH.reject! { |path| path.include?("/globalid") }
begin
  require "action_mailer/test_helper"
  puts "loaded"
rescue LoadError => error
  puts "LoadError #{error.path}"
rescue NameError => error
  puts "NameError #{error.message[/uninitialized constant \S+/]}"
end
