#!/bin/bash
# Discourse's db:migrate rescues a failed seed (DS1 on main) and exits 0; fail when no category was created.
n=$(psql -h 127.0.0.1 -U postgres -Atc "select count(*) from categories" discourse_test 2>/dev/null)
[ "${n:-0}" -gt 0 ] && exit 0
echo "discourse-seeded.sh: db:migrate created no categories in discourse_test"
exit 1
