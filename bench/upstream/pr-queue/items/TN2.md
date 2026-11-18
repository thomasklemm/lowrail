---
id: TN2
repo: ruby/ruby
kind: fix
area: time.c, Time.new with a zone object that converts with to_str
reviewer: "nobu (time.c, 337b4b6344)"
branch: thomasklemm/time-new-to-str-utc
head: "a0670a0a30fad39d37658d02b0085d0f69c4ed99"
base: master
built_on: "3a19e2efcf"
depends_on: []
stacked_on:
alternative_of:
impact: "Time.new(2026, 1, 1, 0, 0, 0, o) segfaults when o.to_str is \"UTC\", \"Z\" or \"-00:00\" (3.3 to master), and a zone name via to_str gets the system local time; time.c +5"
rank: 4
risky: false
state: built
pr:
note: "2026-11-18: side finding of the claude-code pass on TN1, built in orb T-01a1ebed-fc8b-70a3-998f-34884eb65f6a (docs/upstream/ruby-time-new.md, TN2 section). time_init_vtm's zone-object fallback stored utc_offset_arg's UTC_ZONE (Qundef) in vtm.utc_offset and passed it to vtm_add_offset (gdb: flo_cmp on 0x24), and didn't return after a successful find_timezone. Crash on 3.3.13, 3.4.12, 4.0.9 and master 3a19e2efcf; wrong instant on the same. Unreported on Redmine and GitHub. New tests segfault/fail on master and pass on the head; btest 2148, test_time* 246 (295 with TZInfo, three TZs), spec/ruby/core/time 652, all green; merge-tree with TN1 clean. Not to open now (ruby/ruby moratorium); Thomas decides between a Redmine report with the draft in the doc and a PR."
passes: []
---

# Fix Time.new with a zone object that converts to "UTC" or a zone name

A zone argument that isn't a String or an Integer is tried as a timezone object first. When it has no `local_to_utc`, `time_init_vtm()` falls back to `utc_offset_arg()`, which converts it with `to_str`. Two results of that fallback weren't handled:

```ruby
o = Object.new
def o.to_str = "UTC"   # also "Z", "-00:00"
Time.new(2026, 1, 1, 0, 0, 0, o)  # [BUG] Segmentation fault
```

`utc_offset_arg()` returns `UTC_ZONE` (`Qundef`) for these, which was then used as an offset in `vtm_add_offset()`. It now takes the UTC path, as a String `"UTC"` does.

When `Time.find_timezone` resolves the converted name, `zone_timelocal()` set up the time, but the code went on and recomputed it as system local time. It now returns there, so the result matches passing the name as a String.
