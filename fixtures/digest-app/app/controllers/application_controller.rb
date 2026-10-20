class ApplicationController < ActionController::Base
  inertia_config version: -> { RailsVite.digest }, always_include_errors_hash: true
end
