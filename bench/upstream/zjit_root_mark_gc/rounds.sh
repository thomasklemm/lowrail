#!/bin/bash
# Three interleaved rounds of --harness=gc: base, base2 (same binary, A/A), patch.
cd /home/user/workspace/ruby-bench
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.7/bin:$PATH
Z="--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024"
for i in 1 2 3; do
  ruby run_benchmarks.rb --harness=gc --interleave --warmup=15 --bench=30 \
    --no-sudo --turbo --no-pinning --name_filters=railsbench,lobsters,shipit \
    -e "base::/home/user/rubies/zr-base/bin/ruby $Z" \
    -e "base2::/home/user/rubies/zr-base/bin/ruby $Z" \
    -e "patch::/home/user/rubies/zr-patch/bin/ruby $Z" \
    --out_path=/tmp/fw/gc19685/out --out-name=round$i > /tmp/fw/gc19685/round$i.log 2>&1
  echo "ROUND $i EXIT $?" >> /tmp/fw/gc19685/rounds.log
done
echo ALLDONE >> /tmp/fw/gc19685/rounds.log
