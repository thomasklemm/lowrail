# Public analogue, not code from Private Rails app with Inertia Rails.
# inertia_rails documents the lazy form; its generator uses eager `ViteRuby.digest`.
# https://github.com/inertiajs/inertia-rails/blob/master/docs/guide/asset-versioning.md
# https://github.com/ElMassimo/vite_ruby/blob/main/vite_ruby/lib/vite_ruby/builder.rb
InertiaRails.configure do |config|
  config.version = -> { ViteRuby.digest }
end
