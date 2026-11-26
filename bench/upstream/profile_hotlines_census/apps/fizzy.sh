# Controller tests only: the whole suite has 7 errors from Current#reset_all without the gem too (field test).
RUBY=4.0.7
CMD=(bin/rails test test/controllers -v)
export CI_PROGRESS_BAR=0
PREP() { [ -f tmp/.hl-db ] || { RAILS_ENV=test bin/rails db:prepare > /tmp/prep-fizzy.log 2>&1 && touch tmp/.hl-db; }; }
