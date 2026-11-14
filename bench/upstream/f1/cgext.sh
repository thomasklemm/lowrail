#!/bin/bash
# cgext.sh PREFIX OUTDIR: compile bench/callgrind.c (lowrail_callgrind) for one Ruby install
set -e
export CPATH=$HOME/w/valgrind-brk512/include
mkdir -p $2
$1/bin/ruby -rrbconfig -rshellwords -e 'c = RbConfig::CONFIG; exit system(*c["LDSHARED"].shellsplit, "-fPIC", "-O2", "-I#{c["rubyhdrdir"]}", "-I#{c["rubyarchhdrdir"]}", "/home/user/workspace/repo/bench/callgrind.c", "-o", File.join(ARGV[0], "lowrail_callgrind.so"))' $2
