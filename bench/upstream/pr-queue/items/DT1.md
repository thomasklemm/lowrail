---
id: DT1
repo: rails/rails
kind: perf
area: Active Model dirty tracking
reviewer:
branch: thomasklemm/dirty-skip-untouched
head: "4e635c7ca5aa5e66f51bbf6b1c5b9c9ae3a0ed57"
base: main
built_on: "088fc0cf61"
introduced_by:
depends_on: []
stacked_on:
alternative_of: L6
impact: "Less work instead of cheaper calls (L6 closed). Dirty tracking builds an Attribute for every column of a loaded record: changed?/has_changes_to_save?/changed_attribute_names_to_save check every attribute, and forget_attribute_assignments after a save builds and replaces all of them. DT1 skips attributes that are still raw row values (not built, not cast), which can't have changed. Objects per call, Ruby 4.0.10, 30 columns: find + update! of one column 300 -> 246, find + changed? 90 -> 59; at 100 columns 466 -> 272 and 184 -> 83; serializable_hash unchanged. Wall time (paired, interleaved, 6 rounds of fresh processes, 95% bootstrap CI, main2 as A/A), ZJIT on master 42a644f6e0 at 30 columns: find + changed? -18.7% [-23.7, -13.4], find + update! -6.5% [-11.8, -1.7], update! of a reused record -6.8% [-10.3, -3.4]; at 100 columns -33% / -15% / -11%; at 10 columns only changed? moves (-11%). YJIT 4.0.10 at 30 columns -30.5% / -13.2% / -4.7%. Callgrind (script/upstream-bench, 4.0.10, no JIT, 30 columns): find + update! 2,111,005 -> 1,871,399 (-11.4%), find + changed? 712,854 -> 486,626 (-31.7%), A/A <= 0.06%; YJIT -13.5% / -34.2% not JIT-flat, no claim. Real request: Hackatime PATCH display name (users, 42 columns, PostgreSQL) -28 objects of 2,948 (A/A within 6). Bench raw: bench/upstream/lead6/realworld-2026-11-27. Callgrind body run: bench/upstream/dt1/body/DT1-2026-11-27. Reach: every save and dirty check of a loaded record on Rails main; per call it is proportional to the untouched columns."
evidence: [bench/upstream/lead6/realworld-2026-11-27, bench/upstream/dt1/body/DT1-2026-11-27]
rank:
risky: true
pr:
state: built
note: "2026-11-27: built in T-01a21d30-f768-7457-9b12-665c25e3039c as L6's replacement after Thomas closed #60016 (do less work, not inline helpers). Not reviewed, not opened. Readability: adds two set methods (touched_keys, forgetting_assignments) and one private predicate (untouched?), about L2 (new helper), so it needs an app-measurable effect: Hackatime PATCH shows -28 objects (~1%); request wall time not shown outside A/A yet. Exactness so far: AM 1,223 runs, AR SQLite 10,459 (4 errors need the sqlite3 CLI, same on main), AR PostgreSQL 11,391 runs, 0 failures; differential probe of 68 record states (load, partial select, extra column, new, dup, clone, becomes, Marshal, YAML, frozen, locking, callbacks, in-place mutation of string/json/serialized/binary before and after save, will_change!, restore, clear, touch, update_columns) identical on main and head after masking now-timestamps and addresses. Risky: touches record loading and dirty tracking. Needs thermos-sol and Astra (adversarial) and Thomas before opening."
ownership: {date: 2026-11-27, checked: ["open PRs naming attr_names, touched_keys, forgetting_assignments, attribute_at, untouched?, forget_attribute_assignments that change activemodel/lib/active_model/attribute_mutation_tracker.rb, activemodel/lib/active_model/attribute_set.rb, activemodel/lib/active_model/dirty.rb"], hits: []}
passes: []
---

# Skip attributes that are only in the row when tracking changes

(Body not written yet: drafted after reviews decide the change is worth opening.)
