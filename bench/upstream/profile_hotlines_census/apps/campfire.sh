RUBY=4.0.7
CMD=(bin/rails test -v)
export REDIS_URL=redis://localhost:6379/1
PREP() { [ -f tmp/.hl-db ] || { RAILS_ENV=test bin/rails db:prepare > /tmp/prep-campfire.log 2>&1 && touch tmp/.hl-db; }; }
