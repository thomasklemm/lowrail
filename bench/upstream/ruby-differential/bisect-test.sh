#!/bin/bash
# git bisect run helper for a standalone Ruby repro (docs/upstream/ruby41-differential-1.md).
#   BUILD=~/rdiff/bisect/h2/build BAD=TypeError git bisect run bisect-test.sh REPRO [RUBY FLAGS...]
# BUILD is a configured build directory of the worktree being bisected. Exit 0 good, 1 bad (BAD in the output),
# 125 skip (miniruby does not build).
build=${BUILD:?configured build directory}
repro=$(realpath "${1:?repro file}"); shift
cd "$build" || exit 125
PATH=$HOME/.cargo/bin:$PATH nice make -j"$(nproc)" miniruby > /tmp/bisect-make.log 2>&1 || exit 125
out=$(timeout 60 ./miniruby "$@" "$repro" 2>&1)
echo "$(git -C .. rev-parse --short HEAD): $(echo "$out" | head -n 1)"
echo "$out" | grep -q "${BAD:-TypeError}" && exit 1
exit 0
