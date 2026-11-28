#!/bin/bash
# a1.large reruns of recorded a1.xxlarge wall cohorts, same scripts and settings.
cd /home/user/workspace/repo
export PATH=/home/user/.local/share/mise/installs/ruby/4.0.10/bin:$PATH
O=bench/upstream/timing_a1_large
R40=4.0.10
RM=/home/user/w/ruby-master-inst/bin/ruby
SC="--base /home/user/w/sc-base --candidate /home/user/w/sc-cand --with railties --with activerecord --with actioncable --with sqlite3 --names main,branch"
AS="--base /home/user/w/rails-main --candidate /home/user/w/rails-asc1 --gems activesupport,activemodel,activerecord --with sqlite3 --names main,branch"
t() { local name=$1; shift; local s=$(date +%s); echo "START $name $(date -u +%FT%TZ)"; "$@"; echo "END $name exit=$? secs=$(( $(date +%s) - s ))"; }
t SC1-yjit  script/upstream-bench --out $O/SC1-yjit  $SC --ruby $R40 --modes "" --ips 5 --wall 30 --wall-mode yjit --warmup 500  bench/upstream/solid_stack/sc1_body.rb
t SC1-zjit  script/upstream-bench --out $O/SC1-zjit  $SC --ruby $RM  --modes "" --wall 30 --wall-mode zjit --warmup 2000 bench/upstream/solid_stack/sc1_body.rb
t ASC1-yjit script/upstream-bench --out $O/ASC1-yjit $AS --ruby $R40 --modes "" --wall 30 --wall-mode yjit --warmup 3000 bench/upstream/census13r/asc1_body.rb
t ASC1-zjit script/upstream-bench --out $O/ASC1-zjit $AS --ruby $RM  --modes "" --wall 30 --wall-mode zjit --warmup 3000 bench/upstream/census13r/asc1_body.rb
echo ALL_DONE
