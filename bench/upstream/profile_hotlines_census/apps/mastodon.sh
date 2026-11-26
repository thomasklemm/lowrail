# Request and controller specs (field test).
RUBY=4.0.9
CMD=(bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation)
export RAILS_ENV=test DB_HOST=localhost DB_USER=user DB_NAME=hl_mastodon REDIS_URL=redis://localhost:6379/4 LOCAL_DOMAIN=localhost DISABLE_SIMPLECOV=true
PREP() { mise install node@24.22.0 >/dev/null && export PATH=$(mise where node@24.22.0)/bin:$PATH; [ -f tmp/.hl-db ] || { { mkdir -p tmp/corepack && corepack enable --install-directory tmp/corepack && PATH=$PWD/tmp/corepack:$PATH COREPACK_ENABLE_DOWNLOAD_PROMPT=0 yarn install --immutable && PATH=$PWD/tmp/corepack:$PATH bin/rails db:create db:schema:load assets:precompile; } > /tmp/prep-mastodon.log 2>&1 && touch tmp/.hl-db; }; }
