#!/usr/bin/env bash
# The uncached survey's measurements on one a1.xxlarge orb (docs/upstream/uncached-survey.md).
#   orb_run.sh setup        toolchain, PostgreSQL, sources and candidate trees under ~/w
#   orb_run.sh ir           Callgrind cells (A/A in each), all in parallel, into runs/ir-*
#   orb_run.sh wall NAME SCRIPT MODE [ARGS...]   one wall cohort into runs/wall-NAME (MODE zjit or yjit)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
runs=$here/runs
master=~/rubies/master-0d399335b7/bin/ruby
vg=~/w/valgrind-brk512
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

setup() {
  mise install ruby@4.0.10
  local r410; r410=$(mise where ruby@4.0.10)/bin/ruby
  [ -x $vg/bin/valgrind ] || BENCH_TOOL_JOBS=16 "$repo/script/bench-valgrind" $vg
  if [ ! -x $master ]; then
    [ -d ~/w/ruby ] || git clone -q --filter=blob:none https://github.com/ruby/ruby.git ~/w/ruby
    (cd ~/w/ruby && git checkout -q 0d399335b7 && ./autogen.sh && mkdir -p build && cd build &&
      ../configure --prefix="$HOME/rubies/master-0d399335b7" --enable-zjit --enable-yjit --disable-install-doc \
        --with-baseruby="$r410" > /tmp/master-configure.log && make -j16 > /tmp/master-make.log && make install > /tmp/master-install.log)
  fi
  sudo pg_ctlcluster 17 main start 2>/dev/null || true
  sudo -u postgres psql -qc "CREATE ROLE \"$(whoami)\" SUPERUSER LOGIN" 2>/dev/null || true
  mkdir -p ~/w/src ~/w/main ~/w/cand
  [ -d ~/w/src/rails ] || git clone -q --filter=blob:none https://github.com/rails/rails.git ~/w/src/rails
  git -C ~/w/src/rails checkout -q 2e299253f942ab94041cc6f210ac9d33884c210d
  for spec in bensheldon/good_job:v4.24.1:good_job-dequeue-uncached rails/solid_queue:v1.7.2:solid_queue-poller-uncached; do
    IFS=: read -r slug tag patch <<< "$spec"; name=${slug#*/}
    [ -d ~/w/src/$name ] || git clone -q --filter=blob:none https://github.com/$slug.git ~/w/src/$name
    [ -d ~/w/main/$name ] || git -C ~/w/src/$name worktree add -q --detach ~/w/main/$name $tag
    if [ ! -d ~/w/cand/$name ]; then
      git -C ~/w/src/$name worktree add -q --detach ~/w/cand/$name $tag
      git -C ~/w/cand/$name apply "$here/patches/$patch.diff"
    fi
  done
  # Side directories for the model: the side's name is what the script reads; "main" ones link Rails main's gems.
  mkdir -p ~/w/sides/base ~/w/sides/uncached
  for s in base uncached; do
    mkdir -p ~/w/sides-main/$s
    for g in activesupport activemodel activerecord; do ln -sfn ~/w/src/rails/$g ~/w/sides-main/$s/$g; done
    cp ~/w/src/rails/RAILS_VERSION ~/w/sides-main/$s/
  done
}

bench() { (cd "$repo" && script/upstream-bench --valgrind $vg "$@"); }

ir() {
  mkdir -p "$runs"
  local r410=4.0.10 m=(--warmup 300 -n 300)
  bench --out "$runs/ir-model-81-yjit" --base ~/w/sides/base --candidate ~/w/sides/uncached --gems "" \
    --with activerecord --with sqlite3 --ruby $r410 --modes yjit "${m[@]}" --names cached,uncached "$here/qc_model.rb" > "$runs/ir-model-81-yjit.log" 2>&1 &
  bench --out "$runs/ir-model-81-zjit" --base ~/w/sides/base --candidate ~/w/sides/uncached --gems "" \
    --with activerecord --with sqlite3 --ruby $master --modes zjit "${m[@]}" --names cached,uncached "$here/qc_model.rb" > "$runs/ir-model-81-zjit.log" 2>&1 &
  bench --out "$runs/ir-model-main" --base ~/w/sides-main/base --candidate ~/w/sides-main/uncached \
    --gems activesupport,activemodel,activerecord --with sqlite3 --ruby $r410 --modes interp,yjit "${m[@]}" \
    --names cached,uncached "$here/qc_model.rb" > "$runs/ir-model-main.log" 2>&1 &
  bench --out "$runs/ir-model-main-zjit" --base ~/w/sides-main/base --candidate ~/w/sides-main/uncached \
    --gems activesupport,activemodel,activerecord --with sqlite3 --ruby $master --modes zjit "${m[@]}" \
    --names cached,uncached "$here/qc_model.rb" > "$runs/ir-model-main-zjit.log" 2>&1 &
  bench --out "$runs/ir-sq" --base ~/w/main/solid_queue --candidate ~/w/cand/solid_queue --gems solid_queue \
    --with rails --with sqlite3 --ruby $r410 --modes interp,yjit --warmup 200 -n 200 --names main,uncached \
    "$here/sq_body.rb" > "$runs/ir-sq.log" 2>&1 &
  bench --out "$runs/ir-sq-zjit" --base ~/w/main/solid_queue --candidate ~/w/cand/solid_queue --gems solid_queue \
    --with rails --with sqlite3 --ruby $master --modes zjit --warmup 200 -n 200 --names main,uncached \
    "$here/sq_body.rb" > "$runs/ir-sq-zjit.log" 2>&1 &
  bench --out "$runs/ir-gj" --base ~/w/main/good_job --candidate ~/w/cand/good_job --gems good_job \
    --with rails --with pg --ruby $r410 --modes yjit --warmup 200 -n 200 --names main,uncached \
    "$here/gj_body.rb" > "$runs/ir-gj.log" 2>&1 &
  bench --out "$runs/ir-gj-zjit" --base ~/w/main/good_job --candidate ~/w/cand/good_job --gems good_job \
    --with rails --with pg --ruby $master --modes zjit --warmup 200 -n 200 --names main,uncached \
    "$here/gj_body.rb" > "$runs/ir-gj-zjit.log" 2>&1 &
  wait
}

wall() {
  local name=$1 script=$2 mode=$3; shift 3
  local ruby=4.0.10; [ "$mode" = zjit ] && ruby=$master
  mkdir -p "$runs"
  bench --out "$runs/wall-$name" --ruby $ruby --modes "" --wall 30 --wall-mode "$mode" "$@" "$here/$script" \
    > "$runs/wall-$name.log" 2>&1
}

"$@"
