## Disclosure fix (2026-11-27)

Astra and thermos-sol on `3e348f32bd` both showed that on main, with a schema cache built on a newer SQLite,
`schema_cache_path` set and `check_schema_cache_dump_version = false`, `bin/rails runner` create/find/update/destroy
pass on SQLite 3.35.5 and 3.36.0, and that the head refuses those connections
([review-astra-2026-11-27](review-astra-2026-11-27/README.md), [review-thermos-sol-2026-11-27](review-thermos-sol-2026-11-27/README.md)).
The `Model.create!` / `find` row above is the uncached case. `e7a17ff01b` keeps the code and test and rewords the commit
message and CHANGELOG to say uncached schema discovery fails and that these working paths are refused too; the body is
thermos-sol's two-paragraph version, which also names #58284 as unreleased.
