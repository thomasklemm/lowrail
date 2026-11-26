APPDIR=/home/user/workspace/repo/.corpus/ft-hackatime; CMD=(bin/rails test -v)
PLANT="app/controllers/leaderboards_controller.rb:4a\\\\    20.times { ERB::Util.html_escape(\"a<b\") }"
export TEST_DATABASE_URL=postgres://user@localhost/ft_hackatime_test
