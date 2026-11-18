#!/usr/bin/env bash
cd /home/user/workspace/repo/bench/upstream/rk3/req
while ! grep -q DONE /tmp/fh-yjit.txt 2>/dev/null; do sleep 5; done
NOGC=1 WL=$PWD/wl-interp.txt ../../outside_leads/req/batch2.sh /tmp/fh-interp2.txt interp ../../rk3/req/none.rb ../../rk3/req/none.rb ../../rk3/req/rk3.rb ../../rk3/req/rk34.rb ../../rk3/req/none.rb
cd /home/user/workspace/repo
mise exec ruby@4.0.9 -- script/upstream-bench --out bench/upstream/rk3/body/RK3 --base /home/user/up/rack-main --candidate /home/user/up/rack --ruby 4.0.9 --valgrind /home/user/w/valgrind-brk512 --modes interp,yjit --ips 3 --names main,branch bench/upstream/rk3/RK3_body.rb > /tmp/ub.log 2>&1
echo "UB EXIT $?" >> /tmp/ub.log
