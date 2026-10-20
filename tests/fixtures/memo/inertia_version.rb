# Public analogue, not private ARGOS code. inertia_rails documents the lazy
# form; its install generator currently uses the eager `ViteRuby.digest` form.
# https://github.com/inertiajs/inertia-rails/blob/master/docs/guide/asset-versioning.md
# https://github.com/ElMassimo/vite_ruby/blob/main/vite_ruby/lib/vite_ruby/builder.rb
InertiaRails.configure do |config|
  config.version = -> { ViteRuby.digest }
end
