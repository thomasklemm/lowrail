#!/usr/bin/env bash
# ir_region.sh SETUP_RB EXPR [N] [WARMUP]: Callgrind instructions per evaluation of EXPR, counting only the
# measured loop (Lowrail's bench/callgrind.c client requests, --instr-atstart=no), GC disabled, as
# (Ir(N) - Ir(0)) / N after WARMUP calls. For setups whose boot varies more than N calls cost (a Rails app),
# where ir.sh's whole-process difference is unusable. RUBY_BIN picks the Ruby, RUBYFLAGS adds --yjit or
# --zjit; BUNDLE_GEMFILE and RUBYOPT=-rbundler/setup select a bundle.
set -euo pipefail
export PATH=${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.7/bin}:$PATH
setup=$1 expr=$2 n=${3:-5000} warm=${4:-500}
root=$(cd "$(dirname "$0")/../../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ruby -rrbconfig -rshellwords -e '
  cc = RbConfig::CONFIG.fetch("LDSHARED").shellsplit
  exit system(*cc, "-fPIC", "-O2", "-I#{RbConfig::CONFIG.fetch("rubyhdrdir")}", "-I#{RbConfig::CONFIG.fetch("rubyarchhdrdir")}",
    ARGV[0], "-o", ARGV[1])' "$root/bench/callgrind.c" "$work/lowrail_callgrind.so"
run() {
  valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file --callgrind-out-file="$work/out.$1" \
    --log-file="$work/log.$1" ruby ${RUBYFLAGS:-} -e "require '$work/lowrail_callgrind'; load '$setup'; f = -> { $expr }
      $warm.times { f.() }; GC.start; GC.disable; LowrailCallgrindBench.start(false); $1.times { f.() }; LowrailCallgrindBench.finish"
  cat "$work"/out."$1"* | awk '/^totals: /{s += $2} END {print s}'
}
a=$(run 0); b=$(run "$n")
echo $(( (b - a) / n ))
