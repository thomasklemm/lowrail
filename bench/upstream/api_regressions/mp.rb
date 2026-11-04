require "active_model"
c = ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
p [c, c.frozen?, ActiveModel::SecurePassword.const_defined?(:MAX_PASSWORD_LENGTH_ALLOWED, false), $LOADED_FEATURES.grep(/bcrypt\.rb|\/bcrypt\//).size]
class U; include ActiveModel::Model; attr_accessor :password; validates :password, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }; end
p U.new(password: "a" * 73).valid?, U.new(password: "a" * 72).valid?
