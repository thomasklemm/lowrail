#!/bin/bash
# fnsum.sh CGFILE DIVISOR: self Ir per function (summed over source files), divided by DIVISOR
callgrind_annotate --auto=no --inclusive=no --threshold=100 "$1" 2>/dev/null | sed -n '/file:function/,$p' | tail -n +3 |
  sed -E 's/\([ 0-9.]+%\)//' |
  awk -v d=$2 'NF>=2 {ir=$1; gsub(",","",ir); fn=$2; sub(/^.*:/,"",fn); s[fn]+=ir} END{for(k in s) if (s[k]/d>=0.5) printf "%7.1f %s\n", s[k]/d, k}' | sort -rn
