#!/usr/bin/env bash
# Lists the Ractor tests of Action Pack and Action View that pass on the
# control Ruby, one "component/file<TAB>Class#test = s = ." line each.
r=${CONTROL_RUBY:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}
for comp in actionpack actionview; do
  cd $HOME/src/rails-c/$comp
  for f in $(rg -l -i ractor --glob '*_test.rb' test); do
    PATH=$r:$PATH BUNDLE_PATH=$HOME/src/bundle PARALLEL_WORKERS=1 bundle exec ruby -Itest -Ilib -I../activesupport/lib -I../actionpack/lib -I../actionview/lib -I../activemodel/lib $f -n /[Rr]actor/ -v 2>/dev/null | grep -a -oE '^[A-Za-z0-9_:]+#test_[^ ]+ = [0-9.]+ s = .' | sed "s#^#$comp/$f\t#"
  done
done
