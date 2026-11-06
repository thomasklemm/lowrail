#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
base="$root/.lowrail/private/puma-cpu"
version=$1 app=$2 mode=$3 threads=$4 connection=$5 counter=$6 label=$7
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
export PUMA_SOURCE="$base/$version" PUMA_APP=$app PUMA_THREADS=$threads PUMA_CONNECTION=$connection PUMA_COUNTER=$counter
export PUMA_OUT="$base/results/$version-$app-$mode-$threads-$connection-$counter-$label.json"
[[ ! -e $PUMA_OUT && ! -e $PUMA_OUT.info && ! -e $PUMA_OUT.service.log ]] || {
  echo "refusing existing attempt: $PUMA_OUT"; exit 1;
}
mkdir -p "$base/results"
export PUMA_COUNT=${PUMA_COUNT:-2000} PUMA_RATE=${PUMA_RATE:-1000}
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000
export RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
flags=(--disable-yjit)
[[ $mode != yjit ]] || flags=(--yjit --yjit-perf)
directory=$root
if [[ $app == blog ]]; then
  export BUNDLE_GEMFILE="$root/.corpus/censuspuma-blog/Gemfile.census-1e235cee11b0"
  export CENSUS_RAILS_SHA=1e235cee11b0a7aecb189d8837534807626287aa CENSUS_MODE=$mode
  directory="$root/.corpus/censuspuma-blog"
fi
command=(ruby "${flags[@]}" -C "$directory" "$root/bench/upstream/puma_cpu/server.rb")
if [[ $counter == callgrind || $counter == stacks ]]; then
  export PUMA_COUNTER_EXT="$base/lowrail_callgrind.so"
  export PUMA_SAMPLER_EXT=${PUMA_SAMPLER_EXT:-$base/sampler-25278fbc9ff9/census_cpu_sampler.so}
  command=("$base/valgrind/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file
    --callgrind-out-file="$PUMA_OUT.callgrind" "${command[@]}")
fi
service="puma-$(printf '%s' "$PUMA_OUT" | sha256sum | cut -c1-20)"
port=${PUMA_PORT:-$(ruby -rsocket -e 's = TCPServer.new("127.0.0.1", 0); puts s.addr[1]; s.close')}
printf -v launch '%q ' env "PATH=$PATH" "PUMA_SOURCE=$PUMA_SOURCE" "PUMA_APP=$PUMA_APP" "PUMA_THREADS=$PUMA_THREADS" \
  "PUMA_CONNECTION=$PUMA_CONNECTION" "PUMA_COUNTER=$PUMA_COUNTER" "PUMA_OUT=$PUMA_OUT" "PUMA_COUNT=$PUMA_COUNT" \
  "RUBY_GC_HEAP_0_INIT_SLOTS=$RUBY_GC_HEAP_0_INIT_SLOTS" "RUBY_GC_HEAP_1_INIT_SLOTS=$RUBY_GC_HEAP_1_INIT_SLOTS" \
  "RUBY_GC_HEAP_2_INIT_SLOTS=$RUBY_GC_HEAP_2_INIT_SLOTS" "RUBY_GC_HEAP_3_INIT_SLOTS=$RUBY_GC_HEAP_3_INIT_SLOTS" \
  "RUBY_GC_HEAP_4_INIT_SLOTS=$RUBY_GC_HEAP_4_INIT_SLOTS" "BUNDLE_GEMFILE=${BUNDLE_GEMFILE:-}" \
  "CENSUS_RAILS_SHA=${CENSUS_RAILS_SHA:-}" "CENSUS_MODE=${CENSUS_MODE:-}" \
  "PUMA_COUNTER_EXT=${PUMA_COUNTER_EXT:-}" "PUMA_SAMPLER_EXT=${PUMA_SAMPLER_EXT:-}" "${command[@]}"
amp orb service start "$service" --port "$port" --command "$launch" > "$PUMA_OUT.service.log" 2>&1
trap 'amp orb service stop "$service" >> "$PUMA_OUT.service.log" 2>&1' EXIT
for ((i=0;i<1200;i++)); do
  [[ ! -e $PUMA_OUT.info ]] || break
  sleep 0.1
done
[[ -e $PUMA_OUT.info ]] || { amp orb service logs -n 10000 "$service" > "$PUMA_OUT.log"; exit 1; }
if ! ruby "$root/bench/upstream/puma_cpu/client.rb" "$PUMA_OUT" > "$PUMA_OUT.client.log" 2>&1; then
  amp orb service logs -n 10000 "$service" > "$PUMA_OUT.log"
  exit 1
fi
amp orb service logs -n 10000 "$service" > "$PUMA_OUT.log" 2>&1
[[ -e $PUMA_OUT ]] || exit 1
! rg -i 'brk segment overflow|disInstr_AMD64|dis_ESC_NONE' "$PUMA_OUT.log"
echo "$PUMA_OUT"
