#!/usr/bin/env bash
# Callgrind ablation matrix: base twice (A/A), then one piece off per run, in parallel:
#   matrix.sh APP_DIR OUT_TSV MODE N JOBS PIECE...   (a PIECE "on:csp" sets DEF8_ON instead)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$1 out=$2 mode=$3 n=$4 jobs=$5; shift 5
printf '%s\n' base base-aa "$@" | xargs -P "$jobs" -I{} bash -c '
  piece={}; off=; on=
  case $piece in base|base-aa) ;; on:*) on=${piece#on:} ;; *) off=$piece ;; esac
  DEF8_OFF=$off DEF8_ON=$on "$0/ir.sh" "$1" "$2" "$piece" "$3" "$4" || echo "FAILED $piece" >&2
' "$here" "$app" "$out" "$mode" "$n"
