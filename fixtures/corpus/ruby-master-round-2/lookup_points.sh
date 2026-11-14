cd ~/w/bis
for c in d375bcc965 7da70f1773~1 7da70f1773 0b2edb5b9a~1 0b2edb5b9a b7e8fad022; do
  git checkout -q $c && bash ~/workspace/repo/.amp/in/orb-backup/bisect_hashlookup.sh print; echo "$c done" >> ~/w/logs/bisect-lookup.log
done
