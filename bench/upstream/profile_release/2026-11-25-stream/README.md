# Streaming report (T7, Sure), 2026-11-25

Sure (16 workers) still had 825 MB of raw runs per capture with the path table, and `lowrail-profile report`
peaked at 6.16 GB RSS in 5:30 min. The report now streams each TSV and merges attributed rows into flat integer
arrays in first-seen order, so every later sum and tie, and with them report.json, are as before.

Inputs: `--keep-runs` captures from the 1618fc38 gem on Ruby 4.0.7 ([scripts/capture.sh](scripts/capture.sh)):
Blog (rc-blog-81), the fresh app (fresh-81, Rails 8.1.4.1) and Campfire; and a Sure-sized set generated from
Campfire's runs by [scripts/gen.rb](scripts/gen.rb) (`gen.rb rc-campfire big 16 10`: 16 workers, every
attributed row repeated ten times under window names that part of the workers share; run1 43 MB, run2 699 MB).

`/usr/bin/time -f "%e s %M KB" ruby -Igem/lib gem/exe/lowrail-profile report DIR`, before (1618fc38) and after:

| Runs | Raw size | Before | After | report.json and report.md |
| --- | ---: | ---: | ---: | --- |
| Blog | 1 MB | (in capture) | 0.46 s, 27 MB | identical (sha256 cd509d4fce9d08a2…) |
| Fresh app | 1.5 MB | (in capture) | 0.46 s, 38 MB | identical (e5de5ec2f785f9d9…) |
| Campfire | 44 MB | 12.0 s, 317 MB | 7.5 s, 96 MB | identical (16a90c58186fc7c0…) |
| Sure-sized | 742 MB | 211.8 s, 5,355 MB | 119.4 s, 532 MB | identical (b2ed5c77482b896f…) |

"Before" for Blog and the fresh app is the report the capture wrote with the 1618fc38 gem; `report` from the
checkout rewrote the same bytes. The test `test_report_keeps_no_object_per_attributed_row` (gem/test/profile_report_test.rb)
reports 80,000 attributed rows in two processes: the report holds about 8,400 objects after it, 326,025 for
40,000 rows before the change.
