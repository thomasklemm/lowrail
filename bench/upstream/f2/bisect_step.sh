#!/bin/bash
# git bisect run step: build miniruby, measure (heap2_equal - empty) Ir per iteration; bad if above THRESH
cd /home/user/w/src-bisect
export PATH=/home/user/.local/share/mise/installs/ruby/4.0.7/bin:$PATH
log=/home/user/w/bisect-build.log
sha=$(git rev-parse --short=10 HEAD)
build() {
  [ -f Makefile ] || { ./autogen.sh && ./configure --disable-install-doc --with-baseruby=/home/user/.local/share/mise/installs/ruby/4.0.7/bin/ruby; } >> $log 2>&1
  make -j4 miniruby >> $log 2>&1
}
if ! build; then git clean -fdxq -e '!*.log'; build || exit 125; fi
m() {
  export PATH=/home/user/w/valgrind-brk512/bin:$PATH
  local r=()
  for n in 0 200000; do
    r+=($(LD_PRELOAD=/home/user/w/shim/fixseed.so F1_SEED=1 setarch -R valgrind --tool=callgrind --callgrind-out-file=/dev/null ./miniruby --disable-gems -e "${1//N/$n}" 2>&1 | awk '/Collected/ {print $4}'))
  done
  echo $(( (r[1] - r[0]) / 200000 ))
}
eq=$(m 'h = {1e300 => 1, 2e300 => 2}; k = 1e300 * 1; i = 0; while i < N; h[k]; i += 1; end')
em=$(m 'h = {1e300 => 1, 2e300 => 2}; k = 1e300 * 1; i = 0; while i < N; h; i += 1; end')
d=$((eq - em))
echo "$sha $(git log -1 --format=%cs HEAD) equal=$eq empty=$em diff=$d" >> /home/user/w/bisect-results.txt
[ $d -gt ${THRESH:-400} ] && exit 1 || exit 0
