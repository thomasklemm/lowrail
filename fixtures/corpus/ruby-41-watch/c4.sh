#!/bin/bash
# c4.sh RUBY APP MODE CMD [OUT]   RUBY: 4.0.7 | master-b51db981
root=/home/user/workspace/repo
rb=$1; n=$2; mode=$3; cmd=$4; out=$5
dir=$root/.corpus/census4-$n
[ $n = fizzy-mysql ] && dir=$root/.corpus/census4-fizzy-mysql
export BUNDLE_FROZEN=true RAILS_ENV=production RACK_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_LOG_LEVEL=fatal SKIP_TELEMETRY=1 APP_VERSION=census APP_HOST=localhost RUBY_YJIT_ENABLE=0 RUBY_ZJIT_ENABLE=0 CENSUS_MODE=$mode
case $n in
  codetriage|pingcrm) export DATABASE_ADAPTER=postgresql ;;
  fizzy-mysql) export DATABASE_ADAPTER=mysql MYSQL_USER=root MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307 ;;
  *) export DATABASE_ADAPTER=sqlite ;;
esac
unset RUBYOPT
cd $dir
flags=""; [ $mode = yjit ] && flags=--yjit; [ $mode = zjit ] && flags=--zjit
script=$root/bench/upstream/rails_main_census_4.rb
if [ -n "$CENSUS_VALGRIND" ]; then
  exec mise exec ruby@$rb -- bundle exec valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
    --callgrind-out-file=$CENSUS_VALGRIND --log-file=$CENSUS_VALGRIND.log \
    $(mise where ruby@$rb)/bin/ruby $flags $script $cmd $n $out
fi
exec mise exec ruby@$rb -- bundle exec ruby $flags $script $cmd $n $out
