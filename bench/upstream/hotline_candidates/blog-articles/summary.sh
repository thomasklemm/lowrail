# summ.sh DIR: A/A, heap and app_fix rows of a request_pairs summary
jq -r '"aa pass \(.aa.pass) (tol \(.aa.tolerance_pct)%), heap_matched \(.heap_matched), jit \(.jit.actual_jit)",
  (.layers | to_entries[] | select(.key=="off_a" or .key=="off_b" or .key=="app_fix") |
   "\(.key)\ttotal \(.value.instructions_total.value.median|round) (\(.value.instructions_total.delta_pct.median*1000|round/1000)% [\(.value.instructions_total.delta_pct.ci95|map(.*1000|round/1000)|join(", "))])\tno_gc \(.value.instructions_no_gc.value.median|round) (\(.value.instructions_no_gc.delta_pct.median*1000|round/1000)% [\(.value.instructions_no_gc.delta_pct.ci95|map(.*1000|round/1000)|join(", "))])\tobjects \(.value.allocations.value.median) (\(.value.allocations.delta_pct.median*1000|round/1000)%)"),
  "gc per request off_a/app_fix: \(.gc.off_a.minor_gc_per_request.median)/\(.gc.app_fix.minor_gc_per_request.median)"' "$1/summary.json"
