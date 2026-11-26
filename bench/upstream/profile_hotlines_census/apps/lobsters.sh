RUBY=4.0.9
CMD=(bundle exec rspec --seed 1234 --format documentation)
export RAILS_ENV=test
PREP() { [ -f config/database.yml ] || { cp config/database.yml.sample config/database.yml; cp .github/workflows/check/* config/; }
  [ -f tmp/.hl-db ] || { bin/rails db:schema:load db:migrate > /tmp/prep-lobsters.log 2>&1 && touch tmp/.hl-db; }; }
