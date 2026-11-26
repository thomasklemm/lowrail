# Controller tests.
RUBY=4.0.9
CMD=(bin/rails test test/controllers -v)
export RAILS_ENV=test REDIS_URL=redis://localhost:6379/10 DB_USERNAME=user
PREP() { [ -f tmp/.hl-db ] || { bin/rails db:create db:schema:load > /tmp/prep-flow.log 2>&1 && touch tmp/.hl-db; }; }
