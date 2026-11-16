# source env.sh LABEL — LABEL is r409 (Ruby 4.0.9), master, or zjit (master with RUBYOPT=--zjit).
# Isolated from the global Ruby setup; each Ruby keeps its gems under $R3/bundle/ruby/<ABI>.
LRB=${LRB:-$HOME/Code/lowrail-bench}
R3=${R3:-$LRB/r3}
case "$1" in
  r409) RUBY_BIN=$LRB/rubies/a/bin ;;
  master|zjit) RUBY_BIN=$LRB/install/r3master/bin ;;
  *) echo "unknown label: $1" >&2; return 2 ;;
esac
unset GEM_HOME GEM_PATH RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE
export PATH="$RUBY_BIN:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
export HOME="$R3/home" BUNDLE_USER_HOME="$R3/home/bundle" GEM_SPEC_CACHE="$R3/home/gemcache"
export BUNDLE_PATH="$R3/bundle" BUNDLE_FROZEN=true
export PKG_CONFIG_PATH="$(/opt/homebrew/bin/brew --prefix openssl@3)/lib/pkgconfig"
# macOS aborts forked test workers that touch an Objective-C class another thread was initializing (seen with
# Hackatime on 4.0.9 too); this is the standard workaround and has no effect on Linux.
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export RAILS_ENV=test PARALLEL_WORKERS=${PARALLEL_WORKERS:-4}
[ "$1" = zjit ] && export RUBYOPT=--zjit
mkdir -p "$HOME"
