APPDIR=/home/user/workspace/repo/.corpus/ft-casa; CMD=(bundle exec rspec spec/requests --seed 1234 --format documentation)
PLANT="app/controllers/casa_cases_controller.rb:10a\\\\    20.times { ERB::Util.html_escape(\"a<b\") }"
export POSTGRES_USER=user DATABASE_HOST=localhost
