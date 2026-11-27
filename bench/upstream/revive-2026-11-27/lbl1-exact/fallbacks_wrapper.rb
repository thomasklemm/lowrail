require "i18n"; require "i18n/backend/fallbacks"; I18n::Backend::Simple.include(I18n::Backend::Fallbacks)
load ARGV.shift
