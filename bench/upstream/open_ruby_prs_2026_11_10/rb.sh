#!/bin/bash
# rb.sh RUBY BENCH OUT [ruby flags...]; env WIN_* passed through
R=$1; B=$2; O=$3; shift 3
cd /home/user/workspace/ruby-bench
BUNDLE_PATH=/home/user/workspace/bundle PATH=$(dirname $R):$PATH WIN_OUT=$O DATABASE_URL=sqlite3:/tmp/rb-$$.sqlite3 \
  $R "$@" -r/home/user/workspace/mtools/win.rb benchmarks/$B/benchmark.rb > $O.log 2>&1
echo "$B $? $O"
