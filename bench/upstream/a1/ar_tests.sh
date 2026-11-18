#!/bin/bash
# ar_tests.sh TREE ADAPTER OUT: Active Record association, reflection, relation and scoping tests in one process.
cd $HOME/c10/$1/activerecord
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH BUNDLE_PATH=~/c10/bundle BUNDLE_WITHOUT="job:cable:storage:mdl:doc:rubocop" ARCONN=$2
files=$(ls test/cases/associations/*_test.rb test/cases/associations_test.rb test/cases/reflection_test.rb test/cases/relation_test.rb test/cases/relations_test.rb test/cases/relation/*_test.rb test/cases/scoping/*_test.rb test/cases/associations/*/*_test.rb 2>/dev/null)
bundle exec ruby -w -Itest -e 'ARGV.each { |f| require File.expand_path(f) }' $files > $3 2>&1
echo "exit $?" >> $3
