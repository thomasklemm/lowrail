RUBY=4.0.7
CMD=(bin/rails test --verbose)
export DATABASE_URL=postgres://user@localhost/hl_codetriage_test
PREP() { [ -f config/database.yml ] || cp config/database.ci.yml config/database.yml
  [ -f tmp/.hl-db ] || { RAILS_ENV=test bin/rails db:create db:schema:load > /tmp/prep-codetriage.log 2>&1 && touch tmp/.hl-db; }; }
