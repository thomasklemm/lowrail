#!/usr/bin/env bash
out=$(bash /home/user/workspace/repo/.amp/in/orb-backup/nhc/bstep.sh $(git rev-parse --short=10 HEAD) 2>/dev/null) || exit 125
echo "$out" >> /tmp/bisect-steps.log
w=${out##*per_write=}
[ -z "$w" ] && exit 125
[ "$w" -ge ${BAD:-95} ] && exit 1
[ "$w" -le ${GOOD:-85} ] && exit 0
exit 125
