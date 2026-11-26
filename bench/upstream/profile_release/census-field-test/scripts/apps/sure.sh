APPDIR=/home/user/workspace/repo/.corpus/ft-sure; CMD=(bin/rails test test/controllers -v)
PLANT="app/controllers/transactions_controller.rb:22a\\\\    20.times { ERB::Util.html_escape(\"a<b\") }"
export POSTGRES_DB=ft_sure_test POSTGRES_USER=user DB_HOST=localhost REDIS_URL=redis://localhost:6379/8
