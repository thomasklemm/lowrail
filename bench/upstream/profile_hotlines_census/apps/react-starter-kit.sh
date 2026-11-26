RUBY=4.0.1
CMD=(bundle exec rspec --seed 1234 --format documentation --exclude-pattern "spec/system/**/*_spec.rb")
export RAILS_ENV=test
PREP() { [ -f tmp/.hl-db ] || { { npm ci --no-audit --no-fund && bin/rails db:prepare assets:precompile; } > /tmp/prep-react-starter-kit.log 2>&1 && touch tmp/.hl-db; }; }
