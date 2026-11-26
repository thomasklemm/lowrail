# Only system tests serve requests (Capybara's server thread in the test process).
RUBY=4.0.7
CMD=(bin/rails test:all -v)
export RAILS_ENV=test DATABASE_URL=postgres://user@localhost/hl_pingcrm_test
PREP() { [ -f tmp/.hl-db ] || { { bun install --frozen-lockfile && bin/rails db:create db:schema:load assets:precompile; } > /tmp/prep-pingcrm.log 2>&1 && touch tmp/.hl-db; }; }
