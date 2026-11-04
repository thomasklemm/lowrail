Title: **Restore ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED**

This keeps `ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED` as a public constant that points at `BCryptPassword::MAX_PASSWORD_LENGTH_ALLOWED`. #56041 moved the constant into the new `BCryptPassword` class when it added `algorithm:`. The removal is unreleased.

Applications and gems use the old name to cap password length, so on main they raise `NameError` when the code loads:

```ruby
# Spree, spree/core/lib/spree/core/configuration.rb
preference :maximum_password_length, :integer, default: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

# open-build-service, app/models/user.rb
validates :password, length: { minimum: 6, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }
```

The constant preserves the BCrypt byte limit and is defined directly on `SecurePassword` again, as in 8.1. Loading stays as lazy as on main: `SecurePassword` already requires `bcrypt_password.rb`, and the bcrypt gem is still only required when a password is hashed. The new test fails without the constant.
