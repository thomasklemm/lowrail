# frozen_string_literal: true

# Setup for ir.sh: the Fallbacks backend with a few translations.
require "i18n"; require "i18n/backend/fallbacks"
I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
I18n.available_locales = %i[en de]; I18n.default_locale = :en; I18n.enforce_available_locales = true
I18n.fallbacks = I18n::Locale::Fallbacks.new(de: :en)
I18n.backend.store_translations(:en, hello: "Hello", greet: "Hi %{name}", link: :hello, attributes: { body: "Body" },
  activerecord: { attributes: { post: { title: "Title" } } })
