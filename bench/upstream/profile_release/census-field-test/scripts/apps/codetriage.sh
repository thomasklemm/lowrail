APPDIR=/home/user/workspace/repo/.corpus/ft-codetriage; CMD=(bin/rails test --verbose)
PLANT="app/controllers/pages_controller.rb:28a\\    20.times { ERB::Util.html_escape(\"a<b\") }"
FEATURES_REJECT='/yard-[^/]+/lib/yard/(handlers|code_objects)/'
