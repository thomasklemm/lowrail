# hashie leads after HM1 (2026-11-26)

Where hashie still allocates once hashie/hashie#656 (HM1) is applied, and whether each site is worth a PR. Bar: a
change cuts about 2% of its workload in interpreter instructions (A/A-gated, `script/upstream-bench`), or in YJIT
when JIT-flat. **No lead clears it; nothing is queued.**

## Where the leads came from

* **Apps** (existing lowrail-profile captures from the 2026-11-25 hot-lines run, reanalysed for every hashie line,
  not a new app run): Huginn (hashie 5.2.0, jobs), Forem and CodeTriage (5.1.0), OSM and Dawarich (5.2.0). Beyond
  HM1's two lines (#3 `method_suffix`, #5 `log_collision?`), what remains is: Forem's and CodeTriage's 5.1.0 lines
  `convert_key` `to_s`, `Array.new(map)` and `dup`, already fixed on master by #613, #615 and #614; `initialize` →
  `deep_update` splat (Forem 39 objects/request, 0.23%; CodeTriage 0.10%; Huginn 26/job); nested Mash and
  Hashie::Array construction (inherent); `convert_value`'s `val.dup if duping` (Huginn 1.3/job); the collision
  warning's message (Huginn 2.2/job, 5 of 89 jobs). A real rerun on master + HM1 was not done: no app checkouts here,
  and CodeTriage's lock has a dependency pinning `hashie < 6`, so the apps can't load master without overriding it.
* **Duel benchmarks** (`ObjectSpace` allocation sites per scenario on master + HM1, `alloc_sites.rb`; per-call counts `objects.rb`
): the sites behind L1–L4 below.

## Leads

| ID | Change (one line each, on master `e1adebc`) | Objects saved (master + HM1) | Result |
|---|---|---|---|
| L1 | `_log_collision?`: `regular_key?(method_key.is_a?(Symbol) ? method_key.name : method_key.to_s)` | Mash.new(api) 21→19, deep_merge 27→22, overwrite 7→6 | **Dropped.** `body/HL1`: interp ±0.0–0.2% (two rows inside A/A), YJIT −0.3% to +0.3% (JIT-flat), ips all inside A/A. The `is_a?` branch costs what the String saved. |
| L2 | `initialize`: `_deep_update(source_hash)` instead of `deep_update(source_hash)` | Mash.new(api) 21→17, deep_merge 27→23 (one splat Array per Mash) | **Dropped, behaviour change.** `deep_update` is an extension point real subclasses override and rely on during construction: dropbox-api 0.3.2 `Dropbox::API::Object#deep_update` (disables recursive conversion), zverok/cobb `Cobb::Mash#deep_update` (drops nils). A rest parameter allocates even when empty in the interpreter (`rest_alloc.rb`), so no signature keeps the hook and saves the Array. |
| L3 | `_method_name_and_suffix`: `method_name.is_a?(Symbol) ? method_name.name : method_name.to_s` | method write 7→6, suffix reads 16→13 | **Dropped, slower.** `body/HL3`: interp +0.2% to +0.5%, YJIT +0.9% to +1.8% (JIT-flat), ips inside A/A. Not seen in any app's profile either. |
| L4 | `convert_value`: drop `val = val.dup if duping` | 1 Hash per nested Hash (1 of 21 in Mash.new(api)) | **Not built.** Too small; the copy (since 2009/2012) keeps a subclass's `initialize` from holding or mutating the caller's nested Hash. |

Not a lead: building the collision warning when the logger discards it (Huginn 2.2/job, only apps that silence the
logger instead of using `Mash.quiet`/`disable_warnings`).

`body/HL1` and `body/HL3` are full `script/upstream-bench` runs (Ruby 4.0.9, interp + YJIT, benchmark-ips 3 rounds,
master `e1adebc` vs the one-line change uncommitted on master); their scripts are `hl1_body.rb` and `hl3_body.rb`
with `repository.json`, the Duel fixture.
