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
