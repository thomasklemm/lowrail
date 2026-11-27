## Attribution (detail runs: allocation tracing and heap dumps, one run per configuration)

### Live bytes after boot by owner, MB (Ruby master interpreter, Rails main)

| owner | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| Rails (all components) | 26.79 | 27.49 | 25.99 | 28.02 | 26.75 | 45.28 |
| gems | 26.73 | 38.11 | 29.36 | 42.04 | 25.07 | 118.88 |
| app | 0.04 | 0.58 | 0.15 | 0.38 | 0.08 | 29.84 |
| Ruby stdlib | 3.90 | 4.05 | 4.77 | 5.05 | 4.20 | 6.66 |
| Ruby VM tables | 4.62 | 6.80 | 4.72 | 8.12 | 4.60 | 15.83 |
| Ruby method caches (cc tables) | 2.72 | 3.00 | 2.62 | 4.58 | 2.68 | 11.03 |
| untraced (C, before tracing) | 6.47 | 6.40 | 6.36 | 6.89 | 6.39 | 7.38 |
| harness and other | 0.49 | 0.53 | 0.47 | 0.68 | 0.50 | 1.27 |
| ISEQs (inside the groups above) | 34.77 | 40.20 | 37.06 | 45.26 | 34.80 | 96.50 |

### Largest owners after boot, MB (master interpreter, Rails main)

| owner | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| gem/stripe | – | – | – | – | – | 18.40 |
| gem/rouge | – | 12.68 | – | – | – | 11.96 |
| rails/activerecord | 10.61 | 10.77 | 11.00 | 10.66 | 10.61 | 17.53 |
| gem/anthropic | – | – | – | – | – | 10.16 |
| ruby/vm | 4.62 | 6.80 | 4.72 | 8.12 | 4.60 | 15.83 |
| (untraced) | 6.47 | 6.40 | 6.36 | 6.89 | 6.39 | 7.38 |
| rails/activesupport | 4.97 | 5.06 | 4.69 | 5.76 | 4.98 | 9.67 |
| app | 0.04 | 0.58 | 0.15 | 0.38 | 0.08 | 29.84 |
| rails/actionpack | 4.09 | 4.48 | 4.10 | 5.00 | 4.10 | 9.12 |
| gem/mail | 4.79 | 4.80 | 4.79 | 4.78 | 4.81 | 4.79 |
| ruby/stdlib | 3.90 | 4.05 | 4.77 | 5.05 | 4.20 | 6.66 |
| ruby/method-cache | 2.72 | 3.00 | 2.62 | 4.58 | 2.68 | 11.03 |
| gem/avo | – | – | – | 4.26 | – | – |
| gem/bootsnap | 0.87 | – | 0.88 | 1.47 | 0.87 | 16.97 |
| gem/prism | 2.75 | 2.75 | 2.75 | 2.75 | 2.75 | 2.75 |
| rails/actionview | 2.17 | 2.24 | 2.15 | 2.32 | 2.17 | 2.91 |
| gem/yard | – | – | – | – | – | 2.15 |
| gem/bundler | 2.15 | 2.15 | 2.15 | 2.15 | 2.15 | 2.15 |
| gem/sorbet-runtime | – | – | 1.93 | – | – | – |
| gem/view_component | – | – | – | 2.18 | – | 1.53 |
| gem/rack-mini-profiler | – | – | – | – | – | 1.67 |
| gem/concurrent-ruby | 1.56 | 1.59 | 1.55 | 1.60 | 1.56 | 1.63 |
| gem/ruby-vips | 1.50 | 1.50 | 1.50 | – | – | 1.49 |
| gem/addressable | – | – | – | 1.36 | – | 1.40 |
| rails/activemodel | 1.27 | 1.28 | 1.24 | 1.34 | 1.28 | 1.73 |
| rails/railties | 1.26 | 1.18 | 1.27 | 1.43 | 1.20 | 1.76 |
| gem/lookbook | – | – | – | – | – | 1.33 |
| gem/rexml | – | – | – | – | – | 1.19 |
| gem/net-imap | 1.11 | 1.12 | 1.11 | 1.08 | 1.11 | 1.10 |
| gem/nokogiri | 1.05 | 1.06 | 1.05 | 1.05 | 1.05 | 1.05 |

