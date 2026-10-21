# Rails source drift

`c3466ea00d7121798e3aa3144ffdf7174b81d8cb` → `36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e`. Source-only, conservative early warning; **not admission**.

| Unit | Status | Changed / removed / added source files | Changed / removed members | 8.2 action |
|---|---|---:|---:|---|
| `view/link_to` | changed | 508 / 7 / 25 | 809 / 284 | Re-certify; keep refused |
| `route/path` | changed | 389 / 4 / 22 | 629 / 183 | Re-certify; keep refused |
| `memo/uri_join` | unchanged | 0 / 0 / 0 | 0 / 0 | External/app checks |
| `memo/sha256` | unchanged | 0 / 0 / 0 | 0 / 0 | External/app checks |
| `digest/file_memo` | unchanged | 0 / 0 / 0 | 0 / 0 | External/app checks |
| `active_record/preload_plans` | changed | 723 / 4 / 56 | 1534 / 359 | Re-certify; keep refused |
| `active_record/instantiate` | changed | 660 / 3 / 49 | 1471 / 342 | Re-certify; keep refused |
| `active_record/ar_plans` | changed | 723 / 4 / 56 | 1534 / 359 | Re-certify; keep refused |
| `inertia/config_bind` | changed | 287 / 2 / 20 | 330 / 86 | Re-certify; keep refused |
| `inertia/props` | unchanged | 0 / 0 / 0 | 0 / 0 | External/app checks |
| `endpoint/action` | changed | 881 / 8 / 54 | 1950 / 540 | Re-certify; keep refused |
| `sealed/link_to` | changed | 508 / 7 / 25 | 809 / 284 | Re-certify; keep refused |
| `sealed/form_scaffold` | changed | 881 / 8 / 54 | 1950 / 540 | Re-certify; keep refused |
| `sealed/token_tag` | changed | 881 / 8 / 54 | 1950 / 540 | Re-certify; keep refused |
| `sealed/collection_render` | changed | 881 / 8 / 54 | 1950 / 540 | Re-certify; keep refused |
