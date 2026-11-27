#!/bin/bash
# ttable.sh RUN LABEL4: ns per call from four tbench.rb logs (base, head, base again, a variant) and ratios to the base mean.
cd "$(dirname "$0")"; r=$1
paste $r-0-*.txt $r-1-*.txt $r-2-*.txt $r-3-*.txt | awk -F'\t' -v l="$2" 'BEGIN{printf "%-18s %10s %10s %10s %10s %8s %8s %8s\n","case","base","head","base2",l,"head/b","A/A",l"/b"} $1!="checksum"{b=($2+$6)/2; printf "%-18s %10.1f %10.1f %10.1f %10.1f %7.2fx %7.2fx %7.2fx\n",$1,$2,$4,$6,$8,$4/b,$6/$2,$8/b}'
