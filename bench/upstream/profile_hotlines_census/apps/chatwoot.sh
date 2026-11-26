# JSON API controller specs (spec/controllers/api): the Vite build runs out of memory on a 4 GB orb (2.5 GB node heap), so auto-build is off and HTML pages are left out.
RUBY=3.4.4
CMD=(bundle exec rspec spec/controllers/api --seed 1234 --format documentation)
export VITE_RUBY_AUTO_BUILD=false RAILS_ENV=test POSTGRES_HOST=localhost POSTGRES_USERNAME=user POSTGRES_PASSWORD= POSTGRES_DATABASE=hl_chatwoot_test REDIS_URL=redis://localhost:6379/9
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=test_key_a6cde8f7b9c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7 ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=test_key_b7def9a8c0d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d8 ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=test_salt_c8efa0b9d1e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d9
PREP() { mise install node@24.22.0 >/dev/null && export PATH=$(mise where node@24.22.0)/bin:$PATH; [ -f tmp/.hl-db ] || { { psql -h localhost -d user -c 'select 1' >/dev/null; npx --yes pnpm@10.2.0 install --frozen-lockfile && bin/rails db:create db:schema:load; } > /tmp/prep-chatwoot.log 2>&1 && touch tmp/.hl-db; }; }
