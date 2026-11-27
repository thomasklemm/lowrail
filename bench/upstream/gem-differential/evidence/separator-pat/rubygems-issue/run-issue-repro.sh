#!/bin/bash
# Runs the issue's repro exactly as written in a fresh HOME and GEM_HOME: ./run-issue-repro.sh RUBY_PREFIX REPRO_FILE
d=$(mktemp -d /tmp/issrep.XXXX); mkdir -p $d/home
echo "== $(PATH=$1/bin ruby -v)"
out=$(cd $d && env -i PATH=$1/bin:/usr/bin:/bin HOME=$d/home GEM_HOME=$d/gems bash -e "$2" 2>&1); st=$?
echo "$out" | grep -v '^\s*$' | sed "s#$d#/tmp/X#g" | grep -vE '^\s{6,}/' | sed -n '1,/^## Environment/p' | grep -v '^## Environment'
echo "exit=$st"
rm -rf $d
