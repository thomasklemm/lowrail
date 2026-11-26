RUBY=3.4.3
CMD=(bundle exec rspec --seed 1234 --format documentation --exclude-pattern "spec/system/**/*_spec.rb")
export RAILS_ENV=test
PREP() { [ -f tmp/.hl-db ] || { { bun install --frozen-lockfile && bin/rails db:prepare assets:precompile; } > /tmp/prep-redprints-cfp.log 2>&1 && touch tmp/.hl-db; }; }
