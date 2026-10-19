# frozen_string_literal: true

require_relative "../lowrail"

Lowrail.setup(root: ENV.fetch("LOWRAIL_ROOT") { File.expand_path(Dir.pwd) })
