# autobisect.sh LO_IDX HI_IDX THRESHOLD OUT: binary search over /tmp/fp.txt lines (first-parent) for the first
# commit whose fresh Ir/row exceeds THRESHOLD (lo below, hi above), measuring with bisect.sh in ~/l7/bis1.
set -u
lo=$1 hi=$2 th=$3 out=$4
cp /tmp/fp.txt $HOME/l7/fp.txt
while [ $((hi - lo)) -gt 1 ]; do
  mid=$(( (lo + hi) / 2 )); c=$(sed -n ${mid}p $HOME/l7/fp.txt)
  bash /home/user/workspace/repo/bench/upstream/l7/bisect.sh $HOME/l7/bis1 $out $c
  v=$(tail -1 $out | awk '{print $3}')
  if awk -v v="$v" -v t="$th" 'BEGIN { exit !(v > t) }'; then hi=$mid; else lo=$mid; fi
done
echo "first above: $(sed -n ${hi}p $HOME/l7/fp.txt)" >> $out
