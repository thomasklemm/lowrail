#!/bin/sh
# Mirrors the createbuckets and copyfixturefiles services of docker/docker-compose-test-and-ci.yml.
mc alias set myminio http://127.0.0.1:9000 minioadmin minioadmin >/dev/null
for bucket in gumroad-specs gumroad-invoices; do
  mc ls myminio/$bucket >/dev/null 2>&1 || { mc mb myminio/$bucket; mc anonymous set public myminio/$bucket; }
  mc version enable myminio/$bucket
done
while IFS= read -r f || [ -n "$f" ]; do [ -z "$f" ] && continue; mc cp "/fixtures/$f" "myminio/gumroad-specs/specs/$f" >/dev/null || exit 1; done < /fixture-files-private.txt
while IFS= read -r f || [ -n "$f" ]; do [ -z "$f" ] && continue; mc cp "/fixtures/$f" "myminio/gumroad-specs/specs/$f" >/dev/null || exit 1; mc anonymous set download "myminio/gumroad-specs/specs/$f" >/dev/null; done < /fixture-files-public.txt
echo fixtures copied
