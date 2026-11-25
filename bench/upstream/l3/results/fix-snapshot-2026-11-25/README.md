# L3 snapshot fix, 2026-11-25

Head cf1607c76d (thomasklemm/attrs-for-database-row-2) on rails/rails main f785381cca, Ruby 4.0.9. Applies the
thermos-sol must-fix from results/review-thermos-sol-2026-11-25: `values_for_database` reads the attributes from a
copy of the set's Array after `materialize`, as main's row copy did, plus one Active Record test (head.diff).

* probe-sha256.txt: review_probe.rb (676 lines) and the reviewer's exactness_extension.rb (718 lines) are
  byte-identical on main and this head; the extended main output also equals the reviewer's review-probe-main.
* suites.txt: Active Model and Active Record SQLite; the 5 errors need the sqlite3 CLI (4) and the pg gem (1).
* body-ips.txt: l3_ips.rb, --yjit, core 1, 6 rounds main/l3/main2 (ips_rounds.sh, ~/ips symlinked to three
  checkouts). Best: Marshal.dump 37.565k -> 44.518k (+18.5%), attributes_for_database 92.033k -> 154.469k (+67.8%),
  main2 -1.5% / -0.8%.
* allocs.txt (l3_allocs.rb): warm record attributes_for_database 4 -> 2, attributes_before_type_cast 4 -> 1,
  Marshal.dump 16 -> 14; first call on a fresh record 78 -> 74.
