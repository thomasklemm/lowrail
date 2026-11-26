RUBY=3.4.2
CMD=(bin/rails test -v)
export RAILS_ENV=test
PREP() { mise install node@24.22.0 >/dev/null && export PATH=$(mise where node@24.22.0)/bin:$PATH; [ -f tmp/.hl-db ] || { { npm ci --no-audit --no-fund && bin/vite build --mode test && bin/rails db:test:prepare; } > /tmp/prep-thinkroom.log 2>&1 && touch tmp/.hl-db; }; }
