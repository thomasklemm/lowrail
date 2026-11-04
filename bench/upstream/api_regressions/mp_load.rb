require "active_model"
b = $LOADED_FEATURES.dup
ActiveModel::SecurePassword
puts(($LOADED_FEATURES - b).map { _1.sub(%r{.*/wt/[a-z0-9]+/}, "") }.sort)
