#!/bin/bash
# build.sh <rev> : extracts graphql-c_parser at rev into /tmp/gqb/<rev> and compiles the extension
set -e
rev=$1; out=/tmp/gqb/$rev
rm -rf $out; mkdir -p $out
git -C /tmp/gr archive $rev graphql-c_parser | tar x -C $out
cd $out/graphql-c_parser/ext/graphql_c_parser_ext
mise exec ruby@4.0.9 -- ruby extconf.rb >/dev/null && make -s -j4 >/dev/null 2>$out/make.err
cp graphql_c_parser_ext.so $out/graphql-c_parser/lib/graphql/
echo "$rev built"
