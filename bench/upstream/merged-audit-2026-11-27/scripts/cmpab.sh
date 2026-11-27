#!/bin/bash
# cmpab.sh DIR A B M : changed-line diff between our head A and final PR head B; bases taken against M^1 (landing parent)
cd ~/w/gems/$1 2>/dev/null || cd $1
A=$(git rev-parse $2); B=$(git rev-parse $3); M=$(git rev-parse $4)
echo "##### $1 ${A:0:10}..${B:0:10}"
git log --format='  %h %an/%cn %s' $(git merge-base $A $B)..$B | head -15
/home/user/workspace/repo/.amp/in/orb-backup/pdiff.sh $(git merge-base $A $M^1) $A $(git merge-base $B $M^1) $B
