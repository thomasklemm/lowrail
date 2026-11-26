APPDIR=/home/user/workspace/repo/.corpus/ft-loomio; CMD=(bin/rails test test/controllers -v)
PLANT="app/controllers/api/v1/search_controller.rb:4a\\\\    20.times { ERB::Util.html_escape(\"a<b\") }"
export DATABASE_URL=postgres://user@localhost/ft_loomio_test CANONICAL_HOST=localhost REDIS_URL=redis://localhost:6379/7 RAILS_ENV=test
export MISE_TRUSTED_CONFIG_PATHS=/home/user/workspace/repo/.corpus/ft-loomio
