APPDIR=/home/user/workspace/repo/.corpus/ft-fizzy; CMD=(bin/rails test test/controllers -v)
PLANT="app/controllers/bubbles_controller.rb:17a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
export CI_PROGRESS_BAR=0
