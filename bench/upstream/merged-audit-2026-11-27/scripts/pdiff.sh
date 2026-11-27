#!/bin/bash
# pdiff.sh A1 A2 B1 B2 : compare only the changed lines (+/-) per file of diff A1..A2 vs B1..B2
norm(){ git diff -U0 "$1" "$2" | awk '/^diff --git/{f=$3} /^[+-]/ && !/^(\+\+\+|---) /{print f" "$0}'; }
diff <(norm $1 $2) <(norm $3 $4)
