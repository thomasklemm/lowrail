RUBY=4.0.7
CMD=(bin/rails test -v)
PREP() { [ -f tmp/.hl-db ] || { RAILS_ENV=test bin/rails db:prepare > /tmp/prep-writebook.log 2>&1 && touch tmp/.hl-db; }; }
