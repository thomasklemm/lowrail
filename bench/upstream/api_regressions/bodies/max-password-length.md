Title: **Restore ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED**

This keeps `ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED` as a public constant that points at `BCryptPassword::MAX_PASSWORD_LENGTH_ALLOWED`. #56041 moved the constant into the new `BCryptPassword` class when it added `algorithm:`, and that change has not been released yet.

Applications and gems use the old name to cap password length, so on main they raise `NameError` when the code loads:

```ruby
# Spree, spree/core/lib/spree/core/configuration.rb
preference :maximum_password_length, :integer, default: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

# open-build-service, app/models/user.rb
validates :password, length: { minimum: 6, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }
```

GitHub code search finds the same pattern in many application `User` models and password forms.

The value is the same frozen Integer as in 8.1, and the constant is still defined directly on `SecurePassword`. Reading it does not load the bcrypt gem. Validations that use it give the same results as on 8-1-stable on the interpreter, YJIT and ZJIT. The new test fails without the constant.
