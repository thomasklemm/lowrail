# Request specs (field test).
RUBY=4.0.7
CMD=(bundle exec rspec spec/requests --seed 1234 --format documentation)
export RAILS_ENV=test POSTGRES_USER=user DATABASE_HOST=localhost
PREP() { mise install node@24.22.0 >/dev/null && export PATH=$(mise where node@24.22.0)/bin:$PATH; [ -f tmp/.hl-db ] || { { npm ci --no-audit --no-fund && npm run build && npm run build:css && bin/rails db:create db:schema:load; } > /tmp/prep-casa.log 2>&1 && touch tmp/.hl-db; }; }
