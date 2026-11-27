export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
export ROOT=/home/user/workspace/repo
export WORK="$ROOT/.amp/in/orb-backup/l3-review"
export OUT="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27/head-41af869c78"
export BUNDLE_PATH="$ROOT/.lowrail/gate-gems"
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR"
use_tree() {
  export RAILS="$WORK/$1"
  export BUNDLE_GEMFILE="$WORK/bundle-$1/Gemfile"
  export RUBYLIB="$RAILS/railties/lib"
}
