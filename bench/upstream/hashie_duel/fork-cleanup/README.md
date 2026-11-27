# Fork cleanup (2026-11-27)

Thomas: the fork's PR list is not our archive. All 20 open measurement PRs on thomasklemm/hashie were closed and
43 dead branches deleted, after checking that every Duel result is in Lowrail.

* **Check:** every attempt of every completed `Perf` run on the fork (99 runs, `runs.tsv`) was looked up in
  `bench/upstream/hashie_duel` and `bench/upstream/hashie_perf` by run ID and attempt. One was missing: run
  45985950306, `calib/plant-alloc` at `0c65ba6`, a head that was rebuilt 13 minutes later (its successor
  45987737817 is in `calibration-8`). Its job log, run metadata and summary are here as `plant-alloc-45985950306-a1.*`.
* **Closed:** #1–#7, #9–#17 (calibration and Callgrind calibration) and #27, #28, #29, #32 (round 2 candidates,
  recorded in `../../hashie_perf/round2/duel`). Closing keeps the Actions runs. `pulls-before.json` lists every
  fork PR with head and base before closing.
* **Deleted branches:** `branches.tsv` has every branch with its tip and whether it was kept.
  `deleted-branches.bundle` holds the 41 deleted tips that upstream master doesn't contain (the other two,
  `perf-base` and `thomasklemm/duel-zjit`, are ancestors of it); restore one with
  `git fetch deleted-branches.bundle refs/remotes/fork/BRANCH` in a hashie clone.
* **Kept:** `master`; `1-1-stable`, `3-3-stable` and `create-github-action`, which the fork inherited from upstream;
  and the three candidate branches of queue items HM3, HM4 and HM5. No upstream PR was open at the time.

From now on a fork measurement PR is closed, and its branch deleted, as soon as its data is recorded.
