APPDIR=/home/user/workspace/repo/.corpus/ft-redprints-cfp; CMD=(bundle exec rspec spec --exclude-pattern "spec/system/**/*_spec.rb" --seed 1234 --format documentation)
PLANT="app/controllers/proposals_controller.rb:11a\\\\    20.times { ERB::Util.html_escape(\"a<b\") }"
