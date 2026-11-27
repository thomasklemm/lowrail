#!/usr/bin/env bash
set -euxo pipefail
root=/home/user/workspace/repo
scratch="$root/.amp/in/orb-backup/sq37-review"
probe="$root/bench/upstream/sq37/review-astra-2026-11-27/cached_crud_probe.rb"
database="$scratch/cached-crud.sqlite3"
cache="$scratch/cached-schema.yml"
bash "$scratch/run-cell.sh" base 3.44.2 "$probe" build "$database" "$cache"
for side in base head; do
  for sqlite in 3.35.5 3.36.0 3.37.0; do
    expected=0
    if [[ $side == head && $sqlite != 3.37.0 ]]; then expected=1; fi
    if bash "$scratch/run-cell.sh" "$side" "$sqlite" "$probe" cached "$database" "$cache"; then status=0; else status=$?; fi
    echo "CACHED_CRUD_EXIT=$status SIDE=$side SQLITE=$sqlite EXPECTED=$expected"
    [[ $status == "$expected" ]]
    if SQ37_DATABASE="$database" SQ37_SCHEMA_CACHE="$cache" bash "$scratch/run-cell.sh" "$side" "$sqlite" \
      -C "$scratch/app-cached" bin/rails runner \
      'class Widget < ActiveRecord::Base; end; w = Widget.create!(name: "cached review value"); raise unless Widget.find(w.id).name == "cached review value"; w.update!(name: "updated value"); raise unless Widget.find(w.id).name == "updated value"; w.destroy!; raise if Widget.exists?(w.id); puts "PASS: Rails runner create/find/update/destroy"'; then status=0; else status=$?; fi
    echo "CACHED_RAILS_EXIT=$status SIDE=$side SQLITE=$sqlite EXPECTED=$expected"
    [[ $status == "$expected" ]]
  done
done
if bash "$scratch/run-cell.sh" base 3.36.0 "$probe" cold "$database" "$cache"; then status=0; else status=$?; fi
echo "DEFAULT_CACHE_VALIDATION_EXIT=$status EXPECTED=1"
[[ $status == 1 ]]