### Rails main − 8.1.4.1 after boot by owner, MB (master-interpreter; owners moving ≥ 0.1 MB in some app)

| owner | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| rails/activerecord ISEQ | +0.96 | +0.95 | +1.07 | +0.98 | +0.96 | +0.69 |
| gem/psych | +0.43 | +0.44 | +0.45 | +0.43 | +0.43 | +0.39 |
| gem/msgpack | +0.55 | – | +0.58 | +0.74 | +0.58 | – |
| rails/activesupport other | +0.34 | +0.33 | +0.32 | +0.33 | +0.32 | +0.66 |
| rails/activemodel ISEQ | +0.26 | +0.27 | +0.26 | +0.23 | +0.26 | +0.19 |
| ruby/method-cache | +0.21 | +0.17 | +0.13 | +0.21 | +0.20 | +0.39 |
| rails/activesupport ISEQ | +0.20 | +0.20 | +0.21 | +0.20 | +0.20 | +0.16 |
| rails/activerecord other | +0.23 | +0.24 | +0.30 | +0.18 | +0.21 | -0.11 |
| gem/marcel | +0.15 | +0.16 | +0.15 | +0.14 | +0.15 | +0.17 |
| gem/rack | +0.11 | +0.11 | +0.11 | +0.13 | +0.11 | +0.09 |
| gem/useragent | +0.24 | +0.00 | – | – | +0.24 | +0.00 |
| rails/actionpack other | +0.11 | +0.05 | +0.10 | +0.10 | +0.10 | -0.11 |
| rails/activemodel other | +0.05 | +0.03 | +0.03 | +0.04 | +0.05 | +0.13 |
| gem/redis | – | +0.00 | – | – | – | -0.15 |
| rails/actionpack ISEQ | +0.00 | +0.00 | -0.06 | -0.07 | +0.01 | -0.18 |
| gem/rake | -0.29 | -0.29 | -0.29 | -0.00 | – | +0.00 |
| gem/bootsnap | -0.53 | – | -0.57 | -0.75 | -0.56 | +0.02 |
| ruby/stdlib | -1.08 | -1.08 | -1.14 | -1.16 | -1.08 | -1.19 |

### Rails main − 8.1.4.1 after boot by owner, MB (r4010-interpreter; owners moving ≥ 0.1 MB in some app)

| owner | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| rails/activerecord ISEQ | +0.63 | +0.63 | +0.77 | +0.63 | +0.63 | +0.77 |
| gem/psych | +0.49 | +0.47 | +0.48 | +0.48 | +0.49 | +0.45 |
| gem/msgpack | +0.64 | – | +0.68 | +0.86 | +0.68 | – |
| rails/activesupport other | +0.38 | +0.34 | +0.29 | +0.31 | +0.33 | +0.62 |
| ruby/method-cache | +0.28 | +0.22 | +0.18 | +0.25 | +0.26 | +0.46 |
| rails/activemodel ISEQ | +0.26 | +0.26 | +0.26 | +0.26 | +0.26 | +0.26 |
| rails/actionpack ISEQ | +0.26 | +0.26 | +0.26 | +0.26 | +0.26 | +0.26 |
| rails/activesupport ISEQ | +0.23 | +0.22 | +0.23 | +0.23 | +0.23 | +0.22 |
| gem/marcel | +0.18 | +0.18 | +0.18 | +0.15 | +0.18 | +0.20 |
| gem/rack | +0.12 | +0.12 | +0.12 | +0.14 | +0.12 | +0.10 |
| rails/activerecord other | +0.19 | +0.14 | +0.26 | +0.15 | +0.21 | -0.23 |
| gem/useragent | +0.25 | +0.00 | – | – | +0.25 | +0.00 |
| rails/actionpack other | +0.12 | +0.06 | +0.13 | +0.03 | +0.10 | -0.07 |
| gem/redis | – | +0.00 | – | – | – | -0.18 |
| gem/concurrent-ruby | -0.02 | -0.01 | -0.05 | -0.02 | -0.04 | -0.11 |
| gem/bootsnap | -0.61 | – | -0.65 | -0.84 | -0.65 | +0.00 |
| ruby/stdlib | -0.71 | -0.69 | -0.73 | -0.76 | -0.69 | -0.79 |

