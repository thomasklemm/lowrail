# usage: source env.sh rel|dbg|m2|m2dbg
case $1 in rel) R=$HOME/rubies/master;; dbg) R=$HOME/rubies/master-dbg;; m2) R=$HOME/rubies/m2;; m2dbg) R=$HOME/rubies/m2-dbg;; esac
export PATH=$R/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin
export BUNDLE_GEMFILE=$HOME/jitdiff/bundle/Gemfile BUNDLE_PATH=$HOME/jitdiff/gems-$1
