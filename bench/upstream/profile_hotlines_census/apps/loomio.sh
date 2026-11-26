# Controller tests (field test).
RUBY=4.0.9
CMD=(bin/rails test test/controllers -v)
export RAILS_ENV=test DATABASE_URL=postgres://user@localhost/hl_loomio_test CANONICAL_HOST=localhost REDIS_URL=redis://localhost:6379/7 MISE_TRUSTED_CONFIG_PATHS=$PWD
PREP() { mise install node@24.22.0 >/dev/null && export PATH=$(mise where node@24.22.0)/bin:$PATH; [ -f tmp/.hl-db ] || { { [ -f config/database.yml ] || cp config/database.example.yml config/database.yml; bin/rails db:create db:schema:load; } > /tmp/prep-loomio.log 2>&1 && touch tmp/.hl-db; }; }
