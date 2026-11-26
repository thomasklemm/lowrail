# Core request specs (list, topics, posts, categories, tags, search; about 1,500 of spec/requests' 6,400 examples): the whole directory's plain run alone reached 1.2 GB RSS halfway, more than the stack-walking run can add to on a 4 GB orb.
RUBY=4.0.7
CMD=(bundle exec rspec spec/requests/list_controller_spec.rb spec/requests/topics_controller_spec.rb spec/requests/posts_controller_spec.rb spec/requests/categories_controller_spec.rb spec/requests/tags_controller_spec.rb spec/requests/search_controller_spec.rb --seed 1234 --format documentation)
export RAILS_ENV=test LOAD_PLUGINS=0 DISCOURSE_REDIS_HOST=localhost DISCOURSE_REDIS_DB=5
PREP() { [ -f tmp/.hl-db ] || { { npx --yes pnpm@10 install --frozen-lockfile; bin/rake db:create db:migrate; } > /tmp/prep-discourse.log 2>&1 && touch tmp/.hl-db; }; }
