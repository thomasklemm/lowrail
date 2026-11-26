RUBY=4.0.6
CMD=(bin/rails test -v)
export TEST_DATABASE_URL=postgres://user@localhost/hl_hackatime_test RAILS_ENV=test
PREP() { [ -f tmp/.hl-db ] || { { bun install --frozen-lockfile && bin/rails db:create db:schema:load; } > /tmp/prep-hackatime.log 2>&1 && touch tmp/.hl-db; }; }
