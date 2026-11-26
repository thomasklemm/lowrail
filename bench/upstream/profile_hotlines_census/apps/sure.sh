# Top-level controller tests a-l: the stack-walking profiled run reached 2.9 GB RSS and was killed at the end (writing its counts) on a 4 GB orb, for all of test/controllers, for all top-level files, and for those with --runs 1.
RUBY=3.4.9
CMD=(bin/rails test "test/controllers/[a-l]*_test.rb" -v)
export RAILS_ENV=test POSTGRES_DB=hl_sure_test POSTGRES_USER=user DB_HOST=localhost REDIS_URL=redis://localhost:6379/8
export PLAID_CLIENT_ID=foo PLAID_SECRET=bar DISABLE_PARALLELIZATION=true
PREP() { [ -f tmp/.hl-db ] || { bin/rails db:create db:schema:load tailwindcss:build > /tmp/prep-sure.log 2>&1 && touch tmp/.hl-db; }; }
