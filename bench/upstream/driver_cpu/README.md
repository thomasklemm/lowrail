# Driver CPU study

The record is [driver-cpu.md](../../../docs/upstream/driver-cpu.md). These are
query cases and post-processing for the existing `refresh_window.rb` and
`perf_round/percall.sh`, not an application benchmark. Use disposable databases:
`cases.rb` drops/recreates `driver_rows` and inserts 1,000 synthetic records.
Never point it at an application database.

## Inputs

Use Ruby 4.0.9 (`3e93b23afc`) and the source SHAs in the record. The measured
layout is `/tmp/pdrv/{rails,sqlite,pg,trilogy,mysql2}`. The two independent
SQLite branches are `/tmp/pdrv/sqlite-bind` and `/tmp/pdrv/sqlite-fill-wide`.
Build each driver's native extension with that Ruby and its normal build
instructions; SQLite used `--enable-system-libraries`. PostgreSQL needs libpq;
mysql2 needs the MariaDB/MySQL client development library.

Check **the loaded binary**, not just compilation success. sqlite3-ruby can
prefer `lib/sqlite3/4.0/sqlite3_native.so`; pg can prefer `lib/4.0/pg_ext.so`.
Ensure these match the newly built extension in each checkout. For example:

```sh
ruby -I /tmp/pdrv/sqlite-bind/lib -rsqlite3 \
  -e 'puts $LOADED_FEATURES.grep(/sqlite3_native\.so$/)'
```

Create bundle directories `/tmp/pdrv/{base,aa,sqlite-head,sqlite-fill-wide-head}`.
Each has a Gemfile pointing at the same Rails components and drivers, except
the selected SQLite checkout. `base` and `aa` must be identical. The base
Gemfile is:

```ruby
source "https://rubygems.org"
%w[activesupport activemodel activerecord].each do |component|
  gem component, path: "/tmp/pdrv/rails/#{component}"
end
gem "sqlite3", path: "/tmp/pdrv/sqlite"
gem "pg", path: "/tmp/pdrv/pg"
gem "trilogy", path: "/tmp/pdrv/trilogy/contrib/ruby"
gem "mysql2", path: "/tmp/pdrv/mysql2"
```

Resolve/install with Bundler 4.0.20. The census lock includes bigdecimal 4.1.3,
date 3.6.0, concurrent-ruby 1.3.8, i18n 1.15.2, json 3.1.0, minitest 6.0.6,
psych 5.5.0 and tzinfo 2.0.6. Preserve the same dependency resolution in every
arm. SQLite/pg/trilogy/mysql2 identify themselves as 2.10.2/1.7.0/2.13.3/0.5.7.

The local PostgreSQL database is `pdrv`, authenticated as the current user.
MariaDB has disposable database `pdrv`, user `user`, and Unix socket
`/run/mysqld/mysqld.sock`. Run PostgreSQL cohorts serially with respect to one
another; likewise do not overlap mysql2 and Trilogy fixture setup. SQLite is
process-private. Distinct server families may be measured concurrently;
instructions, not wall time, are the endpoint.

Build the existing `bench/callgrind.c` as `/tmp/pdrv/cg/lowrail_callgrind.so`
using Ruby's `mkmf` and `create_makefile("lowrail_callgrind")`, with Valgrind
headers available. Use the enlarged-brk Valgrind from `script/bench-valgrind`;
the measured executable is `$HOME/vg-brk512/bin/valgrind`.

## Run once, keep rejected data

From the repository root, with Ruby 4.0.9 first on PATH:

```sh
DRIVER=sqlite3 PREPARED=1 MODE=interpreter \
  bash bench/upstream/driver_cpu/measure.sh /tmp/pdrv/example-interpreter \
  /tmp/pdrv/base /tmp/pdrv/aa /tmp/pdrv/sqlite-fill-wide-head

CASES="$PWD/bench/upstream/driver_cpu/sqlite_bind_cases.rb" \
NAMES=bind20_driver,bind20_adapter,bind20_model \
DRIVER=sqlite3 PREPARED=1 MODE=yjit \
  bash bench/upstream/driver_cpu/measure.sh /tmp/pdrv/example-yjit \
  /tmp/pdrv/base /tmp/pdrv/aa /tmp/pdrv/sqlite-head

ruby bench/upstream/driver_cpu/summarize.rb \
  /tmp/pdrv/example-interpreter /tmp/pdrv/example-yjit > /tmp/pdrv/example.json
```

`measure.sh` refuses to reuse an output directory. Default count is five and
default repetitions are three. The summary accepts only complete repetitions
1/2/3, A/A zero containment within ±0.5%, unchanged/matched five-pool capacities
within one page, and all measured JIT windows flat. An accepted control is
not itself a candidate gain: inspect the candidate interval and regressions.
Never repeat an A/A rejection until a green cohort appears.

For the census, omit the candidate arm and use `DRIVER=postgresql|mysql2|trilogy`
and `PREPARED=0|1`; Trilogy only supports zero. Large YJIT model-load warmups
are expensive under Valgrind. Do not mistake ongoing compilation warmup for a
hung benchmark. Boot/warmup are outside the counted region.

The independent original-tool cross-check was:

```sh
PDRV_RAILS=/tmp/pdrv/rails DRIVER=sqlite3 PREPARED=1 \
OUT=/tmp/pdrv/percall-example \
  bash bench/upstream/perf_round/percall.sh \
  bench/upstream/driver_cpu/sqlite_bind_cases.rb bind20_model 100 3 \
  /tmp/pdrv/base /tmp/pdrv/aa /tmp/pdrv/sqlite-head
```

Native YJIT allocations use the same cases/worker, fixed-heap environment from
`measure.sh`, and `ruby --yjit -rbundler/setup` **without** `CG_EXT` or Valgrind.
CPU-time fields are retained observations, not a wall-time claim.

## Differential validation

Run against base and each candidate separately, assert the native feature's
path, and compare the complete observations as well as their digest:

```sh
COMPACT=1 ruby --yjit -I /tmp/pdrv/sqlite-bind/lib \
  bench/upstream/driver_cpu/sqlite_exact.rb > /tmp/pdrv/exact-head.json
```

`sqlite_exact.rb` is independent of the benchmark's fixture and expected
output. It records strings as class/bytes/encoding/frozen/valid, checks
successive results and identities, covers invalid encoding/error boundaries,
1–2,000 columns, huge integers, GC stress/compaction and threads. The result
objects remain retained through compaction. `pg_exact.rb` additionally probes
custom decoder callbacks, binary/text results, clearing results during a
callback, and OID/column/fallback maps for the rejected pg experiment.

SQLite's own suite command, from the corresponding driver checkout, is:

```sh
SQLITE3_TEST_GC_LEVEL=verify ruby -Ilib -Itest \
  -e 'Dir["test/test_*.rb"].sort.each { require_relative _1 }'
```

Sol and Astra are coordinator-owned. Fork publication is not an upstream PR;
the queue items must not be opened until their current-head gates pass.