### Ruby master − 4.0.10 after boot by type, MB (interpreter, Rails main; types moving ≥ 0.1 MB in some app)

| type | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| IMEMO/iseq | -6.06 | -6.49 | -7.02 | -8.00 | -6.55 | -17.76 |
| STRING | -0.85 | -1.00 | -0.94 | -1.11 | -0.89 | -4.46 |
| HASH | -0.44 | -0.53 | -0.41 | -0.68 | -0.44 | -5.49 |
| ARRAY | -0.87 | -0.92 | -0.92 | -1.13 | -0.87 | -2.07 |
| DATA/VM/cc_table | -0.45 | -0.65 | -0.53 | -0.65 | -0.47 | -2.30 |
| CLASS | -0.37 | -0.37 | -0.43 | -0.46 | -0.42 | -1.29 |
| IMEMO/callcache | -0.18 | -0.29 | -0.22 | -0.24 | -0.19 | -1.21 |
| OBJECT | -0.18 | -0.25 | -0.17 | -0.32 | -0.18 | -1.00 |
| DATA/T_IMEMO/iseq | -0.20 | -0.01 | -0.21 | -0.28 | -0.20 | -0.84 |
| MODULE | -0.12 | -0.12 | -0.12 | -0.16 | -0.12 | -0.31 |
| DATA/proc | -0.05 | -0.07 | -0.05 | -0.07 | -0.05 | -0.27 |
| DATA/VM | -0.05 | -0.03 | -0.04 | -0.03 | -0.02 | -0.31 |
| DATA/autoload_table | -0.03 | -0.03 | -0.04 | -0.04 | -0.03 | -0.14 |
| REGEXP | +0.02 | +0.12 | -0.01 | +0.03 | -0.01 | +0.19 |
| IMEMO/cdhash | +0.07 | +0.07 | +0.08 | +0.09 | +0.07 | +0.18 |
| IMEMO/fields | +0.07 | +0.08 | +0.05 | +0.13 | +0.07 | +0.45 |
| IMEMO/subclasses | +0.11 | +0.12 | +0.11 | +0.15 | +0.11 | +0.43 |
| DATA/symbol_id_entry_list | +0.64 | +0.68 | +0.67 | +0.79 | +0.64 | +1.56 |
| DATA/VM/thread | +1.05 | +1.05 | +1.05 | +1.05 | +1.05 | +1.05 |
| IMEMO/ment | +2.88 | +2.94 | +2.95 | +3.62 | +2.84 | +9.45 |

### Bytes in duplicate String copies after boot (beyond one copy per content), MB

| configuration | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| r4010-interpreter r81 | 0.50 | 0.33 | 0.50 | 0.65 | 0.46 | 1.22 |
| r4010-interpreter main | 0.49 | 0.30 | 0.47 | 0.63 | 0.47 | 1.19 |
| master-interpreter r81 | 0.43 | 0.29 | 0.43 | 0.57 | 0.40 | 1.05 |
| master-interpreter main | 0.42 | 0.27 | 0.41 | 0.55 | 0.41 | 1.05 |
| master-zjit r81 | 0.34 | 0.29 | 0.33 | 0.46 | 0.32 | 1.06 |
| master-zjit main | 0.32 | 0.27 | 0.31 | 0.45 | 0.31 | 1.05 |

### Objects allocated after request 1,000 and still live at request 5,000, MB

| configuration | blog | writebook | pingcrm | redprints-cfp | react-starter-kit | sure |
|---|---:|---:|---:|---:|---:|---:|
| r4010-interpreter r81 | 0.11 | 0.27 | 0.10 | 0.11 | 0.09 | 0.17 |
| r4010-interpreter main | 0.08 | 0.26 | 0.10 | 0.10 | 0.09 | 0.15 |
| master-interpreter r81 | 0.08 | 0.27 | 0.10 | 0.10 | 0.09 | 0.16 |
| master-interpreter main | 0.08 | 0.26 | 0.10 | 0.10 | 0.09 | 0.15 |
| master-zjit r81 | 0.08 | 0.27 | 0.10 | 0.10 | 0.09 | 0.16 |
| master-zjit main | 0.08 | 0.27 | 0.10 | 0.10 | 0.09 | 0.15 |

