APPDIR=/home/user/ft/op; CMD=(bundle exec rspec spec/controllers --seed 1234 --format documentation)
PLANT="${OP_PLANT:-app/controllers/news_controller.rb:1a\\\\# placeholder}"
export DATABASE_URL=postgres://user@localhost/ft_openproject_test RAILS_ENV=test
