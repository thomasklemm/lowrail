# M0 — ARGOS (private app, aggregate numbers only)

ARGOS is a private Rails app; no code from it is checked in here. Measured
2026-10-19 in its own orb by a separate thread, without Lowrail.

**Stack:** Ruby 4.0.7, Rails 8.1.4, PostgreSQL 18, Bootsnap 1.26, Minitest 6
with fixtures, inertia_rails 3.22 (React, Vite), Alba serializers, Typelizer,
sorbet-runtime (T::Struct/T::Enum), GoodJob, Doorkeeper, WebMock/VCR.
177 gems.

**Tests:** 10,816 unit + request tests (8 workers, 80 s, 0 failures, 1 skip),
552 system tests, 3 backup e2e tests.

**Boot:** test eager boot ≈3.0 s. 1,063 Ruby files with 8,952 `def`s;
85 models, 99 controllers, 125 Inertia page modules. Methods directly
defined on app classes: 17,273 after eager load, **51,692 after schema
load and `define_attribute_methods`** — eager loading alone misses 34k
methods generated later (mostly ActiveModel attribute/dirty methods). The
facts dumper therefore loads schema and attribute methods per model.

**Where time goes (request/controller tests, StackProf wall, YJIT):** self
time PG exec 24 %, GC ≈8 %, activerecord 18 % (Ruby side), app + lib 3.6 %,
Inertia 0.5 %, Alba ≈1 % total. Three authenticated Inertia JSON page visits:
9.5–29 ms median, 9–26 SQL queries each. In those requests
**`Digest::Base#update` is 12.8 % self**, traced to the Inertia asset version:
the Vite manifest digest is recomputed from the file on every request.

## Conclusions for Lowrail

1. Data access dominates; lowering cannot remove SQL. Active Record
   attribute/type/reflection dispatch is the framework target (agrees with
   Campfire uncached).
2. Per-request work that depends only on boot-fixed inputs is the clearest
   win: the asset-version digest is a function of a file that does not change
   while the process runs. A guarded memo (file identity/digest as the fact)
   is a candidate pass; arbitrary version procs are not assumed pure.
3. Serialization plans (Inertia props, Alba) from fixed descriptors are a
   later candidate; values and partial/deferred-prop semantics stay dynamic.
