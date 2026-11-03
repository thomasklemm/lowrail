# frozen_string_literal: true

# The first request of each app: an anonymous page every boot can serve.
module BootPaths
  PATHS = {
    "lobsters" => "/", "discourse" => ["/latest.json", { "HTTP_ACCEPT" => "application/json" }],
    "mastodon" => "/about", "sure" => "/sessions/new", "chatwoot" => "/app/login",
    "campfire" => "/session/new", "fizzy" => "/session/new", "writebook" => "/session/new", "blog" => "/",
  }.freeze
end
