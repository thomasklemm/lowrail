# frozen_string_literal: true

# Entry point for RUBYOPT="-I<gem>/lib -rlowrail/setup" or config/boot.rb.
# Never raises: on any problem the app runs as plain Ruby.
require_relative "../lowrail"

Lowrail.boot(root: ENV.fetch("LOWRAIL_ROOT") { File.expand_path(Dir.pwd) })