4. Equivalence risks: 243 test files use stubs or dynamic method
   techniques, 137 use time travel; a custom stub helper swaps singleton
   methods. Guards must observe lookup, singleton, ancestor, schema and config
   changes (the gem's guard tests cover the singleton cases).

## First Lowrail iteration (2026-10-20)

Same private application checkout as the baseline; Ruby 4.0.7, Rails 8.1.4,
local PostgreSQL on port 5433. No application source, class/file/test names,
payloads or credentials are included here. Runtime integration used only
`RUBYOPT=-I<lowrail>/gem/lib -rlowrail/setup`, not an application commit.
The application Gemfile and lockfile were unchanged.

### Build and differential gates

`lowrail facts APP` captured 9,222 named modules, 122,922 methods, 5,816
distinct generated scripts, and 52,017 app-relevant methods (36,650 linked
to generated bodies). No errors; one absent cache table was explicitly skipped.

`lowrail build APP` lowered **235/280 route sites in 61 units**, spanning
57 Ruby files and four templates. `view/link_to`: **0/0** sites, not a failed
pass. Refusals: 36 options hashes, four explicit receivers, two direct/resolve
helpers, two routes with requirements/globs, one class/module-body call.
These are deliberate original-Rails boundaries, not suppressed diagnostics.
The known-regressing preload pass remained opt-in and was not enabled.

The initial unit/request verify was identical but vacuous: **zero guard hits,
794 guard fallbacks**. An unrelated mounted engine's singleton script-name
method disabled every unit through a global route-set fact. The fix leaves
script-name resolution and URL finishing dynamic, after argument conversion
and path formatting, instead of disabling the guard or caching engine state.
Public emitted-Ruby regression fixtures cover both path and URL helpers,
defaults, mutation of URL options, and observable evaluation order.

Final commands, run sequentially with `VCR_RECORD_MODE=none`, seed **1729**:

```sh
PARALLEL_WORKERS=8 lowrail verify APP --bisect -- bin/rails test --seed 1729
env -u PARALLEL_WORKERS SYSTEM_PARALLEL_WORKERS=4 \
  CUPRITE_PROCESS_TIMEOUT=30 CUPRITE_TIMEOUT=30 CAPYBARA_MAX_WAIT_TIME=5 \
  lowrail verify APP --bisect -- bin/rails test:system --seed 1729
```

| Gate | Off | On | Outcome identities | Guard hits / fallbacks |
|---|---:|---:|---|---|
| Unit + request | 10,816, 60.2 s | 10,816, 62.5 s | 10,815 pass + same one skip | 794 in 58 units / 0 |
| System | 552, 92.7 s | 552, 93.7 s | 552 pass, no skips | 226 in 39 units / 0 |

Both match the earlier baseline counts and are **identical per test** to their
fresh off controls, not just equal totals. `--bisect` was enabled throughout;
there were no divergent outcomes to bisect and no denylist was written.
These final runs include the per-file loader-policy changes and both fixes at
[`698f738`](https://github.com/thomasklemm/lowrail/commit/698f738c7279494ac929a78a15ec04213b57bbcc).
Suite times are not performance benchmarks (parallel scheduling and browser
load differ). These counters record guard acceptance/rejection; an inner
runtime-condition fallback is not separately counted by the current emitter.
Three units (6, 7, 12) remain unexercised: each is an organization-missing
redirect behind an earlier onboarding/authentication check, not a stuck guard.

Generic fixes are published as
[`9fa9bd1`](https://github.com/thomasklemm/lowrail/commit/9fa9bd13313ad0314f606d37e221b66616751b8f)
(dynamic route finishing) and
[`698f738`](https://github.com/thomasklemm/lowrail/commit/698f738c7279494ac929a78a15ec04213b57bbcc)
(template source classification for types). At that revision, Rust: 22 unit
tests and two integration harnesses pass; optional corpus bodies are absent
in this checkout. Gem: 57 tests, 598 assertions, no failures/errors, ten
explicit optional-dependency/corpus skips. These are not full corpus claims.

### Types and MCP

`lowrail types APP` succeeds: **14,734 signatures**, **3,053 non-`untyped`
returns** (about 20.7%). This is not 14,734 precisely inferred methods.
The first run falsely diagnosed 23 raw template sources as invalid Ruby;
the generic fix excludes known template source locations from the Ruby-body
walker. A public fixture retains a real malformed-Ruby diagnostic as a
negative control. Template return inference remains unsupported, not fabricated.

The stdio MCP smoke initializes, lists six tools, and answers `type_of` plus
`diagnostics` without protocol/tool errors. Final source diagnostics: **0**.

### Interleaved request and boot measurements

Five fresh-process off/on pairs, alternating order, YJIT enabled; each of
three authenticated Inertia JSON pages gets 100 warmups and 200 measured
requests per process. Authentication, frozen time, fixtures, matching version
header and query-cache clearing reproduce the baseline recipe. Every response
has the expected component and successful status. Stats and StackProf are off
for these timings; the off process loads setup but sets `LOWRAIL=0`.
Numbers are the median of five run medians; parentheses give their min–max,
not a confidence interval.

| Page | Off, ms | On, ms | Median change |
|---|---:|---:|---:|
| Overview | 17.650 (16.658–19.248) | 17.712 (17.543–18.796) | +0.35% |
| List | 8.111 (7.952–8.373) | 8.416 (7.988–8.990) | +3.76% |
| Profile settings | 6.448 (5.933–6.575) | 6.555 (6.365–6.868) | +1.67% |

All differences are **within the observed run-to-run noise**, not a demonstrated
speedup or slowdown. Request allocation medians are unchanged to rounding
(23,120 / 5,152 / 3,830); query counts stay 26 / 12 / 9. A separate on/stats
run confirms **zero reached route units on these pages**, despite five
delivered lowered Ruby files. The suite hits do not imply these pages exercise
the pass.

Five alternating fresh-process test/eager-boot pairs, YJIT on, no stats:
**2.89 s off (2.68–3.27) vs 2.95 s on (2.84–3.35)**, +2.1%, also within
noise. Unlike request controls, boot-off has no Lowrail setup in `RUBYOPT`.
This is warm-filesystem process startup, not cold OS-cache boot.

### Profile and next three candidates

A separate short on run profiles 200 requests per page with StackProf wall,
1 ms interval, after the same 100 warmups: 7,286 reported samples, one missed
sample and one sample without a raw stack. Inclusive areas count a sample
once even when a frame recurs; categories overlap and must not be added.
PostgreSQL execution alone is **30.5% self** and cannot be removed by Ruby
lowering. Next candidates, in order:

1. **Asset-version digest from a guarded file fact:** digest update is
   **15.8% self**, manifest digest **17.3% inclusive**. Per-page digest self
   shares are 9.6% / 21.7% / 27.2%, versus 12.8% combined in the older
   baseline. The per-request digest is still present, not already cached.
2. **Active Record query-shape/Arel planning:** `build_arel` and Arel visitors
   are **5.4% inclusive, 1.5% self**. Guard fixed schema, method definitions
   and query shape; keep binds, scopes, rows and SQL execution dynamic.
3. **Active Record/Active Model attribute and type dispatch:** **2.7%
   inclusive, 0.84% self**, including type lookup, readers and conversion
   dispatch. A guarded descriptor plan must not cache values, time-zone
   results or effects of user-defined readers/converters.

Serializer code is only 0.84% inclusive / 0.11% self in this profile.
Inertia prop/render traversal covers 30.2% inclusive but only 0.40% self:
the inclusive number includes dynamic values and SQL, not removable plan
overhead. None of these shares is a promised speedup.

### Exactness and cost of the digest guard

The measured manifest is 177,268 bytes. A standalone YJIT microbenchmark uses
five alternating rounds, 100 warmups + 2,000 calls per alternative; every
warmup result equals the original digest. All numbers are microseconds/call
(median and min–max round means):

| Operation | Time, µs | Objects/call |
|---|---:|---:|
| Original file MD5 + hex | 278.89 (274.75–298.56) | 8 |
| `stat` tuple + cached digest duplicate | 3.53 (1.64–5.26) | 5 |
| Read bytes, exact compare + cached digest duplicate | 84.67 (67.38–108.13) | 3 |

An immutable-file boot fact can cover the computation, **not an arbitrary
Inertia version lambda**. A tuple of device/inode/size/mtime/ctime is cheap
but not an exact content proof. Exact byte equality retains a full file read
and transient file-sized string, saving about 194 µs per digest in this
microbenchmark; it is not a measured request-level gain. Returning a duplicate
preserves the original result's mutability. A future pass also needs guards
on the digest/method/path dependencies, original fallback on changes, missing
files and read errors, and an explicit concurrent-file-change contract.
No digest caching pass was implemented or enabled in this iteration.

## Zweite Iteration: exaktes Digest-Memo (2026-10-20)

Der neue, unabhängige Opt-in-Pass `lowrail build APP --passes default,+digest_memo` senkt
**eine Gem-Site in einer zusätzlichen Unit** ab: insgesamt 62 Units,
58 Ruby-Dateien und vier Templates. Keine Digest-Ablehnung; die 45
bisherigen Route-Ablehnungen bleiben bestehen. Keine Anwendungssourcen,
Klassen-, Datei- oder Testnamen werden hier veröffentlicht. Die Integration
verwendet weiterhin nur `RUBYOPT`; Gemfile und Lockfile bleiben unverändert.
`memo` und `preload_plans` sind für diese Messungen nicht ausgewählt.

Die Dateibytes werden jedes Mal vollständig neu gelesen. Nur ein exakter
Byte-Vergleich darf den Hash sparen; kein Stat-Tupel, kein Memo einer
beliebigen Version-Proc und kein zweites Öffnen nach dem Vergleich.
Fehler und Globs bleiben im ursprünglichen Gem-Verhalten. Der definierte
Stream-Vertrag bei Umbenennen, In-place-Änderung und Entfernen zwischen Reads
sowie Guards und Grenzen stehen in [der Pass-Notiz](../passes/digest-memo.md).
Die öffentliche RailsVite/Inertia/vite_ruby-Fixture verifiziert 7/7 identisch,
71 Assertions pro Modus, 65 Digest-Hits und null Fallbacks, auch beim Build
mit `--passes default,+memo,+digest_memo`. Die Memo-Purity-Prüfung lehnt die
beliebige lazy Proc weiterhin ab; der Digest-Pass optimiert ihren Gem-Aufruf.

### Finale Differential-Gates nach Integration der Memo-Hooks

Dieselbe private App-Revision, Ruby 4.0.7, Rails 8.1.4, lokale PostgreSQL-DB;
`VCR_RECORD_MODE=none`, Seed 1729, acht Unit-/Request- und vier System-Worker.
Die beiden Rails-Suiten laufen nacheinander, nie gleichzeitig in diesem Baum.
Beide Befehle verwenden `lowrail verify APP --bisect -- …`.

| Gate | Off | On | Identität | Hits Route / Digest | Fallbacks |
|---|---:|---:|---|---:|---:|
| Unit + Request | 10.816, 63,1 s | 10.816, 62,9 s | 10.815 Pass + derselbe eine Skip | 794 / **765** | **0** |
| System | 552, 95,8 s | 552, 93,6 s | alle 552 Pass | 226 / **2.849** | **0** |

Verglichen werden alle Testidentitäten und Ergebnisse, nicht nur Summen.
Es gibt keine Outcome-Differenz zu bisecten und keine neue Denylist.
Suite-Laufzeiten sind wegen Parallelisierung/Browserlast keine
Performance-Messung und belegen keinen Speedup.
Die finale Rust-Suite: 26 Unit-Tests + zwei Integrationsharnesses grün;
optionale externe Corpus-Bodies sind in diesem Checkout nicht vorhanden.
Gem-Suite: 77 Tests, 875 Assertions, keine Fehler, zwölf explizite optionale
Dependency-/Corpus-Skips. Das ist keine Behauptung vollständiger Corpus-Abdeckung.
Auch das gebaute/entpackte Gem besteht die öffentliche Fixture mit 7/7,
65 Hits und null Fallbacks; der Runtime-Pfad wird auf das Paket geprüft.

**SQL-Trace-Grenze:** Der inzwischen integrierte zusätzliche Tracer meldet
parallel 288/10.816 Unit-/Request- und 2/552 System-Traces als abweichend
(advisory, nicht Outcome-Differenzen). Serielle Kontrollen derselben auffälligen
Tests mit **allen Units deaktiviert** liefern weiterhin 242/288 beziehungsweise
4/4 abweichende Traces, null Hits und identische Testergebnisse; die seriellen
Verify-Befehle enden deshalb mit Exit 1. Vier Systemfälle werden ausgewählt,
weil zusätzlich zur Digest-Differenz auch unterschiedliche Query-Zahlen zählen.
Eine bestätigte Ursache: kleine Sequenz-IDs in SQL-Literalen unterscheiden sich
zwischen zwei Läufen, während der Tracer erst sechsstellige Zahlen normalisiert;
PostgreSQL-Sequenzen werden durch einen Test-Rollback nicht zurückgesetzt.
Die Kontrolle zeigt Unterschiede ohne Fast Path, nicht die vollständige Ursache
jeder Warnung. Es wird **keine vollständige SQL-Identität behauptet** und weder
der Tracer abgeschaltet noch eine breitere Zahlenmaskierung eingebaut.

### Fünf interleavte YJIT-Paare

Zehn frische Prozesse, Reihenfolge Off/On, On/Off im Wechsel. Jede der drei
authentifizierten Inertia-JSON-Seiten erhält 100 Warmups und 200 gemessene
Requests je Prozess. Zeit bleibt wie zuvor eingefroren, Fixtures und
Authentifizierung kommen aus der lokalen Testschnittstelle; Query-Caches
werden vor jedem Request geleert. Jeder Response wird auf HTTP 200,
erwartete Komponente und passende Version geprüft. Stats und Profiler sind
für diese Zeitmessungen aus. Beide Modi laden Setup, Off setzt `LOWRAIL=0`.
Die Zahlen sind Median der fünf Prozessmediane und deren Min–Max, keine
Konfidenzintervalle und keine Produktionslast-Simulation.

| Seite | Off, ms (Min–Max) | On, ms (Min–Max) | Medianänderung |
|---|---:|---:|---:|
| Overview | 19,064 (18,169–21,568) | 17,905 (17,004–20,157) | −6,1 % |
| List | 8,793 (8,395–10,284) | 7,640 (7,388–9,550) | −13,1 % |
| Profile settings | 7,096 (6,775–7,421) | 6,082 (5,704–6,739) | **−14,3 %** |

Bei Profile sind die Bereiche knapp getrennt und jedes der fünf Paare
schneller (−5,0 bis −19,0 %); diese Kohorte zeigt dort ein einheitliches
Signal. Overview und List haben überlappende Bereiche und jeweils auch
langsamere On-Paare: ihre Medianänderungen sind **nicht klar vom Rauschen
getrennt**. Auch bessere Mediane garantieren keine besseren Tails: p95 über
die fünf Prozesse liegt Off/On bei Overview 27,26–30,85 / 19,99–31,38 ms,
List 10,81–12,57 / 12,11–15,72 ms, Profile 8,17–9,80 / 8,63–13,62 ms.

Allokationen steigen stabil um rund **21 Objekte/Request**: 23.007 →
23.028 / 5.066 → 5.087 / 3.756 → 3.777. Reale SQL-Zahlen bleiben
25 / 11 / 8 in beiden Modi; diese Zählung schließt `SCHEMA`, `TRANSACTION`
und Cache-Treffer aus und ist deshalb nicht direkt mit älteren absoluten
Zählungen gleichzusetzen. Ein separater Stats-Lauf zählt **6.300 echte
Digest-Wiederverwendungen**, sieben je Request über 900 Requests inklusive
Warmups, **keinen Route-Hit und null Fallbacks**. Die Request-Gewinne sind
damit nicht bloß aus Suite-Hits abgeleitet.

### Kosten und verbleibende Kandidaten

Fünf alternierende YJIT-Mikrorunden im selben Prozess, 100 Warmups + 2.000
Aufrufe je Alternative, Dateigröße 177.268 Bytes; Median und Min–Max der
Rundenmittel:

| Operation | µs/Aufruf | Objekte/Aufruf |
|---|---:|---:|
| Originaler MD5-Dateiaufruf mit Pathname | 298,40 (297,34–312,24) | 10 |
| Finaler Guard + Chunk-Read + Byte-Memo | **129,81 (97,47–176,06)** | 13 |

Der vollständige Pass ist teurer als der frühere unbewachte
`binread`-Prototyp mit 84,67 µs: Guard, gleiche Chunk-/Stream-Semantik,
Pfadprüfung und Inhaltsindex sind Teil der Messung. Der frühere Stat-Wert
von 3,53 µs ist weiterhin **kein exakter Beweis** und wurde nicht eingebaut.

Ein separater On-StackProf-Wall-Lauf (1 ms, je 200 Requests nach 100 Warmups)
liefert 7.697 berichtete, 7.696 in Raw-Stacks repräsentierte Samples und
drei verpasste Samples. Prozentzahlen verwenden die repräsentierten
Samples; inklusive Bereiche zählen jedes Sample je Bereich nur einmal und
dürfen nicht addiert werden. Native Digest-Updates haben **null Self-Samples**
statt 15,8 % in der vorigen Kohorte. Das Manifest-/Memo-Read-/Vergleichsbudget
bleibt bei **6,48 % inklusiv**; SQL-Ausführung bei **33,90 % self** kann der
Ruby-Pass nicht beseitigen. Die nächsten gemessenen Ruby-Kandidaten:

1. **Arel-/Query-Planung:** `build_arel` und Visitors **6,08 % inklusiv,
   1,64 % self**; keine Implementierung in dieser Iteration.
2. **Attribut-/Typ-Dispatch:** ActiveModel-Attribute/Registrierung/Lazy-Set
   und ActiveRecord-Attribut-/Typ-Dispatch **4,34 % inklusiv, 2,00 % self**;
   keine Werte oder benutzerdefinierten Konvertierungen memoisiert.
3. **Inhaltsindex des exakten Byte-Memos:** `String#hash` innerhalb des
   Memos **2,48 % self**, zusätzlich Read **1,10 % self**. Einen billigeren
   Index dürfte man nur mit weiter vollständigem Byte-Beweis verwenden,
   nicht als Ersatz durch einen Stat-Guard.

Offene Grenzen: mehr transiente Allokationen, vollständig erhaltenes
Datei-IO, begrenzter Cache, bekannte Call-Site-Guard-Grenzen und keine
Aussage über kalte OS-Caches oder parallele Produktionslast. Daher bleibt
der Pass zunächst opt-in. Die private Integration und ihre temporären
Harness-Dateien wurden nach der Messung entfernt; der private Worktree ist
sauber. Keine ARGOS-Änderung wurde committed oder in das Lowrail-Repository
übertragen.
