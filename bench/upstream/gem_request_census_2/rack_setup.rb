# frozen_string_literal: true

# Setup for gem_request_census/ir.sh and cpu_ns.rb: Rack::Utils.set_cookie_header with a single value and with a
# Rails-style session cookie Hash (docs/upstream/gem-request-census-2.md).
#   bash ../gem_request_census/ir.sh RACK/lib rack_setup.rb 'Rack::Utils.set_cookie_header("k", PLAIN)' 5000
require "rack/utils"
SESSION = { value: "Zm9vYmFyYmF6cXV4MTIzNDU2Nzg5MA%3D%3D--a1b2c3d4e5f6", path: "/", httponly: true, same_site: :lax }.freeze
PLAIN = "value"
