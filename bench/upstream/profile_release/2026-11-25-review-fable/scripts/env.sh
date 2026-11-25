# source env.sh RUBY : PATH for that mise Ruby; no checkout on RUBYLIB.
export PATH="$(mise where ruby@$1)/bin:$PATH"
unset RUBYLIB RUBYOPT
export GEMFILE_GEM=/tmp/pr/build/lowrail-profile-0.1.0.rc1.gem
